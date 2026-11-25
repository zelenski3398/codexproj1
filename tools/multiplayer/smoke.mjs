import assert from 'node:assert/strict';
import {setTimeout as delay} from 'node:timers/promises';

const endpoint = process.env.WINGS_DUEL_URL || 'ws://127.0.0.1:19074';
const clients = [];
async function client() {
  const socket = new WebSocket(endpoint);
  const inbox = [];
  clients.push(socket);
  socket.addEventListener('message', event => {
    inbox.push(JSON.parse(event.data));
    if (inbox.length > 500) inbox.shift();
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, {once: true});
    socket.addEventListener('error', reject, {once: true});
  });
  const send = (type, data = {}) => socket.send(JSON.stringify({type, ...data}));
  const next = async (predicate, timeout = 20000) => {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const index = inbox.findIndex(predicate);
      if (index >= 0) return inbox.splice(0, index + 1).at(-1);
      await delay(14);
    }
    throw new Error('Timed out reading duel message. Recent messages: ' + inbox.filter(x=>x.type!=='pong').slice(-8).map(x => x.type + ':' + (x.phase || x.text || '')).join(', '));
  };
  const lobby = (predicate = () => true) => next(msg => msg.type === 'lobby' && predicate(msg));
  const ping = setInterval(() => { if (socket.readyState === WebSocket.OPEN) send('ping'); }, 2000);
  socket.addEventListener('close', () => clearInterval(ping), {once: true});
  return {socket, send, next, lobby};
}

async function guest(name) {
  const peer = await client();
  peer.send('create', {name});
  const profile = await peer.next(msg => msg.type === 'profile');
  assert.equal(profile.credential.length, 64);
  await peer.lobby();
  return {...peer, id: profile.profile.id, token: profile.credential};
}

async function invite(a,b) {
  a.send('challenge', {opponent:b.id});
  const entry = await b.lobby(m => m.invite?.other.id === a.id);
  return entry.invite.id;
}

