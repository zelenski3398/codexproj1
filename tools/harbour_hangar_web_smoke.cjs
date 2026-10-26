// Production export; real menu/key input and read-only smoke telemetry.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8792','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,progress,count=0;const errors=[];
 const check=(ok,label)=>{assert.ok(ok,label);count++;console.log('PASS: '+label);};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:800,height:500}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:240000});
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  progress=setInterval(async()=>{
   try{console.log('Browser progress:',await page.evaluate(()=>({intro:window.firstSortieState?.startup_intro?.phase,selecting:window.firstSortieState?.selecting,missions:window.firstSortieState?.missions_selecting,choice:window.firstSortieState?.mission_selected,on_foot:window.firstSortieState?.on_foot})));}catch{}
  },20000);
  await page.goto('http://127.0.0.1:8792/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  const [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);
  await wait(()=>window.firstSortieState?.startup_intro?.active===false);
  await click('missions_button');await wait(()=>window.firstSortieState.missions_selecting);
  await click('mission_picker');await delay(3000);
  // Mouse-opened Godot popup initially has no keyboard-focused item:
  // the first Down focuses item zero, then two more reach Harbour.
  for(let i=0;i<3;i++){await page.keyboard.press('ArrowDown',{delay:100});await delay(1000);}
  await page.keyboard.press('Enter');
  await wait(()=>window.firstSortieState.mission_selected===2);
  check((await state()).mission_selected===2,'Harbour mission selected through production menu');
  await click('mission_depart_button');await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.fleet_count===7);
  const before=await state();
  check(before.countryside.plots>=7000&&before.countryside.plots<=12000&&before.countryside.clusters>=300&&before.countryside.wall_m>=40000&&before.countryside.near_batches<=before.countryside.near_limit,'Expanded countryside exports and respects near-detail budget');
  check(before.interception_siren.requested&&before.interception_siren.playing&&before.interception_siren.loop&&before.interception_siren.starts===1,'Harbour air-raid recording loops once from mission start');
  check(before.hangar_parked===7&&before.fleet.every(a=>a.hp===100&&!a.engine),'Mission fleet starts serviceable, engines off, in hangars');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='aircraft');
  await delay(3000);
  const aboard=await state();
  check(aboard.pilot_hp===100&&aboard.hp===100&&aboard.world_id===before.world_id,'Real E boarding preserves pilot, aircraft and continuous world');
  await page.screenshot({path:'/tmp/harbour-boarding-web.png'});
  console.log('Boarding view saved for visual inspection: /tmp/harbour-boarding-web.png');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot);
  check((await state()).world_id===before.world_id,'Real E dismount restores on-foot control in same world');
  check(errors.length===0,'No browser, WebGL or missing-resource errors');
  console.log('HARBOUR WEB RESULT: '+count+'/'+count+' passed');
 }finally{
  clearInterval(progress);if(browser)await browser.close();server.kill();
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
