// Real release browser UI and existing F3 damage tool. Telemetry is read-only.
const {chromium} = require('playwright');
const {spawn} = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
(async () => {
 const output = '/tmp/survival-web-checks'; fs.mkdirSync(output,{recursive:true});
 const server = spawn('python3',['-m','http.server','8769','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser; let checks=0; const errors=[];
 const check=(value,message)=>{assert.ok(value,message);checks++;console.log('PASS: '+message);};
 try {
  await delay(500);
  browser=await chromium.launch({executablePath:process.env.CHROME_BIN||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:960,height:600}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=async p=>{try{await page.waitForFunction(p,null,{timeout:120000});}catch(e){console.log("FAILED STATE: "+JSON.stringify(await state()));await page.screenshot({path:path.join(output,"failure.png")});throw e;}};
  const click=async id=>{const [x,y]=(await state())[id];await page.mouse.click(x,y);};
  await page.goto('http://127.0.0.1:8769/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.selecting);
  await click('malta_button');
  await wait(()=>window.firstSortieState.airfield_selecting);
  check((await state()).selected_mode==='encounter','Existing Malta encounters remain the default');
  await page.screenshot({path:path.join(output,'departure-chart.png')});
  await click('mode_picker');
  await wait(()=>window.firstSortieState.mode_popup);
  if((await state()).mode_focus!==1) await page.keyboard.press('ArrowUp');
  await wait(()=>window.firstSortieState.mode_focus===1);
  await page.keyboard.press('Enter');
  await page.screenshot({path:path.join(output,'mode-dropdown.png')});
  await wait(()=>window.firstSortieState.selected_mode==='survival');
  check((await state()).airfield_selecting,'Survival can be selected without leaving departure chart');
  await page.screenshot({path:path.join(output,'survival-selection.png')});
  await click('depart_button');
  await wait(()=>window.firstSortieState.on_foot && window.firstSortieState.enemy_count===1);
  check((await state()).encounter.mode==='survival' && (await state()).encounter.stage===1,'Survival departure starts exactly stage one');
  await page.keyboard.press('e');
  await wait(()=>!window.firstSortieState.on_foot);
  const original=(await state());
  await page.keyboard.press('h');
  await wait(()=>window.firstSortieState.hp===90);
  await page.keyboard.press('F3');
  await wait(()=>window.firstSortieState.debug_visible);
  await click('debug_target_picker');
  await wait(()=>window.firstSortieState.debug_target_popup);
  if((await state()).debug_target_focus!==1) await page.keyboard.press('ArrowUp');
  await wait(()=>window.firstSortieState.debug_target_focus===1);
  await page.keyboard.press('Enter');
  // Kill using the existing visible component damage button, never JS mutation.
  for(let hit=0;hit<10;hit++){
   const hp=(await state()).enemy_hp;
   await click('debug_damage_button');
   await page.waitForFunction(previous=>window.firstSortieState.enemy_hp<previous,hp,{timeout:120000});
  }
  await wait(()=>window.firstSortieState.encounter.awaiting);
  check((await state()).enemy_count===0 && (await state()).encounter.stage===1,'Actual damage destruction removes active enemy and awaits confirmation');
  await page.keyboard.press('F3');
  await wait(()=>!window.firstSortieState.debug_visible);
  await page.screenshot({path:path.join(output,'stage-cleared.png')});
  await delay(600);
  check((await state()).enemy_count===0,'Stage does not auto-spawn during live browser frames');
  await click('confirm_button');
  await wait(()=>window.firstSortieState.encounter.stage===2 && window.firstSortieState.enemy_count===2);
  check((await state()).world_id===original.world_id && (await state()).hp===90 && !(await state()).engine_running && !(await state()).paused,'Mouse confirmation preserves world, player health, engine and live controls');
  await page.keyboard.press('c');
  await delay(600);
  check((await state()).encounter.stage===2 && (await state()).enemy_count===2,'C cannot duplicate an active stage');
  await page.screenshot({path:path.join(output,'stage-two.png')});
  await page.keyboard.press('i');
  await wait(()=>window.firstSortieState.engine_running);
  await page.keyboard.down('w');await page.keyboard.down('f');
  await wait(()=>window.firstSortieState.throttle>0.1 && window.firstSortieState.shots>8);
  await page.keyboard.up('w');await page.keyboard.up('f');
  check((await state()).shots>8,'Player engine, throttle and guns still respond after stage transition');
  for(let hit=0;hit<9;hit++){
   const hp=(await state()).hp;
   await page.keyboard.press('h');
   await page.waitForFunction(previous=>window.firstSortieState.hp<previous,hp,{timeout:120000});
  }
  await wait(()=>window.firstSortieState.destroyed && window.firstSortieState.encounter.ended);
  await page.keyboard.press('c');await delay(500);
  check((await state()).encounter.stage===2 && !(await state()).encounter.awaiting,'Player destruction ends the run and disables stage confirmation');
  check(errors.length===0,'Release browser has no JavaScript or Godot runtime errors');
  fs.writeFileSync(path.join(output,'results.json'),JSON.stringify({checks,errors,state:await state()},null,2));
  console.log(`SURVIVAL WEB RESULT: ${checks}/${checks} passed`);
 } finally {if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
