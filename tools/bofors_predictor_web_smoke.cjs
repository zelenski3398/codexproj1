// Production export, actual menu/walking/mouse/key input; telemetry is read-only.
const {chromium}=require('playwright');const {spawn}=require('node:child_process');
const path=require('node:path');const assert=require('node:assert/strict');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8793','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page,progress,count=0;const errors=[];
 const check=(ok,text)=>{assert.ok(ok,text);console.log('PASS:',text);count++;};
 try{
  await sleep(500);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  page=await browser.newPage({viewport:{width:800,height:500}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.error('WEB ERROR:',m.text());}});page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:240000});
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  progress=setInterval(async()=>{try{console.log('WEB PROGRESS:',await page.evaluate(()=>({intro:window.firstSortieState?.startup_intro?.phase,mode:window.firstSortieState?.ground_mode,prompt:window.firstSortieState?.ground_prompt,posts:window.firstSortieState?.bofors_posts?.map(p=>({field:p.field,mounted:p.mounted,target:p.target,observed:p.observed,assigned:p.assigned})),lead:window.firstSortieState?.bofors_lead})));}catch{}},20000);
  await page.goto('http://127.0.0.1:8793/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  let [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);await wait(()=>!window.firstSortieState.startup_intro.active);
  await click('malta_button');await wait(()=>window.firstSortieState.airfield_selecting);
  await click('st_elmo_button');await wait(()=>window.firstSortieState.home_airfield==='st_elmo');await click('depart_button');
  await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.bofors_posts?.length===4);
  const initial=await state(),world=initial.world_id;
  check(initial.command_posts.length===3&&initial.aa_count===18&&initial.fort.guns===3,'Four Bofors predictors export alongside all original heavy posts and guns');
  check(initial.bofors_mode===0&&initial.bofors_posts.every(p=>p.assigned===0),'Fresh browser session starts in Manual with no automatic assignments');
  const goal=initial.bofors_posts.find(p=>p.field==='st_elmo').approach;
  check(Math.abs(initial.ground_position[1]-goal[1])<.6,'Fort predictor approach shares the soldier\'s accessible deck');
  const held=new Set();
  for(let tick=0;tick<180;tick++){
   const s=await state(),p=s.ground_position,dx=goal[0]-p[0],dz=goal[2]-p[2];if(Math.hypot(dx,dz)<.8||s.ground_prompt.includes('F Operate Bofors'))break;
   const lx=Math.cos(s.pilot_yaw)*dx-Math.sin(s.pilot_yaw)*dz,lz=Math.sin(s.pilot_yaw)*dx+Math.cos(s.pilot_yaw)*dz,wanted=new Set();
   if(Math.abs(lx)>.4)wanted.add(lx>0?'d':'a');if(Math.abs(lz)>.4)wanted.add(lz>0?'s':'w');
   for(const key of held)if(!wanted.has(key)){await page.keyboard.up(key);held.delete(key);}
   for(const key of wanted)if(!held.has(key)){await page.keyboard.down(key);held.add(key);}
   await sleep(150);
  }
  for(const key of held)await page.keyboard.up(key);
  check((await state()).ground_prompt.includes('F Operate Bofors'),'Normal walking reaches a usable Fort St Elmo predictor');
  await page.keyboard.press('f');await wait(()=>window.firstSortieState.bofors_posts.some(p=>p.mounted));
  if(!(await state()).aa_mouse.captured){await page.mouse.click(400,250);await sleep(500);}
  check(!(await state()).on_foot&&(await state()).fort.shots.every(v=>v===0),'F gives exclusive optics control without firing a gun');
  const before=(await state()).bofors_posts.find(p=>p.mounted);
  await page.mouse.move(200,150,{steps:8});await sleep(1000);
  check((await state()).bofors_posts.find(p=>p.mounted).yaw!==before.yaw,'Relative mouse moves the actual observation optics');
  await page.mouse.down({button:'right'});await wait(()=>window.firstSortieState.aa_mouse.fov<36);await page.mouse.up({button:'right'});
  check((await state()).aa_mouse.fov<36,'RMB provides magnified binocular observation');
  await wait(()=>window.firstSortieState.aa_mouse.fov>55);
  await page.keyboard.press('c');await wait(()=>window.firstSortieState.enemy_count===1);
  // Initial encounter is northwest of the player. Sweep optics manually until
  // the real observer reports a visible contact, then use normal TAB/ENTER.
  for(let i=0;i<16&&!((await state()).bofors_posts.find(p=>p.mounted).observed);i++){
   await page.mouse.move(200+(i%2?-70:70),150-(i<3?25:0),{steps:4});await sleep(500);
  }
  await wait(()=>window.firstSortieState.bofors_posts.some(p=>p.mounted&&p.observed>0));
  await page.keyboard.press('Tab');await wait(()=>window.firstSortieState.bofors_posts.some(p=>p.mounted&&p.target));
  await page.keyboard.press('Enter');await wait(()=>window.firstSortieState.bofors_posts.some(p=>p.mounted&&p.assigned===3&&p.valid>0));
  check((await state()).fort.shots.every(v=>v===0),'Observed aircraft receives a battery assignment and solutions without automatic fire');
  await page.keyboard.press('f');await wait(()=>window.firstSortieState.on_foot);
  await page.keyboard.press('m');await wait(()=>window.firstSortieState.map_open);await sleep(1000);await click('travel_picker');
  for(let i=0;i<10&&(await state()).travel_popup_focus!==4;i++){
   const focus=(await state()).travel_popup_focus;await page.keyboard.press('ArrowDown');
   await wait(old=>window.firstSortieState.travel_popup_focus!==old,focus);
  }
  await page.keyboard.press('Enter');await wait(()=>window.firstSortieState.travel_selected===4);await click('travel_button');await wait(()=>!window.firstSortieState.map_open);
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='gun');
  await page.keyboard.press('Escape');await wait(()=>window.firstSortieState.paused);await sleep(1000);await click('bofors_mode_picker');
  for(let i=0;i<5&&(await state()).bofors_mode_popup_focus!==2;i++){
   const focus=(await state()).bofors_mode_popup_focus;await page.keyboard.press('ArrowDown');
   await wait(old=>window.firstSortieState.bofors_mode_popup_focus!==old,focus);
  }
  await page.keyboard.press('Enter');await wait(()=>window.firstSortieState.bofors_mode===2);
  check((await state()).bofors_mode===2,'Native Godot pause settings select Training in the browser');
  await page.keyboard.press('Escape');await wait(()=>!window.firstSortieState.paused);await page.mouse.click(400,250);await sleep(400);
  await wait(()=>window.firstSortieState.bofors_lead.yaw_error!==undefined);
  for(let i=0;i<30;i++){
   const s=await state(),lead=s.bofors_lead;if(lead.visible)break;
   const dx=Math.max(-70,Math.min(70,-lead.yaw_error/.16)),dy=Math.max(-50,Math.min(50,-lead.pitch_error/.16));
   await page.mouse.move(400+dx,250+dy,{steps:4});await sleep(400);
  }
  await wait(()=>window.firstSortieState.bofors_lead.visible);
  check((await state()).bofors_lead.visible,'Assigned physical lead diamond renders in the mounted browser sight');
  await page.screenshot({path:'/tmp/bofors-browser-training.png'});
  await page.mouse.down();await wait(()=>window.firstSortieState.fort.shots.some(v=>v>0));await page.mouse.up();
  check((await state()).fort.shots[0]>0,'Only explicit LMB input fires the existing Bofors');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot);
  check((await state()).world_id===world,'Post/gun/walking transitions preserve the continuous world');
  check(errors.length===0,'No JavaScript, shader or missing-resource errors');
  console.log('BOFORS WEB RESULT: '+count+'/'+count+' passed');
 }catch(e){if(page){console.error('LAST STATE:',JSON.stringify(await page.evaluate(()=>window.firstSortieState)));await page.screenshot({path:'/tmp/bofors-browser-failure.png'});}throw e;}
 finally{clearInterval(progress);if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
