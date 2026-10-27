// Actual production build. Inputs are real keyboard/pointer events; diagnostics
// are read-only. No pose, damage, mission clock or recovery state is assigned.
const {chromium}=require('playwright');const {spawn}=require('node:child_process');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');const crypto=require('node:crypto');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8791','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,progress,count=0;const errors=[];
 const check=(ok,text)=>{assert.ok(ok,text);count++;console.log('PASS: '+text);};
 try{
  await sleep(500);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:800,height:500}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.error('WEB ERROR:',m.text());}});page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:240000});
  progress=setInterval(async()=>{try{console.log('WEB PROGRESS',await page.evaluate(()=>({intro:window.firstSortieState?.startup_intro,recovery:window.firstSortieState?.recovery,mode:window.firstSortieState?.ground_mode,position:window.firstSortieState?.ground_position,yaw:window.firstSortieState?.pilot_yaw,paused:window.firstSortieState?.paused})));}catch{}},15000);
  await page.goto('http://127.0.0.1:8791/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  let initial=await state();const position=initial.startup_intro.video_position;
  const posterBefore=crypto.createHash('sha256').update(await page.screenshot()).digest('hex');
  await wait(old=>window.firstSortieState.startup_intro.video_position!==old,position);
  check((await state()).startup_intro.video_playing,'Poster video clock advances before any user gesture');
  const posterAfter=crypto.createHash('sha256').update(await page.screenshot()).digest('hex');check(posterAfter!==posterBefore,'Browser renders changing poster frames');
  let wrapped=false;let last=(await state()).startup_intro.video_position;const limit=Date.now()+45000;
  while(Date.now()<limit){await sleep(300);let value=(await state()).startup_intro.video_position;if(value<last-.5){wrapped=true;break;}last=value;}
  check(wrapped&&(await state()).startup_intro.video_restarts===0,'Poster loops through the end of the clip without a forced decoder restart');
  const [px,py]=(await state()).startup_intro.play_button;await page.mouse.click(px,py);
  await wait(()=>window.firstSortieState?.startup_intro?.active===false);
  await page.keyboard.press('2');await wait(()=>window.firstSortieState.selected==='sea_gladiator');
  const [x,y]=(await state()).fly_button;await page.mouse.click(x,y);
  await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.hangar_parked===9);
  const before=await state();const ids=before.fleet.map(a=>a.id);
  check(before.environment==='malta'&&before.selected==='sea_gladiator'&&before.pilot_hp===100,'Fresh primary free-roam action opens Malta on foot with selected Gladiator');
  check(before.fleet.every(a=>a.hp===100&&!a.engine)&&before.hangar_parked===9,'All nine available aircraft spawn parked inside hangars with engines stopped');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='aircraft');
  for(let i=0;i<10;i++){await page.keyboard.press('h');await sleep(150);}
  await wait(()=>window.firstSortieState.hp===0);let disabled=await state();
  check(disabled.pilot_hp===100&&!disabled.encounter.ended,'Zero aircraft HP does not kill pilot or end free roam');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot);
  const abandoned=await state();await page.keyboard.press('v');await page.keyboard.press('v');
  await wait(()=>window.firstSortieState.recovery.state==='REQUESTED');
  check((await state()).recovery.requests===1,'Real V input latches repeated recovery requests');
  await wait(()=>window.firstSortieState.recovery.state==='READY');
  const arrived=await state();check(arrived.truck_count===4&&Math.hypot(arrived.ground_position[0]-abandoned.ground_position[0],arrived.ground_position[2]-abandoned.ground_position[2])<1,'One truck arrives without teleporting the pilot');
  // Closed-loop walking through the existing W / arrow-key controls.
  const travelDeadline=Date.now()+240000;
  while(Date.now()<travelDeadline){
   const s=await state();const p=s.ground_position,t=s.recovery.truck_position;
   if(Math.hypot(t[0]-p[0],t[2]-p[2])<3.8)break;
   const desired=Math.atan2(-(t[0]-p[0]),-(t[2]-p[2]));const error=Math.atan2(Math.sin(desired-s.pilot_yaw),Math.cos(desired-s.pilot_yaw));
   await page.keyboard.up('ArrowLeft');await page.keyboard.up('ArrowRight');await page.keyboard.up('w');
   if(Math.abs(error)>.10)await page.keyboard.down(error>0?'ArrowLeft':'ArrowRight');
   if(Math.abs(error)<.35)await page.keyboard.down('w');await sleep(120);
  }
  for(const key of ['w','ArrowLeft','ArrowRight'])await page.keyboard.up(key);
  check((await state()).ground_prompt.includes('recovery truck'),'Actual walking reaches the recovery truck prompt');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.recovery.returns===1&&window.firstSortieState.recovery.state==='IDLE');
  const returned=await state();check(returned.on_foot&&returned.pilot_hp===100&&returned.truck_count===3&&returned.world_id===before.world_id,'Truck entry returns pilot on foot without resetting world or health');
  check(JSON.stringify(returned.fleet.map(a=>a.id))===JSON.stringify(ids)&&returned.fleet.some(a=>a.hp===0&&a.destroyed),'Recovery preserves fleet identities and the destroyed aircraft');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='aircraft'&&window.firstSortieState.hp===100);
  check((await state()).pilot_hp===100,'Survivor boards a different serviceable replacement aircraft');
  await page.screenshot({path:'/tmp/recovery-browser-returned.png'});
  await page.keyboard.press('Escape');await wait(()=>window.firstSortieState.paused);
  const [mx,my]=(await state()).change_button;await page.mouse.click(mx,my);
  await wait(()=>window.firstSortieState.startup_intro?.phase===1);
  const returnedPosition=(await state()).startup_intro.video_position;await wait(old=>window.firstSortieState.startup_intro.video_position!==old,returnedPosition);
  check((await state()).startup_intro.video_playing,'Returning from paused gameplay shows one continuously moving poster');
  check(errors.length===0,'No JavaScript, resource, shader or HTTP errors observed');
  fs.writeFileSync('/tmp/recovery-browser-results.json',JSON.stringify({checks:count,errors,before,disabled,arrived,returned},null,2));
  console.log(`PILOT RECOVERY WEB RESULT: ${count}/${count} passed`);
 }finally{clearInterval(progress);await browser?.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
