const {chromium}=require('playwright');
const {spawn}=require('node:child_process');
const path=require('node:path');
const assert=require('node:assert/strict');
(async()=>{
 const server=spawn('python3',['-m','http.server','8789','--bind','127.0.0.1','--directory',path.resolve(__dirname,'../builds/universal-damage-test')],{stdio:'ignore'});
 let browser;const errors=[];
 try{
  await new Promise(r=>setTimeout(r,500));
  browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:800}});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.goto('http://127.0.0.1:8789/index.html');
  await page.waitForFunction(()=>window.universalDamageFixture?.done,null,{timeout:180000});
  const result=await page.evaluate(()=>window.universalDamageFixture);
  for(const message of result.messages)console.log(message);
  assert.equal(result.failed,0,JSON.stringify(result));
  assert.equal(errors.length,0,JSON.stringify(errors));
  console.log(`UNIVERSAL DAMAGE WEB RESULT: ${result.checks}/${result.checks} passed; no browser errors`);
 }finally{if(browser)await browser.close();server.kill();}
})().catch(e=>{console.error(e);process.exitCode=1;});
