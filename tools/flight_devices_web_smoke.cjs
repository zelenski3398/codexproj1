// Actual production export, menu and aircraft keys; read-only telemetry.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8797','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,passed=0;const errors=[];
 const check=(ok,label)=>{assert.ok(ok,label);passed++;console.log('PASS:',label);};
 try{
  await sleep(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:1100,height:700}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=f=>page.waitForFunction(f,null,{timeout:240000});
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8797/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  const [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);
  await wait(()=>!window.firstSortieState.startup_intro.active);await click('fly_button');
  await wait(()=>window.firstSortieState.on_foot);
  await page.keyboard.press('e');await wait(()=>!window.firstSortieState.on_foot);
  const shots=(await state()).shots;
  await page.keyboard.press('q');await wait(()=>window.firstSortieState.flaps>.3);
  check((await state()).shots===shots,'Q deploys actual flaps without firing browser guns');
  await page.screenshot({path:'/tmp/flight-devices-browser-deployed.png'});
  await page.keyboard.press('F1');await wait(()=>window.firstSortieState.minimal_hud.help);
  check((await state()).minimal_hud.help_text.includes('Landing flaps')||(await state()).minimal_hud.help_text.includes('landing flaps'),'Controls view describes flaps');
  const ratio=(await state()).flaps;
  await page.keyboard.press('q');await page.keyboard.press('b');await sleep(400);
  check(Math.abs((await state()).flaps-ratio)<.08,'Help pauses deployment and blocks device commands');
  await page.keyboard.press('Escape');await wait(()=>!window.firstSortieState.paused);
  await page.keyboard.press('b');await wait(()=>window.firstSortieState.device_notice==='AIRBRAKES UNAVAILABLE');
  check((await state()).airbrakes===0,'Spitfire has no silently invented dedicated airbrakes');
  await page.setViewportSize({width:800,height:500});
  await page.keyboard.press('q');await wait(()=>window.firstSortieState.flaps===0);
  check((await state()).flaps===0,'Q retracts flaps smoothly to clean position');
  await page.keyboard.down('f');await sleep(700);await page.keyboard.up('f');
  check((await state()).shots>shots&&(await state()).fire_guide==='F','F retains functional browser aircraft guns');
  await page.screenshot({path:'/tmp/flight-devices-browser.png'});
  check(errors.length===0,'Compatibility browser export has no resource or script errors');
  console.log(`FLIGHT DEVICES WEB RESULT: ${passed}/${passed} passed`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
