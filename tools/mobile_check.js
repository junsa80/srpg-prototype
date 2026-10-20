// Phone-emulation screenshots: node tools/mobile_check.js  (needs build/web served on :18931, puppeteer-core in /workspace/shotrunner)
const puppeteer = require(process.env.PP || '/workspace/shotrunner/node_modules/puppeteer-core'); const fs = require('fs');
const OUT = process.env.OUT || 'build/mobile_check', BASE = process.env.URL || 'http://127.0.0.1:18931/';
const sizes = (process.env.SIZES || '360x640,375x667,390x844,430x932').split(',').map(s => s.split('x').map(Number));
const ALL = { prep: '#nodialog', map: '#nodialog,noprep', forecast: '#ch2,nodialog,noprep,forecast', combat: '#combatfx,nodialog' };
const modes = Object.fromEntries(Object.entries(ALL).filter(([k]) => !process.env.MODES || process.env.MODES.split(',').includes(k)));
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const b = await puppeteer.launch({ headless: 'new', executablePath: '/usr/bin/google-chrome', userDataDir: fs.mkdtempSync('/tmp/pp-'), args: ['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const report = [];
  for (const [w,h] of sizes) for (const sa of ['', 'safearea=47,34']) for (const [m, hash] of Object.entries(modes)) {
    const p = await b.newPage(); const errs = []; p.on('pageerror', e => errs.push(e.message));
    await p.emulate({ viewport: { width: w, height: h, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }, userAgent: 'Mozilla/5.0 (Linux; Android 14) Mobile' });
    await p.goto(BASE + hash + (sa ? ',' + sa : ''));
    if (m === 'combat') { await sleep(2600); await p.touchscreen.tap(w/2, h*0.8); await sleep(2200); } else await sleep(6500);
    const f = `${OUT}/${w}x${h}${sa ? '_notch' : ''}_${m}.png`; await p.screenshot({ path: f });
    report.push(`${f} errs=${errs.length}`); await p.close();
  }
  console.log(report.join('\n')); await b.close();
})();
