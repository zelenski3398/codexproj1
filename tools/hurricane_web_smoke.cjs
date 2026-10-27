// Production export, ordinary menu/key inputs, read-only opt-in telemetry.
const {chromium}=require('playwright');const {spawn}=require('node:child_process');
const path=require('node:path');const assert=require('node:assert/strict');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8796','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,page,count=0;const errors=[];
 const check=(ok,label)=>{assert.ok(ok,label);console.log('PASS:',label);count++;};
 try{
  await sleep(500);browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const wait=fn=>page.waitForFunction(fn,null,{timeout:240000});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8796/index.html?smoke=1');await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  const [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);await wait(()=>!window.firstSortieState.startup_intro.active);
  await click('hurricane_button');await wait(()=>window.firstSortieState.selected==='hurricane');
  check((await state()).selecting,'Hurricane preview selected through the actual main-menu button');
  await page.screenshot({path:'/tmp/hurricane-browser-menu.png'});await click('fly_button');
  await wait(()=>window.firstSortieState.on_foot&&window.firstSortieState.fleet_count===9);
  const before=await state(),world=before.world_id,ids=before.fleet.map(a=>a.id).sort();
  check(before.environment==='malta'&&before.fleet.filter(a=>a.kind==='hurricane').length===3,'Menu launch enters Malta with one Hurricane per airfield');
  check(before.fleet.every(a=>a.hp===100&&!a.engine)&&before.fleet.filter(a=>a.kind==='hurricane').every(a=>a.ports===8),'Parked healthy Hurricanes include all eight exported firing points');
  await page.keyboard.press('e');await wait(()=>!window.firstSortieState.on_foot&&window.firstSortieState.minimal_hud.vital.includes('Hurricane'));
  check(!(await state()).minimal_hud.actions.includes('Enter aircraft'),'Boarding Hurricane clears the entry prompt');
  await page.keyboard.press('i');await wait(()=>window.firstSortieState.engine_running);check((await state()).engine_running,'I starts the selected Hurricane engine manually');
  await page.keyboard.down('f');await wait(()=>window.firstSortieState.shots>=8);await page.keyboard.up('f');
  check((await state()).shots>=8,'Existing browser fire input launches eight-gun physical salvos');
  await page.keyboard.press('F1');await wait(()=>window.firstSortieState.minimal_hud.help&&window.firstSortieState.paused);
  await page.keyboard.press('e');await page.keyboard.press('r');check(!(await state()).on_foot&&(await state()).world_id===world,'Shared help blocks exit and restart behind its overlay');
  await page.keyboard.press('Escape');await wait(()=>!window.firstSortieState.minimal_hud.help&&!window.firstSortieState.paused);
  await page.keyboard.press('i');await wait(()=>!window.firstSortieState.engine_running);await page.keyboard.press('e');await wait(()=>window.firstSortieState.on_foot);
  check((await state()).world_id===world&&JSON.stringify((await state()).fleet.map(a=>a.id).sort())===JSON.stringify(ids),'Exit preserves the same aircraft and world without duplicate spawning');
  await page.screenshot({path:'/tmp/hurricane-browser-hangar.png'});
  check(errors.length===0,'No JavaScript, shader, engine or missing-resource errors');
  console.log(`HURRICANE WEB RESULT: ${count}/${count} passed`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
