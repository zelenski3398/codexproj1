const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');const assert=require('node:assert/strict');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8776','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page;let count=0;const errors=[];
 const check=(value,text)=>{assert.ok(value,text);count++;console.log('PASS: '+text);};
 try{
 await delay(400);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 page=await browser.newPage({viewport:{width:1280,height:800}});
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 const state=()=>page.evaluate(()=>window.firstSortieState);
 const wait=(fn,arg=null)=>page.waitForFunction(fn,arg,{timeout:120000});
 const click=async name=>{const [x,y]=(await state())[name];await page.mouse.click(x,y);};
 const travel=async index=>{
  await page.keyboard.press('m');await wait(()=>window.firstSortieState.map_open);
  await click('travel_picker');
  for(let i=0;i<9&&(await state()).travel_popup_focus!==index;i++){await page.keyboard.press('ArrowDown');await delay(250);}
  await page.keyboard.press('Enter');await wait(i=>window.firstSortieState.travel_selected===i,index);
  check((await state()).travel_selected===index,'Travel selector chooses destination '+index);
  await click('travel_button');await wait(()=>!window.firstSortieState.map_open);await delay(300);
 };
 await page.goto('http://127.0.0.1:8776/index.html?smoke=1');await wait(()=>window.firstSortieState?.selecting);
 await click('malta_button');await wait(()=>window.firstSortieState.airfield_selecting);
 await click('st_elmo_button');await wait(()=>window.firstSortieState.home_airfield==='st_elmo');
 check((await state()).home_airfield==='st_elmo','Existing departure map selects Fort St Elmo');
 await click('depart_button');await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.fort?.guns===3);
 const world=(await state()).world_id;
 check((await state()).fort.seated.every(Boolean)&&(await state()).aa_count===18,'Browser loads three crewed Bofors and retains eighteen airfield guns');
 check((await state()).fort.spawn==='st_elmo'&&(await state()).fort.shots.every(v=>v===0),'Fort departure starts on foot with idle guns');
 await travel(4);
 check((await state()).ground_prompt.includes('Mount AA Gun'),'In-game map travel reaches a safe first-gun interaction position');
 await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='gun');await delay(900);
 check(!(await state()).on_foot&&(await state()).fort.crew_waiting[0],'Mounting gives exclusive gun control and moves its crew aside');
 check(!(await state()).travel_enabled,'Mounted gun disables teleport');
 if(!(await state()).aa_mouse.captured){await page.mouse.click(640,400);await delay(300);}
 const captured=(await state()).aa_mouse.captured;
 check(captured,'Gun mount acquires real browser pointer lock');
 await page.mouse.down();await delay(1000);await page.mouse.up();await delay(300);
 check((await state()).fort.shots[0]>0&&(await state()).fort.shots[1]===0&&(await state()).fort.shots[2]===0,'Individual mode fires only the mounted Bofors in the release export');
 await page.keyboard.press('b');await wait(()=>window.firstSortieState.fort.command);
 await page.keyboard.down('f');await delay(2200);await page.keyboard.up('f');await delay(300);
 check((await state()).fort.shots.every(v=>v>0),'Player battery command sends actual rounds from all three guns');
 await page.keyboard.press('Escape');await wait(()=>window.firstSortieState.paused);
 check(!(await state()).fort.command&&!(await state()).aa_mouse.captured,'Pause cancels battery command and releases pointer lock');
 await page.keyboard.press('Escape');await wait(()=>!window.firstSortieState.paused);
 await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.fort.seated[0]);
 check((await state()).fort.seated[0]&&!(await state()).fort.command,'Dismount restores walking and the seated operator');
 await travel(1);check((await state()).world_id===world,'Travel back to Luqa preserves the running world');
 await travel(6);check((await state()).ground_prompt.includes('Mount AA Gun'),'Third-gun destination remains available in-game');
 await page.keyboard.press('r');await wait(id=>window.firstSortieState.world_id!==id&&window.firstSortieState.on_foot,world);
 check((await state()).fort.spawn==='st_elmo'&&(await state()).fort.shots.every(v=>v===0),'Full retry restores original fort spawn with one clean idle battery');
 check(errors.length===0,'No browser runtime/resource errors');
 console.log('Pointer lock acquired on original mount:',captured);
 console.log('ST ELMO WEB RESULT: '+count+'/'+count+' passed');
 }catch(e){console.error('State:',await page?.evaluate(()=>window.firstSortieState));console.error(errors);throw e;}
 finally{await browser?.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
