// Actual exported WebAudio samples; deterministic acoustic fixture, not AI gameplay.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8773','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/flyby-test')],{stdio:'ignore'});
 let browser,page; const errors=[]; let checks=0;
 const check=(v,m)=>{assert.ok(v,m);checks++;console.log('PASS: '+m);};
 try {
  await delay(400);
  browser=await chromium.launch({executablePath:process.env.CHROME_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'],ignoreDefaultArgs:['--mute-audio']});
  page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.addInitScript(()=>{
   window.probes=[];window.sources=[];
   const start=AudioBufferSourceNode.prototype.start;
   AudioBufferSourceNode.prototype.start=function(...args){window.sources.push(this);return start.apply(this,args);};
   const connect=AudioNode.prototype.connect;
   AudioNode.prototype.connect=function(destination,...args){
    if(destination===this.context.destination){
     const splitter=this.context.createChannelSplitter(2);
     const left=this.context.createAnalyser(),right=this.context.createAnalyser();left.fftSize=right.fftSize=2048;
     connect.call(this,splitter);connect.call(splitter,left,0);connect.call(splitter,right,1);
     window.probes.push({left,right});
    }
    return connect.call(this,destination,...args);
   };
  });
  const state=()=>page.evaluate(()=>window.flybyTestState);
  const sample=()=>page.evaluate(()=>{
   const rms=a=>{const x=new Float32Array(2048);a.getFloatTimeDomainData(x);return {rms:Math.sqrt(x.reduce((s,v)=>s+v*v,0)/x.length),peak:Math.max(...x.map(Math.abs))};};
   return window.probes.map(p=>({left:rms(p.left),right:rms(p.right)})).sort((a,b)=>b.left.rms-a.left.rms)[0];
  });
  const select=async m=>{const [x,y]=(await state())[m];await page.mouse.click(x,y);await delay(1300);};
  await page.goto('http://127.0.0.1:8773/index.html');
  await page.waitForFunction(()=>window.flybyTestState?.mode==='far',{timeout:90000});
  await select('far');const far=await sample();
  await select('near');const near=await sample();
  check(far.left.rms>0.00001&&near.left.rms>far.left.rms*5,'Real browser engine samples grow strongly from distant to close');
  check(!(await state()).airflow_supplied&&!(await state()).airflow_playing,'Absent airflow clip remains silent in actual web export');
  await select('approach');const approaching=await state();
  check(approaching.doppler>1.2&&approaching.airflow_gain>.5,'Web approach builds bounded Doppler and close-pass envelope');
  const rates=await page.evaluate(()=>window.sources.filter(s=>s.buffer?.duration>6).map(s=>s.playbackRate.value));
  check(rates.some(v=>v>1.15),'Actual browser sample playback rate includes approaching Doppler');
  await select('recede');const receding=await state();
  check(receding.doppler<.85&&receding.flight_pitch<approaching.flight_pitch,'Receding web engine drops pitch');
  await select('left');const left=await sample();
  await select('right');const right=await sample();
  check(left.left.rms>left.right.rms*1.2&&right.right.rms>right.left.rms*1.2,'Real browser stereo samples pan left and right');
  await select('matching');await delay(4000);
  check((await state()).airflow_gain<.01&&Math.abs((await state()).doppler-1)<.001,'Matched-speed web aircraft has no sustained airflow or Doppler');
  check(near.left.peak<.95&&left.left.peak<.95&&right.right.peak<.95,'Measured browser output preserves peak headroom');
  await select('stop');
  check(!(await state()).playing,'Engine shutdown stops the browser engine source');
  check((await sample()).left.rms<.0001,'Actual browser engine output becomes silent after shutdown');
  check(errors.length===0,'No browser script, resource or audio errors');
  const results={checks,far,near,left,right,approaching,receding,rates,errors};
  fs.writeFileSync('/tmp/flyby-web-results.json',JSON.stringify(results,null,2));
  console.log('FLYBY WEB RESULT: '+checks+'/'+checks+' passed');
 }catch(e){console.error('State:',await page?.evaluate(()=>window.flybyTestState));console.error(errors);throw e;}
 finally{await browser?.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
