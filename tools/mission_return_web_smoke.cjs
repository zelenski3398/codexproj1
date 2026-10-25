// Isolated production-controller fixture, not a claimed full mission playthrough.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');const path=require('node:path');const assert=require('node:assert/strict');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8795','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/return-test')],{stdio:'ignore'});
 let browser,page,passed=0;const errors=[];
 const check=(ok,text)=>{assert.ok(ok,text);passed++;console.log('PASS:',text);};
 try{
  await sleep(500);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.returnTestState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:240000});
  const click=async name=>{const [x,y]=(await state())[name];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8795/index.html');await wait(()=>window.returnTestState?.phase==='TAKEOFF'&&window.returnTestState.speed>40);
  const world=(await state()).world;
  await click('Secure objectives (fixture)');await wait(()=>window.returnTestState.pending);
  check((await state()).phase==='RETURNING'&&!(await state()).panel&&!(await state()).congratulations,'Airborne success holds panel and congratulations');
  await sleep(1500);check((await state()).objective.includes('Return and land'),'Browser tracker guides the return flight');
  await page.screenshot({path:'/tmp/mission-return-browser-airborne.png'});
  await click('Land (pose fixture)');await wait(()=>window.returnTestState.phase==='SUCCESS');
  check((await state()).panel&&(await state()).count===1&&(await state()).wheels>=2,'Real suspension settlement releases one result panel');
  check((await state()).congratulations&&(await state()).voice_playing,'Supplied congratulations recording starts after landing');
  check((await state()).world===world,'Return and landing retain the same continuous world');
  await page.screenshot({path:'/tmp/mission-return-browser-landed.png'});
  await click('Retry');await wait(()=>window.returnTestState.phase==='TAKEOFF'&&window.returnTestState.speed>40);
  check(!(await state()).pending&&!(await state()).panel&&!(await state()).congratulations,'Retry clears pending return, results and radio latch');
  await click('Secure objectives (fixture)');await wait(()=>window.returnTestState.pending);await click('Crash (fixture)');
  await wait(()=>window.returnTestState.phase==='FAILED');
  check((await state()).panel&&!(await state()).congratulations&&(await state()).count===1,'Crash during return fails once without congratulations');
  check(errors.length===0,'No JavaScript or engine errors in browser fixture');
  console.log(`MISSION RETURN WEB RESULT: ${passed}/${passed} passed`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
