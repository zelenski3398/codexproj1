const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8774','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,checks=0;const errors=[];
 const check=(v,t)=>{assert.ok(v,t);checks++;console.log('PASS: '+t)};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=async(fn,arg=null)=>{try{return await page.waitForFunction(fn,arg,{timeout:150000})}catch(e){console.error('STATE',JSON.stringify(await state()),'ERRORS',errors);await page.screenshot({path:'/tmp/battery-browser-failure.png'});throw e}};
  const click=async key=>{const p=(await state())[key];await page.mouse.click(p[0],p[1])};
  await page.goto('http://127.0.0.1:8774/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.selecting);
  await click('missions_button');await wait(()=>window.firstSortieState.missions_selecting);
  await click('mission_picker');await page.keyboard.press('ArrowUp');await page.keyboard.press('Enter');
  await wait(()=>window.firstSortieState.mission_selected===1);await click('mission_depart_button');
  await wait(()=>window.firstSortieState.command_posts?.length===3 && window.firstSortieState.defence_sounds?.intro_count===1);
  check((await state()).aa_count===18,'Browser world retains four heavy and two Bofors per field plus one separate command post');
  check((await state()).defence_sounds.intro_count===1,'Supplied Harrington mission introduction starts once in web build');
  const goal=(await state()).command_posts.find(p=>p.field==='luqa').position;
  const held=new Set();
  for(let tick=0;tick<500;tick++){
   const s=await state(),p=s.ground_position,dx=goal[0]-p[0],dz=goal[2]-p[2];
   if(Math.hypot(dx,dz)<3.6)break;
   const localX=Math.cos(s.pilot_yaw)*dx-Math.sin(s.pilot_yaw)*dz;
   const localZ=Math.sin(s.pilot_yaw)*dx+Math.cos(s.pilot_yaw)*dz;
   const wanted=new Set();
   if(Math.abs(localX)>.7)wanted.add(localX>0?'d':'a');
   if(Math.abs(localZ)>.7)wanted.add(localZ>0?'s':'w');
   for(const key of held)if(!wanted.has(key)){await page.keyboard.up(key);held.delete(key)}
   for(const key of wanted)if(!held.has(key)){await page.keyboard.down(key);held.add(key)}
   await delay(120);
  }
  for(const key of held)await page.keyboard.up(key);
  check((await state()).ground_prompt.includes('F Enter Heavy AA'),'Soldier can walk to accessible command post using existing movement controls');
  await page.keyboard.press('f');await wait(()=>window.firstSortieState.command_posts.some(p=>p.mounted) && document.pointerLockElement!==null);
  check((await state()).command_posts.filter(p=>p.mounted).length===1 && (await state()).aa_shots===0,'F enters command camera without firing through legacy F gun alias');
  await page.mouse.move(640,290,{steps:8});await delay(500);
  await page.mouse.down({button:'right'});await delay(300);await page.mouse.up({button:'right'});
  await wait(()=>window.firstSortieState.command_posts.some(p=>p.mounted && p.designated && p.valid>0));
  check((await state()).aa_shots===0,'RMB designates target/airspace and computes ballistic solutions without autonomous fire');
  await page.mouse.down();await wait(()=>window.firstSortieState.command_posts.some(p=>p.shots===4));await page.mouse.up();
  const post=(await state()).command_posts.find(p=>p.mounted);
  check(post.salvos===1 && post.shots===4 && (await state()).aa_shots===4,'One LMB decision produces four physical gun shots with individual reloads');
  await page.screenshot({path:'/tmp/battery-command-browser.png'});
  await wait(()=>window.firstSortieState.defence_sounds.warnings.includes(1));
  check((await state()).defence_sounds.warnings.filter(n=>n===1).length===1,'Approaching Stukas activate the supplied air-raid warning once');
  await page.keyboard.press('f');await wait(()=>window.firstSortieState.ground_mode==='walking' && document.pointerLockElement===null);
  check(!(await state()).command_posts.some(p=>p.mounted || p.pending>0),'F dismount restores walking and clears coordinated orders');
  await wait(()=>window.firstSortieState.defence_sounds.dives.some(n=>n>0));
  check((await state()).defence_sounds.dives.some(n=>n>0),'Actual descending Stuka plays spatial supplied Jericho recording in web export');
  check(errors.length===0,'Web export has no script, shader, audio or resource errors');
  console.log(`BATTERY COMMAND WEB RESULT: ${checks}/${checks} passed`);
 }finally{if(browser)await browser.close();server.kill()}
})().catch(e=>{console.error(e);process.exitCode=1});
