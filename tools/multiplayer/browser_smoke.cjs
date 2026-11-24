const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const {setTimeout: delay} = require('node:timers/promises');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const port = Number(process.env.DUEL_TEST_WEB_PORT || 8794);
const backendPort = process.env.DUEL_TEST_SERVER_PORT || '9074';
const url = `http://127.0.0.1:${port}/index.html?smoke=1`;
const browserErrors = [];
let browser;
const exported = path.resolve('builds/web');
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dogfight-web-'));
for (const file of fs.readdirSync(exported)) {
  if (file !== 'index.html') fs.symlinkSync(path.join(exported,file),path.join(fixture,file));
}
const gameArgs = ['--','--skip-intro'];
if (process.env.DUEL_TEST_NO_RENDER === '1') gameArgs.unshift('--disable-render-loop');
const shell = fs.readFileSync(path.join(exported,'index.html'),'utf8').replace('"args":[]','"args":'+JSON.stringify(gameArgs));
fs.writeFileSync(path.join(fixture,'index.html'),shell);
const server = spawn('python3',['tools/multiplayer/serve.py','--port',String(port),'--duel-port',backendPort,'--directory',fixture],{stdio:'ignore'});

async function open(context) {
  const page = await context.newPage();
  page.on('pageerror', e => {browserErrors.push(e.message); console.error(e.message);});
  page.on('console', m => { if (m.type()==='error' && !m.text().includes('favicon')) {browserErrors.push(m.text()); console.error(m.text());} });
  await page.goto(url);
  await menu(page);
  console.log('Opened multiplayer menu');
  return page;
}
const wait = async (page,fn,arg) => {
  await page.bringToFront();
  try { return await page.waitForFunction(fn,arg,{polling:100,timeout:150000}); }
  catch(error) {
    console.error(await page.evaluate(()=>({
      ready:window.firstSortieReady, duel:window.firstSortieState?.duel
    })).catch(()=>null));
    throw error;
  }
};
const state = page => page.evaluate(()=>window.firstSortieState);
const duel = async page => (await state(page)).duel;
async function menu(page) {
  await wait(page,()=>window.firstSortieState && (window.firstSortieState.startup_intro?.play_button || window.firstSortieState.multiplayer_button));
  const initial = await state(page);
  if (initial.startup_intro?.active) {
    await page.mouse.click(...initial.startup_intro.play_button);
    await wait(page,()=>!window.firstSortieState?.startup_intro?.active);
  }
  await wait(page,()=>window.firstSortieState?.multiplayer_button);
  await page.mouse.click(...(await state(page)).multiplayer_button);
  await wait(page,()=>window.firstSortieState?.duel);
}
async function click(page,label) {
  await wait(page,label=>window.firstSortieState?.duel?.widgets.some(w=>w.label.startsWith(label)),label);
  await page.bringToFront();
  await page.mouse.click(...(await duel(page)).widgets.find(w=>w.label.startsWith(label)).point);
}
async function name(page, label, value) {
  await click(page,label);
  await page.keyboard.press('Control+a');
  await page.keyboard.type(value,{delay:25});
}
async function create(page,value) {
  await name(page,'Guest display name',value);
  await click(page,'Create guest');
  await wait(page,()=>window.firstSortieState?.duel?.profile);
}
(async () => {
  try {
    await delay(400);
    browser = await chromium.launch({executablePath:process.env.CHROME_BIN || '/usr/bin/chromium',
      args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-background-timer-throttling','--disable-renderer-backgrounding','--disable-backgrounding-occluded-windows']});
    const left = await browser.newContext({viewport:{width:900,height:562}});
    const right = await browser.newContext({viewport:{width:900,height:562}});
    const a = await open(left);
    await create(a,'Browser Ace');
    console.log('PASS first browser guest created');
    const b = await open(right);
    await create(b,'Browser Ace');
    console.log('PASS second browser guest created');
    const id = (await duel(a)).profile.id;
    assert.notEqual(id,(await duel(b)).profile.id);
    await a.reload();
    await menu(a);
    await wait(a,id=>window.firstSortieState?.duel?.profile?.id===id,id);
    await name(a,'New display name','Browser Lead');
    await click(a,'Rename');
    await wait(a,()=>window.firstSortieState?.duel?.profile?.name==='Browser Lead');
    console.log('PASS browser guest creation, reload, authentication and rename');
    await click(a,'Find a Duel'); await click(b,'Find a Duel');
    await wait(a,()=>window.firstSortieState.duel.available);
    await wait(b,()=>window.firstSortieState.duel.available);
    console.log('PASS both browser guests are available');
    await click(a,'Challenge Browser Ace'); await click(b,'Accept');
    await wait(a,()=>window.firstSortieState?.duel?.match?.state==='selection');
    await wait(b,()=>window.firstSortieState?.duel?.match?.state==='selection');
    assert.equal((await duel(a)).match.id,(await duel(b)).match.id);
    console.log('PASS browsers accepted one shared match');
    await click(a,'Select Spitfire Mk I');
    await wait(b,()=>window.firstSortieState.duel.match.sides.includes(0));
    await click(b,'Select Bf 109 E-4 Emil');
    await click(a,'Ready'); await click(b,'Ready');
    console.log('PASS browsers selected aircraft and sent ready');
    await wait(a,()=>window.firstSortieState?.duel?.flight?.phase==='combat');
    await wait(b,()=>window.firstSortieState?.duel?.flight?.phase==='combat');
    for (const page of [a,b]) {
      const snapshot=(await duel(page)).flight;
      assert.equal(snapshot.defence_enabled,false);
      assert(snapshot.aircraft[0].gear && snapshot.aircraft[0].position[1] < 150);
      assert(snapshot.aircraft[1].position[1] > 400 && Math.hypot(...snapshot.aircraft[1].velocity) > 40);
    }
    await a.bringToFront();
    await a.keyboard.down('f');
    await wait(b,()=>window.firstSortieState.duel.flight.aircraft[0].salvos>0);
    await a.keyboard.up('f');
    console.log('PASS browser challenge, shared selection/readiness, runway/airborne spawns, disabled AA and delivered gunfire');
    await a.keyboard.press('Escape');
    await click(a,'Leave duel');
    await wait(b,()=>window.firstSortieState?.duel?.match?.state==='results');
    assert.equal((await duel(b)).match.result.winner,1);
    assert.equal((await duel(b)).match.result.reason,'A player left the duel.');
    assert.equal((await duel(b)).stats.wins,1);
    await click(b,'Leave duel');
    await click(b,'Back to main menu');
    await wait(b,()=>window.firstSortieState?.multiplayer_button && !window.firstSortieState?.duel);
    await menu(b);
    await wait(b,()=>window.firstSortieState?.duel?.stats?.wins===1);
    assert.deepEqual(browserErrors,[]);
    console.log('PASS browser forfeit result, persistent career and normal main menu restoration');
  }finally{
    if(browser) await browser.close();
    server.kill();
    fs.rmSync(fixture,{recursive:true,force:true});
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
