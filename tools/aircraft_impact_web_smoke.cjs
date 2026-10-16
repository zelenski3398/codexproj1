// Release WebGL game, real keyboard input; no runtime fixture mutations.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8779','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page;const errors=[];let count=0;
 const check=(value,message)=>{assert.ok(value,message);count++;console.log('PASS: '+message);};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:120000});
  await page.goto('http://127.0.0.1:8779/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.selecting);
  const [x,y]=(await state()).fly_button;await page.mouse.click(x,y);
  await wait(()=>window.firstSortieState?.impact&&!window.firstSortieState.selecting);
  check((await state()).selected==='spitfire'&&(await state()).impact.model_visible,'Release export loads redesigned intact Spitfire');
  for(let i=0;i<10;i++){await page.keyboard.press('h');await delay(180);}
  await wait(()=>window.firstSortieState.impact.fragments===8);
  check((await state()).destroyed&&!(await state()).impact.model_visible,'Real ground destruction replaces aircraft with eight physical pieces');
  check(!(await state()).impact.water,'Runway impact uses dry explosion path');
  await page.keyboard.press('r');
  await wait(()=>window.firstSortieState.hp===100&&!window.firstSortieState.impact.started);
  check((await state()).impact.fragments===0&&(await state()).impact.model_visible,'Browser reset clears wreckage and restores aircraft');
  check(errors.length===0,'No browser script, resource or WebGL errors');
  console.log('AIRCRAFT IMPACT WEB RESULT: '+count+'/'+count+' passed');
 }catch(e){console.error(errors);if(page)console.error(await page.evaluate(()=>window.firstSortieState));throw e;}
 finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
