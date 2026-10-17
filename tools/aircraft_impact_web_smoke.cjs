// Production release UI and physical lifecycle. Component debug tools are
// intentionally unavailable in a normal release; the separate fixture checks
// localized failures instead of enabling developer tools in the shipped game.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8779','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page,progress;const errors=[];let count=0;
 const check=(value,message)=>{assert.ok(value,message);count++;console.log('PASS: '+message);};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.error('BROWSER:',m.text());}});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:180000});
  await page.goto('http://127.0.0.1:8779/index.html?smoke=1');
  progress=setInterval(async()=>{try{console.log('BROWSER PROGRESS:',await page.evaluate(()=>({state:window.firstSortieState?.startup_intro,text:document.body.innerText.slice(-250)})));}catch{}},15000);
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  const [px,py]=(await state()).startup_intro.play_button;
  await page.mouse.click(px,py);
  await wait(()=>window.firstSortieState?.startup_intro?.active===false);
  check((await state()).selecting,'Integrated poster Play fades into the existing browser menu');
  const [x,y]=(await state()).fly_button;await page.mouse.click(x,y);
  await wait(()=>window.firstSortieState?.impact&&!window.firstSortieState.selecting);
  check((await state()).selected==='spitfire'&&(await state()).impact.model_visible,'Release export loads intact Spitfire');
  check((await state()).component_hud.visible&&Object.keys((await state()).component_hud.parts).length===12&&Object.values((await state()).component_hud.parts).every(v=>v===1),'Twelve healthy component readouts appear in release browser HUD');
  await page.keyboard.press('F3');await delay(400);
  check(!(await state()).debug_visible,'Developer damage tools stay disabled in normal release gameplay');
  for(let i=0;i<10;i++){await page.keyboard.press('h');await delay(180);}
  await wait(()=>window.firstSortieState?.destroyed);
  check((await state()).impact.fragments===0&&(await state()).impact.model_visible,'Hull depletion leaves intact disabled aircraft rather than mandatory explosion');
  check(!(await state()).impact.water,'Ground-start hull loss is not misclassified as sea impact');
  await page.keyboard.press('r');
  await wait(()=>window.firstSortieState.hp===100&&!window.firstSortieState.impact.started);
  check((await state()).impact.fragments===0&&(await state()).impact.model_visible,'Browser reset clears wreck state and restores aircraft');
  check(Object.values((await state()).component_hud.parts).every(v=>v===1),'Browser reset restores all component readouts');
  await page.screenshot({path:'/tmp/universal-browser-release.png'});
  check(errors.length===0,'No browser script, resource or WebGL errors');
  console.log('AIRCRAFT IMPACT WEB RESULT: '+count+'/'+count+' passed');
 }catch(e){console.error(errors);if(page&&!page.isClosed()){try{console.error(await page.evaluate(()=>window.firstSortieState));}catch{}}throw e;}
 finally{if(progress)clearInterval(progress);if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
