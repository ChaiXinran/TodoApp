import {createRequire} from 'node:module';
import fs from 'node:fs';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const browser=await chromium.launch({executablePath:process.env.CHROME_PATH,headless:true});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,timezoneId:'Asia/Shanghai'});
const page=await context.newPage();const errors=[];const failed=[];
page.on('pageerror',e=>errors.push(String(e)));
page.on('requestfailed',r=>failed.push({url:r.url(),failure:r.failure()?.errorText}));
fs.mkdirSync('.verification',{recursive:true});fs.mkdirSync('screenshots',{recursive:true});
async function semantics(){const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(n=>n.click());}
try{
  const response=await page.goto('https://todo.ranyechai.site/',{waitUntil:'domcontentloaded',timeout:60000});
  if(response.status()!==200)throw Error('HTTPS page status '+response.status());
  await page.waitForFunction(()=>!document.getElementById('loading'),{},{timeout:120000});
  await semantics();
  await page.getByRole('tab',{name:'首页',exact:true}).waitFor({timeout:120000});
  await page.screenshot({path:'screenshots/live-home.png'});
  const manifest=await page.evaluate(async()=>await (await fetch('manifest.json')).json());
  if(manifest.display!=='standalone'||manifest.name!=='日常')throw Error('PWA manifest');
  for(const [name,file]of [['日历','calendar'],['事务','affairs'],['记录','records'],['档案','archive']]){
    await page.getByRole('tab',{name,exact:true}).click();
    await page.waitForTimeout(300);
    await page.screenshot({path:`screenshots/live-${file}.png`});
    if(name==='事务'&&!(await page.locator('body').innerText()).includes('11 门课程'))throw Error('Screenshot timetable did not initialize');
  }
  await page.evaluate(async()=>{await navigator.serviceWorker.ready;});
  await page.waitForFunction(()=>navigator.serviceWorker.controller!==null,{},{timeout:120000});
  const cache=await page.evaluate(async()=>({keys:await caches.keys(),index:!!(await caches.match(new URL('index.html',location.href).href)),controller:navigator.serviceWorker.controller.scriptURL}));
  await context.setOffline(true);
  await page.reload({waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForFunction(()=>!document.getElementById('loading'),{},{timeout:90000});
  await semantics();await page.getByRole('tab',{name:'记录',exact:true}).click();
  await page.screenshot({path:'screenshots/live-offline.png'});
  if(errors.length)throw Error(errors.join(';'));
  const report={url:page.url(),https:true,five_pages:true,screenshot_courses:11,manifest:true,offline_reload:true,cache,errors,failed};
  fs.writeFileSync('.verification/live-site-result.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}catch(e){
  console.log('FAIL',String(e));console.log('NETWORK',JSON.stringify(failed));
  await page.screenshot({path:'screenshots/live-failure.png'});throw e;
}finally{await browser.close();}
