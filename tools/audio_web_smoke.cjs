// Inspect real WebAudio samples after browser user activation. The analyser is
// an observer inserted before destination-bound nodes, not a gameplay hook.
const {chromium} = require('playwright');
const {spawn} = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
 const server = spawn('python3', ['-m','http.server','8767','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')], {stdio:'ignore'});
 let browser; let checks = 0; const errors = []; const measurements = [];
 const check = (value, message) => {assert.ok(value, message); checks++; console.log('PASS: ' + message);};
 try {
  await delay(500);
  browser = await chromium.launch({executablePath:process.env.CHROME_BIN || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'],ignoreDefaultArgs:['--mute-audio']});
  const page = await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {if(message.type() === 'error') errors.push(message.text()); if(message.type() === 'warning') console.log('WARNING: '+message.text());});
  await page.addInitScript(() => {
   window.audioProbes = [];
   window.sourceStarts = [];
   const start = AudioBufferSourceNode.prototype.start;
   AudioBufferSourceNode.prototype.start = function(...args) {
    const b = this.buffer; let e = 0;
    if(b) for(const x of b.getChannelData(0).subarray(0, 32000)) e += x*x;
    window.sourceStarts.push({loop:this.loop, duration:b?.duration, rms:Math.sqrt(e/32000), time:this.context.currentTime, args});
    return start.apply(this,args);
   };
   const connect = AudioNode.prototype.connect;
   AudioNode.prototype.connect = function(destination, ...args) {
    if(destination === this.context.destination) {
     const analyser = this.context.createAnalyser();
     analyser.fftSize = 2048;
     connect.call(this, analyser, ...args);
     connect.call(analyser, destination);
     window.audioProbes.push({source:this.constructor.name, context:this.context, analyser, samples:new Float32Array(2048), rms:0});
     return destination;
    }
    return connect.call(this, destination, ...args);
   };
   setInterval(() => {
    for(const probe of window.audioProbes) {
     probe.analyser.getFloatTimeDomainData(probe.samples);
     probe.rms = Math.sqrt(probe.samples.reduce((sum,value) => sum + value * value, 0) / probe.samples.length);
    }
   }, 50);
  });
  const state = () => page.evaluate(() => window.firstSortieState);
  const wait = predicate => page.waitForFunction(predicate, null, {timeout:120000});
  const click = async id => {const [x,y] = (await state())[id]; await page.mouse.click(x,y);};
  const measure = async label => {
   const values = [];
   for(let i=0;i<6;i++) {await delay(100); values.push(await page.evaluate(() => Math.max(0, ...window.audioProbes.map(probe => probe.rms))));}
   const rms = Math.max(...values);
   measurements.push({label, rms}); console.log('WebAudio RMS: ' + label + ' ' + rms.toFixed(6)); return rms;
  };
  await page.goto('http://127.0.0.1:8767/index.html?smoke=1');
  check(await page.evaluate(() => window.audioProbes.length === 0), 'Landing page starts no audio before Play');
  await page.getByRole('button',{name:'PLAY IN BROWSER'}).click();
  await wait(() => window.firstSortieState?.audio.music_gain > 0.99);
  check(await page.evaluate(() => window.audioProbes.some(probe => probe.context.state === 'running')), 'Play user gesture activates the actual browser AudioContext');
  check(await measure('menu theme') > 0.0001, 'Supplied menu theme produces real decoded audio samples');
  await click('audio_button');
  await wait(() => window.firstSortieState.audio.panel_open);
  await page.screenshot({path:'/tmp/first-sortie-web-checks/audio-settings.png'});
  await click('audio_mute_button');
  await wait(() => window.firstSortieState.audio.muted);
  await delay(500);
  check(await measure('muted menu') < 0.00001, 'In-game mute silences browser output');
  await click('audio_mute_button');
  await wait(() => !window.firstSortieState.audio.muted);
  check(await measure('unmuted menu') > 0.0001, 'Unmute restores real menu output');
  await click('audio_button');
  await page.keyboard.press('2');
  await wait(() => window.firstSortieState.selected === 'sea_gladiator');
  await click('fly_button');
  await wait(() => !window.firstSortieState.selecting && !window.firstSortieState.audio.music_playing && window.firstSortieState.audio.engine_gain > 0.99);
  check(await measure('Gladiator idle') > 0.0001, 'Gladiator engine produces spatial browser output after departure');
  await page.keyboard.down('w');
  await page.keyboard.down('f');
  await page.keyboard.down('ArrowLeft');
  await wait(() => window.firstSortieState.throttle > 0.2 && window.firstSortieState.audio.audible_salvos > 4 && window.firstSortieState.audio.gun_gain > 0.99);
  check((await state()).shots > 0 && (await state()).audio.flight_mix > 0.1, 'Engine blend and real gun salvos remain active while steering and throttling');
  check(await measure('engine and guns') > 0.0001, 'Sustained gunfire and engine produce decoded browser samples');
  await page.keyboard.up('w'); await page.keyboard.up('f'); await page.keyboard.up('ArrowLeft');
  await wait(() => !window.firstSortieState.audio.gun_playing);
  check(!(await state()).audio.gun_playing, 'Trigger release stops gun audio in the release export');
  await page.keyboard.press('Escape');
  await wait(() => window.firstSortieState.paused && window.firstSortieState.audio.gameplay_muted);
  await delay(500);
  check(await measure('paused flight') < 0.00001, 'Pause silences actual gameplay output');
  await click('change_button');
  await wait(() => window.firstSortieState.selecting && window.firstSortieState.audio.music_gain > 0.99);
  check((await state()).audio.music_playing, 'Returning to selection restarts one menu theme');
  await click('malta_button');
  await wait(() => window.firstSortieState.airfield_selecting);
  check(await measure('departure map music') > 0.0001, 'Music continues through Malta airfield selection');
  await click('depart_button');
  await wait(() => window.firstSortieState.on_foot && !window.firstSortieState.audio.music_playing && window.firstSortieState.fleet_count === 6);
  check(!(await state()).audio.engine_playing, 'Parked Malta aircraft remain silent before boarding');
  await page.keyboard.press('e');
  await wait(() => !window.firstSortieState.on_foot);
  check(!(await state()).audio.engine_playing, 'Boarding leaves the engine sound stopped');
  await page.keyboard.press('i');
  await wait(() => window.firstSortieState.audio.engine_gain > 0.99);
  check(await measure('Malta Spitfire idle') > 0.0001, 'I starts real Spitfire engine audio in Malta');
  await page.keyboard.press('i');
  await wait(() => !window.firstSortieState.audio.engine_playing);
  check(!(await state()).audio.engine_playing, 'I shutdown stops the engine loops');
  await page.keyboard.press('e');
  await wait(() => window.firstSortieState.on_foot);
  await page.keyboard.press('r');
  await wait(() => window.firstSortieState.on_foot && window.firstSortieState.hp === 100 && window.firstSortieState.enemy_count === 1);
  check(!(await state()).audio.engine_playing && !(await state()).audio.music_playing, 'Full Malta restart leaves parked engines and menu music off');
  check(errors.length === 0, 'Release export has no browser runtime errors');
  fs.writeFileSync('/tmp/first-sortie-web-checks/audio-results.json', JSON.stringify({checks, errors, measurements, sources:await page.evaluate(() => window.sourceStarts), state:await state()}, null, 2));
  console.log(`AUDIO WEB RESULT: ${checks}/${checks} passed`);
 } finally {if(browser) await browser.close(); server.kill();}
})().catch(error => {console.error(error); process.exitCode = 1;});
