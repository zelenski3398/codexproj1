// Tests an isolated exported fixture using the real mixer/radio/voice, never a
// shortcut in the live mission. Mission activation is tested natively instead.
const {chromium} = require('playwright');
const {spawn} = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
 const server = spawn('python3', ['-m','http.server','8769','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/radio-test')], {stdio:'ignore'});
 let browser; let page; let checks = 0; const errors = [];
 const check = (value, message) => {assert.ok(value, message); checks++; console.log('PASS: ' + message);};
 try {
  await delay(500);
  browser = await chromium.launch({executablePath:process.env.CHROME_BIN || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'],ignoreDefaultArgs:['--mute-audio']});
  page = await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {if(message.type() === 'error') errors.push(message.text());});
  await page.addInitScript(() => {
   window.voiceStarts = [];
   window.audioProbes = [];
   const start = AudioBufferSourceNode.prototype.start;
   AudioBufferSourceNode.prototype.start = function(...args) {
    window.voiceStarts.push({duration:this.buffer?.duration,loop:this.loop});
    return start.apply(this,args);
   };
   const connect = AudioNode.prototype.connect;
   AudioNode.prototype.connect = function(destination, ...args) {
    if(destination === this.context.destination) {
     const analyser = this.context.createAnalyser(); analyser.fftSize = 2048;
     connect.call(this, analyser, ...args); connect.call(analyser, destination);
     window.audioProbes.push({context:this.context, analyser}); return destination;
    }
    return connect.call(this, destination, ...args);
   };
  });
  const state = () => page.evaluate(() => window.radioTestState);
  const outputRms = () => page.evaluate(() => Math.max(0,...window.audioProbes.map(probe=>{
   const samples=new Float32Array(2048);probe.analyser.getFloatTimeDomainData(samples);
   return Math.sqrt(samples.reduce((sum,x)=>sum+x*x,0)/samples.length);
  })));
  const wait = predicate => page.waitForFunction(predicate, null, {timeout:90000});
  const click = async id => {const [x,y] = (await state())[id]; await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8769/index.html');
  await wait(() => window.radioTestState?.exists && window.firstSortieReady);
  check(!(await state()).playing && !(await state()).subtitle && (await state()).duck_db===0, 'Exported radio starts silent with no subtitle or ducking');
  check(Math.abs((await state()).length-3.831)<0.05, 'Supplied complete recording is included and decoded by the web export');
  await click('transmit');
  await wait(() => window.radioTestState.playing && window.radioTestState.subtitle);
  check((await state()).transmissions===1 && (await state()).text.includes('Italian formation detected, one o’clock — intercept!'), 'One supplied transmission displays the exact commander subtitle');
  check((await state()).duck_db===-4 && Math.abs((await state()).engine_db-(20*Math.log10(0.6)-4))<0.01 && Math.abs((await state()).guns_db-(20*Math.log10(0.5)-4))<0.01, 'Web engine/gun buses duck 4 dB while retaining their user levels');
  let rms = 0;
  for(let i=0;i<8;i++) {
   await delay(100);
   rms=Math.max(rms, await outputRms());
  }
  console.log('Commander WebAudio RMS:',rms);
  check(rms>0.001,'Commander recording produces nonzero real WebAudio output');
  check(await page.evaluate(() => window.voiceStarts.filter(source=>Math.abs(source.duration-3.831)<0.05 && !source.loop).length===1),'Browser sample backend starts the commander exactly once without looping');
  await click('transmit');
  check((await state()).transmissions===1,'Repeated transmit clicks cannot overlap speech');
  fs.mkdirSync('/tmp/malta-radio-web-checks',{recursive:true});
  await page.screenshot({path:'/tmp/malta-radio-web-checks/subtitle.png'});
  await wait(() => !window.radioTestState.playing && !window.radioTestState.subtitle && window.radioTestState.duck_db===0);
  check(Math.abs((await state()).engine_db-20*Math.log10(0.6))<0.01 && Math.abs((await state()).guns_db-20*Math.log10(0.5))<0.01,'Natural web playback completion restores both previous bus levels');
  await click('transmit');
  check((await state()).transmissions===1 && !(await state()).playing,'Completed transmission stays latched until retry');
  await click('retry'); await wait(()=>!window.radioTestState.triggered);
  await click('transmit'); await wait(()=>window.radioTestState.playing);
  check((await state()).transmissions===1,'Retry resets the trigger and permits one fresh transmission');
  await click('cancel'); await wait(()=>!window.radioTestState.playing && !window.radioTestState.subtitle && window.radioTestState.duck_db===0);
  check((await state()).duck_db===0,'Cancelling during speech stops web playback and ducking');
  await delay(200);
  check(await outputRms()<0.0001,'Cancellation also silences the actual WebAudio voice');
  await click('retry'); await wait(()=>!window.radioTestState.triggered);
  await click('transmit'); await wait(()=>window.radioTestState.playing);
  await click('leave'); await wait(()=>!window.radioTestState.exists && window.radioTestState.duck_db===0);
  check(!(await state()).exists,'Leaving removes the radio and restores its mix');
  await delay(200);
  check(await outputRms()<0.0001,'No voice sample remains audible after leaving');
  check(errors.length===0,'No browser script, resource or audio errors');
  console.log('RADIO WEB RESULT: '+checks+'/'+checks+' passed');
 } catch(error) {
  console.error('Last radio state:', await page?.evaluate(()=>window.radioTestState));
  console.error('Browser errors:',errors);
  throw error;
 } finally {if(browser)await browser.close();server.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
