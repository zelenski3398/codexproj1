// Production release and real menu input; read-only ?smoke=1 diagnostics.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8788','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,progress,count=0;const errors=[];
 const check=(ok,label)=>{assert.ok(ok,label);count++;console.log('PASS: '+label);};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:180000});
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8788/index.html?smoke=1');
  progress=setInterval(async()=>{try{console.log('BROWSER PROGRESS:',await page.evaluate(()=>({phase:window.firstSortieState?.startup_intro,hangars:window.firstSortieState?.hangars?.length})));}catch{}},15000);
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  const [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);
  await wait(()=>window.firstSortieState?.startup_intro?.active===false);
  check((await state()).selecting,'Integrated poster reaches unchanged game menu');
  check((await state()).hangars.length===3,'Original runway loads three new hangars in production WebGL build');
  await click('malta_button');await wait(()=>window.firstSortieState.airfield_selecting);
  await click('luqa_button');await wait(()=>window.firstSortieState.home_airfield==='luqa');
  await click('depart_button');await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.hangars.length===6);
  const before=await state();
  check(before.hangars.every(h=>h.width===48&&h.depth===36&&h.door_width===42&&h.trusses===7&&h.meshes===8&&h.hp===250),'All six Malta hangars export with intended dimensions, open-door width, steel and installation HP');
  check(new Set(before.hangars.map(h=>h.roof_mesh)).size===1,'Repeated buildings share merged roof geometry');
  check(before.fleet_count===9&&before.aa_count===18,'Aircraft parking and eighteen airfield AA guns remain present');
  await page.screenshot({path:'/tmp/hangar-browser-luqa.png'});
  await page.keyboard.press('r');await wait(old=>window.firstSortieState.hangars.length===6&&window.firstSortieState.hangars[0].id!==old,before.hangars[0].id);
  const after=await state();
  check(after.on_foot&&after.hangars.every(h=>h.hp===250),'Full session retry recreates exactly six healthy hangars and walking control');
  check(errors.length===0,'No JavaScript, shader, resource or HTTP errors observed');
  fs.writeFileSync('/tmp/hangar-browser-results.json',JSON.stringify({checks:count,errors,before,after},null,2));
  console.log(`HANGAR WEB RESULT: ${count}/${count} passed`);
 }finally{clearInterval(progress);await browser?.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
