const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8767','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser;let checks=0;const errors=[];
 const check=(value,text)=>{assert.ok(value,text);checks++;console.log('PASS: '+text);};
 try{
  await delay(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=fn=>page.waitForFunction(fn,null,{timeout:120000});
  const click=async id=>{const [x,y]=(await state())[id];await page.mouse.click(x,y);};
  const walk=async(target,distance)=>{
   for(let step=0;step<700;step++){
    const s=await state();const p=s.ground_position;
    const dx=target[0]-p[0],dz=target[2]-p[2];
    if(Math.hypot(dx,dz)<distance){for(const key of ['w','ArrowLeft','ArrowRight'])await page.keyboard.up(key);return;}
    const desired=Math.atan2(-dx,-dz);
    let error=Math.atan2(Math.sin(desired-s.pilot_yaw),Math.cos(desired-s.pilot_yaw));
    for(const key of ['ArrowLeft','ArrowRight'])await page.keyboard.up(key);
    if(Math.abs(error)>.1)await page.keyboard.down(error>0?'ArrowLeft':'ArrowRight');
    if(Math.abs(error)<.35)await page.keyboard.down('w');else await page.keyboard.up('w');
    await delay(150);
   }
   throw Error('Could not reach ground target: '+JSON.stringify(await state()));
  };
  await page.goto('http://127.0.0.1:8767/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.selecting);
  await click('malta_button');await wait(()=>window.firstSortieState.airfield_selecting);
  await click('depart_button');await wait(()=>window.firstSortieState.truck_count===3);
  const world=(await state()).world_id;
  await page.keyboard.down('Control');await delay(800);await page.keyboard.up('Control');
  check((await state()).aa_shots===0,'Empty AA positions ignore Ctrl in browser');
  await walk((await state()).truck_positions[0],3.3);
  check((await state()).ground_prompt==='E Enter Military Truck','Walking finds nearby truck prompt');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='truck');
  check(!(await state()).on_foot && !(await state()).ground_reticle,'Truck takes exclusive control without gun HUD');
  await page.keyboard.down('w');await wait(()=>window.firstSortieState.truck_speed>1);
  check((await state()).truck_speed>1,'Browser W drives truck');
  await page.keyboard.up('w');
  await page.keyboard.down('Space');await wait(()=>Math.abs(window.firstSortieState.truck_speed)<.1);await page.keyboard.up('Space');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='walking');
  check((await state()).world_id===world,'Truck exit retains running world');
  await walk((await state()).gun_positions[1],5.1);
  check((await state()).ground_prompt==='E Mount AA Gun','Walking reaches visible manual gun');
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='gun');
  check((await state()).aa_mounted===1 && (await state()).ground_reticle && !(await state()).on_foot,'One mounted gun owns reticle and controller');
  await page.keyboard.down('ArrowRight');await page.keyboard.down('Control');await delay(1600);
  await page.keyboard.up('ArrowRight');await page.keyboard.up('Control');
  await wait(()=>window.firstSortieState.aa_shots>0);
  check((await state()).aa_shots>0,'Browser steering and Ctrl fire manual AA');
  await page.screenshot({path:'/tmp/first-sortie-web-checks/manual-aa.png'});
  await page.keyboard.press('e');await wait(()=>window.firstSortieState.ground_mode==='walking');
  const rounds=(await state()).aa_shots;
  await page.keyboard.down('Control');await delay(1000);await page.keyboard.up('Control');
  check((await state()).aa_shots===rounds && (await state()).aa_mounted===0,'Exited gun never restores autonomous fire');
  await page.keyboard.press('r');await page.waitForFunction(previous=>window.firstSortieState.world_id!==previous && window.firstSortieState.ground_mode==='walking',world,{timeout:120000});
  check((await state()).truck_count===3 && (await state()).aa_count===6 && (await state()).aa_healthy && (await state()).aa_shots===0,'Browser retry cleans guns, trucks and controllers');
  check(errors.length===0,'No ANGLE browser runtime errors');
  console.log(`GROUND WEB RESULT: ${checks}/${checks} passed`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