try {
  let a = await guest('Ace One');
  const b = await guest('Ace One');
  assert.notEqual(a.id, b.id);
  const third = await client();
  third.send('resume', {id: a.id, token: b.token});
  await third.next(m => m.type === 'auth_error' && m.invalid);
  third.send('resume', {id: a.id, token: a.token});
  await third.next(m => m.type === 'auth_error' && m.text.includes('another tab'));
  third.socket.close();
  a.send('rename', {name:'Wing Lead'});
  await a.lobby(m => m.profile.name === 'Wing Lead' && m.profile.id === a.id);
  a.send('find');
  b.send('find');
  await a.lobby(m => m.guests.some(g=>g.id===b.id) && !m.guests.some(g=>g.id===a.id));
  await b.lobby(m => m.guests.some(g=>g.id===a.id));
  b.send('decline', {invite:await invite(a,b)});
  await a.lobby(m=>m.available && !m.invite);
  await delay(2300);
  const cancel = await invite(a,b);
  a.send('cancel', {invite:cancel});
  await a.lobby(m=>m.available && !m.invite);
  await delay(2300);
  await invite(a,b);
  await a.next(m=>m.type==='notice' && m.text.includes('expired'), 10000);
  await a.lobby(m=>m.available && !m.invite);
  a.send('challenge', {opponent:b.id});
  b.send('challenge', {opponent:a.id});
  const ia = await a.lobby(m=>m.invite);
  const ib = await b.lobby(m=>m.invite);
  assert.equal(ia.invite.id, ib.invite.id);
  assert.notEqual(ia.invite.outgoing, ib.invite.outgoing);
  const recipient = ia.invite.outgoing ? b : a;
  recipient.send('accept', {invite:ia.invite.id});
  const ma = (await a.lobby(m=>m.match?.state==='selection')).match;
  const mb = (await b.lobby(m=>m.match?.state==='selection')).match;
  assert.equal(ma.id, mb.id);
  const match_id = ma.id;
  for (const [side, challenger, kind] of [[0,a,'spitfire'],[1,b,'bf109_e4']]) {
    challenger.send('select', {match_id,side,kind});
    await challenger.lobby(m=>m.match?.kinds[m.match.you]===kind);
    challenger.send('ready',{match_id});
  }
  const first = (await a.lobby(m=>m.match?.state==='flight')).match;
  await b.lobby(m=>m.match?.round_id===first.round_id);
  const round_id = first.round_id;
  const load = {match_id, round_id};
  const aviation = await a.next(m=>m.type==='flight' && m.phase==='loading');
  assert(aviation.aircraft[0].gear && aviation.aircraft[0].p[1] < 150);
  assert(aviation.aircraft[1].p[1] > 450 && aviation.aircraft[1].v.some(v=>Math.abs(v)>30));
  a.send('loaded',load);
  await delay(250);
  assert.equal((await a.next(m=>m.type==='flight')).phase,'loading');
  b.send('loaded',load);
  await a.next(m=>m.type==='flight' && m.phase==='combat');
  await b.next(m=>m.type==='flight' && m.phase==='combat');
  const firstInput = {match_id, round_id, seq:1, axes:[0,0,0,1], brake:false, fire:true, gear:true};
  a.send('input', {...firstInput,seq:9000,axes:[300,0,0,0]});
  a.send('input',firstInput);
  const fired = await a.next(m=>m.type==='flight' && m.aircraft[0].salvos > 0);
  assert(fired.aircraft[0].ammo < aviation.aircraft[0].ammo);
  const old = a;
  a.socket.close();
  await b.next(m=>m.type==='flight' && m.disconnected[0]>=0);
  const resumed = await client();
  resumed.send('resume',{id:old.id,token:old.token});
  await resumed.next(m=>m.type==='profile' && m.profile.id===old.id && m.profile.name==='Wing Lead');
  a={...resumed,id:old.id,token:old.token};
  await a.lobby(m=>m.match?.round_id===round_id);
  await b.next(m=>m.type==='flight' && m.disconnected[0]<0);
  const ra = await a.lobby(m=>m.match?.state==='results');
  const rb = await b.lobby(m=>m.match?.state==='results');
  assert.equal(ra.match.result.winner,-1);
  assert.equal(ra.stats.draws,1);
  assert.equal(rb.stats.draws,1);
  a.send('rematch',{match_id}); b.send('rematch',{match_id});
  for (const peer of [a,b]) {
    const selection=await peer.lobby(m=>m.match?.state==='selection');
    assert(selection.match.kinds.every(x=>!x));
  }
  for (const [side, challenger, kind] of [[0,a,'hurricane'],[1,b,'c202']]) {
    challenger.send('select', {match_id,side,kind});
    await challenger.lobby(m=>m.match?.kinds[m.match.you]===kind);
    challenger.send('ready',{match_id});
  }
  const second = (await a.lobby(m=>m.match?.state==='flight')).match;
  assert.notEqual(second.round_id, round_id);
  await b.lobby(m=>m.match?.round_id===second.round_id);
  a.send('loaded',{match_id,round_id});
  assert.equal((await a.next(m=>m.type==='flight' && m.round_id===second.round_id)).phase,'loading');
  for (const peer of [a,b]) peer.send('loaded',{match_id,round_id:second.round_id});
  for (const peer of [a,b]) {
    await peer.next(m=>m.type==='flight' && m.phase==='combat');
    const summary=await peer.lobby(m=>m.match?.state==='results');
    assert.equal(summary.stats.draws,2);
    peer.send('rematch',{match_id});
  }
  await a.lobby(m=>m.match?.state==='selection');
  a.send('leave',{match_id});
  await a.lobby(m=>!m.match);
  b.socket.close();
  const later=await client();
  await delay(350);
  later.send('resume',{id:b.id,token:b.token});
  const career=await later.next(m=>m.type==='profile');
  assert.equal(career.stats.draws,2);
  console.log('PASS: authenticated identity, rename, duplicate names, discovery, declining, cancelling, expiry, simultaneous challenges, shared spawns/ready, firing, reconnect, result persistence and consecutive rematches');
} finally {
  for (const socket of clients) if (socket.readyState < WebSocket.CLOSING) socket.close();
}
