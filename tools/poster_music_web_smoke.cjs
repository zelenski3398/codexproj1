// Production-export poster lifecycle with real pointer inputs; no state writes.
const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const server=spawn('python3',['-m','http.server','8798','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/web')],{stdio:'ignore'});
 let browser,count=0;const errors=[];
 const check=(ok,label)=>{assert.ok(ok,label);count++;console.log('PASS:',label);};
 try{
  await sleep(500);
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const page=await browser.newPage({viewport:{width:1000,height:700}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  page.on('response',r=>{if(r.status()>=400)errors.push(r.status()+' '+r.url());});
  const state=()=>page.evaluate(()=>window.firstSortieState);
  const wait=(f,arg=null)=>page.waitForFunction(f,arg,{timeout:240000});
  await page.goto('http://127.0.0.1:8798/index.html?smoke=1');
  await wait(()=>window.firstSortieState?.startup_intro?.phase===1);
  check((await state()).startup_intro.music_asset.endsWith('wings_over_malta_cinematic_march.ogg'),'Poster preloads the supplied cinematic march');
  await page.mouse.click(10,10); // Unlock browser audio, without pressing Play.
  await wait(()=>window.firstSortieState.startup_intro.music_playing);
  check((await state()).startup_intro.phase===1,'Background gesture enables audio without leaving the poster');
  const initialMusic=(await state()).startup_intro.music_position;
  let previous=(await state()).startup_intro.video_position,wrapped=false,maximum=previous;
  let previousMusic=initialMusic,musicAdvance=0;
  const limit=Date.now()+90000;
  let progress=Date.now();
  while(Date.now()<limit){
   await sleep(220);
   const s=(await state()).startup_intro;
   maximum=Math.max(maximum,s.video_position);
   const audioDelta=s.music_position-previousMusic;
   musicAdvance+=audioDelta < -1 ? audioDelta+48 : Math.max(0,audioDelta);
   previousMusic=s.music_position;
   if(Date.now()-progress>10000){console.log("POSTER PROGRESS",JSON.stringify(s));progress=Date.now();}
   if(s.video_position<previous-1){wrapped=true;break;}
   previous=s.video_position;
  }
  const after=await state();
  console.log("POSTER LOOP OBSERVATION",JSON.stringify({wrapped,maximum,musicAdvance,after:after.startup_intro}));
  check(wrapped&&maximum>8&&after.startup_intro.video_restarts===0,'Ten-second animation wraps without manual stop/restart');
  check(after.startup_intro.music_playing&&after.startup_intro.music_starts===1&&musicAdvance>3,'March advances independently across the video loop without restarting');
  check(!after.audio.menu_active&&!after.audio.music_playing,'Old main-menu music does not overlap the poster march');
  await page.mouse.click(10,10);await sleep(300);
  check((await state()).startup_intro.music_starts===1,'Repeated background gestures do not restart the march');
  await page.screenshot({path:'/tmp/poster-march-browser.png'});
  const [x,y]=(await state()).startup_intro.play_button;await page.mouse.click(x,y);
  await wait(()=>!window.firstSortieState.startup_intro.active&&window.firstSortieState.selecting&&window.firstSortieState.audio.menu_active);
  check((await state()).audio.music_playing,'Integrated Play fades into the original menu and its music');
  check(errors.length===0,'No browser script, media-resource or JavaScript errors');
  console.log(`POSTER MUSIC WEB RESULT: ${count}/${count} passed`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
