// Actual browser input and WebGL runtime; telemetry is read-only and opt-in.
const {chromium} = require('playwright');
const {spawn} = require('node:child_process');
const {setTimeout: delay} = require('node:timers/promises');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const project = path.resolve(__dirname, '..');
const port = Number(process.env.WEB_TEST_PORT || 8765);
const output = process.env.WEB_TEST_OUTPUT || '/tmp/first-sortie-web-checks';
let checks = 0;
function check(condition, message) {
  assert.ok(condition, message);
  checks++;
  console.log('PASS: ' + message);
}
(async () => {
  fs.mkdirSync(output, {recursive: true});
  const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1', '--directory', path.join(project, 'builds/web')], {stdio: 'ignore'});
  let browser;
  const errors = [];
  const badResponses = [];
  try {
    await delay(500);
    browser = await chromium.launch({
      executablePath: process.env.CHROME_BIN || '/usr/bin/chromium',
      headless: true,
      args: ['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']
    });
    const page = await browser.newPage({viewport:{width:1280,height:800}});
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', msg => {
      if (msg.type() === 'error') errors.push(msg.text());
      if (msg.type() === 'error' || msg.text().includes('Godot Engine')) console.log('BROWSER: ' + msg.text());
    });
    page.on('response', response => {if(response.status() >= 400)badResponses.push(response.url() + ': ' + response.status());});
    const state = () => page.evaluate(() => window.firstSortieState);
    const wait = async predicate => {
      await page.waitForFunction(predicate, null, {timeout: 120000});
      return state();
    };
    const clickControl = async name => {
      const point = (await state())[name];
      await page.mouse.click(point[0], point[1]);
    };
    await page.goto('http://127.0.0.1:' + port + '/index.html?smoke=1');
    check(await page.getByRole('button', {name:'PLAY IN BROWSER'}).isVisible(), 'Branded start page and Play button');
    check(await page.evaluate(() => Engine.getMissingFeatures({threads:false}).length === 0 && !crossOriginIsolated), 'Runs without cross-origin isolation / special server headers');
    await page.screenshot({path:path.join(output,'landing.png')});
    await page.getByRole('button', {name:'PLAY IN BROWSER'}).click();
    await wait(() => window.firstSortieState && window.firstSortieState.selecting);
    check(await page.evaluate(() => window.firstSortieReady), 'Actual WebAssembly/WebGL game initializes');
    await page.screenshot({path:path.join(output,'selection.png')});
    await page.keyboard.press('2');
    await wait(() => window.firstSortieState.selected === 'sea_gladiator');
    check((await state()).selecting, 'Keyboard selects Sea Gladiator before simulation');
    await clickControl('fly_button');
    await wait(() => !window.firstSortieState.selecting);
    check((await state()).selected === 'sea_gladiator' && (await state()).fixed_gear, 'Mouse Fly starts the correct biplane with fixed gear');
    check((await state()).hp === 100 && (await state()).enemy_count === 1 && (await state()).fire_guide === 'F', 'Health, one enemy and browser firing guide');
    await page.keyboard.down('w'); await page.keyboard.down('f');
    await wait(() => window.firstSortieState.throttle > 0.2 && window.firstSortieState.shots > 10);
    await page.keyboard.up('w'); await page.keyboard.up('f'); await delay(600);
    const throttle = (await state()).throttle;
    const shots = (await state()).shots;
    await delay(600);
    check(Math.abs((await state()).throttle - throttle) < 0.015, 'Throttle holds after W release');
    check((await state()).shots === shots, 'F fires while W is held and stops after release');
    await page.keyboard.press('g'); await delay(500);
    check((await state()).gear && (await state()).fixed_gear, 'G preserves Gladiator fixed landing gear');
    await page.keyboard.down('w');
    await wait(() => window.firstSortieState.throttle > 0.8 && window.firstSortieState.speed > 5);
    await page.keyboard.up('w');
    check((await state()).speed > 5, 'Shared flight physics accelerates the aircraft along the runway');
    await page.screenshot({path:path.join(output,'gladiator-runway.png')});
    for (let i=0;i<5;i++){await page.keyboard.press('h');await delay(80);}
    await wait(() => window.firstSortieState.hp === 50);
    check(!(await state()).smoke, 'Exactly 50 HP leaves engine damage effects off');
    await page.keyboard.press('h');
    await wait(() => window.firstSortieState.hp === 40 && window.firstSortieState.smoke);
    check((await state()).smoke, 'Smoke/fire activates below 50 HP in the browser');
    await page.screenshot({path:path.join(output,'damage.png')});
    for (let i=0;i<4;i++){await page.keyboard.press('h');await delay(80);}
    await wait(() => window.firstSortieState.destroyed && window.firstSortieState.hp === 0);
    check((await state()).destroyed, 'Zero HP enters destroyed state');
    const destroyedShots = (await state()).shots;
    await page.keyboard.down('f');await delay(700);await page.keyboard.up('f');
    check((await state()).shots === destroyedShots, 'Destroyed aircraft cannot fire');
    await page.keyboard.press('r');
    await wait(() => window.firstSortieState.hp === 100 && !window.firstSortieState.destroyed && window.firstSortieState.shots === 0);
    check((await state()).enemy_count === 1 && !(await state()).smoke && (await state()).selected === 'sea_gladiator', 'R clears rounds/effects and restores exactly one fresh enemy');
    await page.keyboard.press('Escape');
    await wait(() => window.firstSortieState.paused);
    check((await state()).paused, 'Escape pauses the browser game');
    await page.keyboard.press('F3');
    await wait(() => window.firstSortieState.debug_visible);
    check((await state()).paused, 'F3 component/gunnery inspector works while paused');
    await page.screenshot({path:path.join(output,'debug.png')});
    await page.keyboard.press('F3');
    await wait(() => !window.firstSortieState.debug_visible && window.firstSortieState.change_visible);
    await clickControl('change_button');
    await wait(() => window.firstSortieState.selecting);
    check(!(await state()).paused, 'Mouse change-aircraft returns to startup selection');
    await clickControl('spitfire_button');
    await wait(() => window.firstSortieState.selected === 'spitfire');
    await page.keyboard.press('Enter');
    await wait(() => !window.firstSortieState.selecting);
    check((await state()).selected === 'spitfire' && !(await state()).fixed_gear && (await state()).hp === 100, 'Mouse selects Spitfire and Enter starts a clean session');
    await page.keyboard.down('f');
    await wait(() => window.firstSortieState.shots >= 16);
    await page.keyboard.up('f');
    check((await state()).shots >= 16, 'Spitfire wing guns fire with browser F');
    await page.screenshot({path:path.join(output,'spitfire.png')});
    const licenseStatuses = [];
    for (const filename of ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt','DejaVu-LICENSE.txt']) {
      licenseStatuses.push((await page.request.get('http://127.0.0.1:' + port + '/' + filename)).status());
    }
    check(badResponses.length === 0 && licenseStatuses.every(status => status === 200), 'All exported assets and licenses load successfully');
    check(errors.length === 0, 'No JavaScript or Godot runtime errors');
    fs.writeFileSync(path.join(output, 'results.json'), JSON.stringify({checks, errors, badResponses, final_state:await state()},null,2));
    console.log('WEB RESULT: ' + checks + '/' + checks + ' passed');
  } finally {
    if(browser)await browser.close();
    server.kill();
  }
})().catch(error => {console.error(error);console.log('WEB RESULT: failed after ' + checks + ' passes');process.exitCode=1;});
