// Actual production menu and gameplay inputs; opt-in telemetry is read-only.
const {chromium}=require('playwright');const {spawn}=require('node:child_process');const path=require('node:path');const assert=require('node:assert/strict');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8797','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page,timer,passed=0;const errors=[];
 const check=(ok,text)=>{assert.ok(ok,text);passed++;console.log('PASS:',text);};
 try{
  await sleep(500);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:240000});
  timer=setInterval(async()=>{try{const s=await state();console.log('WEB PROGRESS:',JSON.stringify({intro:s?.startup_intro?.phase,trees:s?.vegetation?.count,ground:s?.on_foot}));}catch{}},20000);
  await page.goto('http://127.0.0.1:8797/index.html?smoke=1');await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  let [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);await wait(()=>!window.firstSortieState.startup_intro.active);
  [x,y]=(await state()).fly_button;await page.mouse.click(x,y);await wait(()=>window.firstSortieState?.vegetation?.count>2500&&window.firstSortieState.on_foot);
  let s=await state();const world=s.world_id;
  check(s.countryside.plots>7000&&s.countryside.plots<12000&&s.countryside.wall_m>44000,'Revised fields and existing physical wall budget load in the actual browser game');
  check(s.vegetation.count===4800&&Object.values(s.vegetation.species).every(n=>n>500),'All three planted tree species load in continuous Malta');
  check(s.vegetation.meshes===18&&s.vegetation.batches<s.vegetation.count*2,'Nine variants and both LODs use shared meshes and spatial batches');
  check(s.vegetation.opaque&&s.vegetation.near===380&&s.vegetation.far===2200,'Opaque Compatibility material and bounded LOD distances are active');
  check(s.vegetation.colliders<=s.vegetation.collider_cap&&s.vegetation.colliders===0,'Protected hangar/airfield spawn remains clear of trunk collision');
  await page.keyboard.press('e');await wait(()=>!window.firstSortieState.on_foot&&window.firstSortieState.minimal_hud.parts);
  check((await state()).world_id===world,'Boarding retains the same world with revised rural scenery');
  await page.keyboard.press('F1');await wait(()=>window.firstSortieState.minimal_hud.help);await page.setViewportSize({width:800,height:500});await sleep(500);await page.keyboard.press('Escape');await wait(()=>!window.firstSortieState.paused);
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot);
  check((await state()).vegetation.count===4800&&(await state()).world_id===world,'Help, resize and dismount preserve one stable tree population');
  await page.screenshot({path:'/tmp/rural-vegetation-browser.png'});
  check(errors.length===0,'No JavaScript, shader, engine or missing-resource errors');
  console.log(`RURAL VEGETATION WEB RESULT: ${passed}/${passed} passed`);
 }finally{clearInterval(timer);if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
