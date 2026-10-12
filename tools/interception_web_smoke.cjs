// Real exported game, normal menu/keyboard controls, read-only telemetry.
const {chromium} = require('playwright');
const {spawn} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
 const output='/tmp/interception-web-checks'; fs.mkdirSync(output,{recursive:true});
 const server=spawn('python3',['-m','http.server','8771','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser; let checks=0; const errors=[];
 const check=(v,msg)=>{assert.ok(v,msg);checks++;console.log('PASS: '+msg);};
 try {
  await delay(500);
  browser=await chromium.launch({executablePath:process.env.CHROME_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=async p=>{try{await page.waitForFunction(p,null,{timeout:120000});}catch(e){console.log('FAILED STATE: '+JSON.stringify(await state()));await page.screenshot({path:path.join(output,'failure.png')});throw e;}};
  const click=async key=>{const [x,y]=(await state())[key];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8771/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.selecting);
  check((await state()).missions_button?.length===2,'First screen is the game menu with Missions entry');
  await click('missions_button');
  await wait(()=>window.firstSortieState.missions_selecting);
  check(!(await state()).selecting,'Missions entry opens its briefing');
  await page.screenshot({path:path.join(output,'briefing.png')});
  await click('mission_depart_button');
  await wait(()=>window.firstSortieState.on_foot && window.firstSortieState.interception?.phase==='CHECKPOINT');
  const original=await state();
  check(original.home_airfield==='ta_qali' && original.environment==='malta','Mission starts in continuous Malta at Ta’ Qali');
  check(original.enemy_count===0 && original.interception.elapsed===0 && !original.interception.activated,'No enemy/timer before checkpoint');
  check(!original.engine_running && original.hp===100,'Ground start preserves manual engine and healthy Spitfire');
  check(original.interception.marker && original.interception.checkpoint_index===0 && original.interception.checkpoint_count===5,'Only numbered checkpoint 1/5 is active at mission start');
  await page.keyboard.press('m');
  await wait(()=>window.firstSortieState.map_open);
  check((await state()).interception.nav_checkpoint,'Navigation map contains checkpoint');
  await page.screenshot({path:path.join(output,'checkpoint-map.png')});
  await page.keyboard.press('m');
  await wait(()=>!window.firstSortieState.map_open);
  await page.keyboard.press('e');
  await wait(()=>!window.firstSortieState.on_foot);
  check((await state()).world_id===original.world_id,'Boarding retains the existing world');
  await page.keyboard.down('Space');
  await page.keyboard.press('i');
  await wait(()=>window.firstSortieState.engine_running);
  check((await state()).engine_running,'Manual I key starts engine in browser');
  await page.keyboard.down('w');
  await wait(()=>window.firstSortieState.throttle>0.1);
  await page.keyboard.up('w');
  check((await state()).interception.elapsed===0 && (await state()).enemy_count===0,'Power changes do not bypass checkpoint gating');
  await page.screenshot({path:path.join(output,'ground-start.png')});
  for(let hit=0;hit<10;hit++){
   const hp=(await state()).hp;
   await page.keyboard.press('h');
   await page.waitForFunction(before=>window.firstSortieState.hp<before,hp,{timeout:120000});
  }
  await wait(()=>window.firstSortieState.interception.phase==='FAILED');
  check((await state()).interception.result.includes('Player aircraft destroyed'),'Actual debug health destruction displays mission failure');
  await page.keyboard.up('Space');
  await page.screenshot({path:path.join(output,'failure-result.png')});
  const clickResult=async key=>{const [x,y]=(await state()).interception[key];await page.mouse.click(x,y);};
  await clickResult('retry');
  await wait(()=>window.firstSortieState.on_foot && window.firstSortieState.hp===100 && window.firstSortieState.interception.phase==='CHECKPOINT');
  check((await state()).world_id!==original.world_id && (await state()).enemy_count===0 && (await state()).interception.elapsed===0 && (await state()).interception.checkpoint_index===0,'Retry creates a clean new mission with no old enemies/timer');
  await page.keyboard.press('e');
  await wait(()=>!window.firstSortieState.on_foot);
  for(let hit=0;hit<10;hit++){
   const hp=(await state()).hp;
   await page.keyboard.press('h');
   await page.waitForFunction(before=>window.firstSortieState.hp<before,hp,{timeout:120000});
  }
  await wait(()=>window.firstSortieState.interception.phase==='FAILED');
  await clickResult('return');
  await wait(()=>window.firstSortieState.missions_selecting && !window.firstSortieState.interception);
  check((await state()).enemy_count===undefined && (await state()).encounter.remaining===0,'Return to Missions removes old aircraft and mission references');
  await click('mission_back_button');
  await wait(()=>window.firstSortieState.selecting);
  check((await state()).malta_button && (await state()).fly_button,'Return to main menu preserves original modes');
  check(errors.length===0,'Browser export has no runtime/script/resource errors');
  console.log(`INTERCEPTION WEB RESULT: ${checks}/${checks} passed`);
 } finally {if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
