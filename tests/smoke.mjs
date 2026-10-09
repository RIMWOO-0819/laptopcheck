// Smoke test in a real headless Chromium: boots LaptopCheck.html from file://
// (exactly how users open it) and checks rendering, judging rules and interactions.
// Usage:  npm test                         (sample data)
//         node tests/smoke.mjs out/data.js (also boots with real data from check.ps1)
import { readFileSync, mkdtempSync, copyFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { chromium } from 'playwright';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = p => readFileSync(p, 'utf8').replace(/^﻿/, '');
const sampleJs = read(join(root, 'samples/data.sample.js'));
const customJs = process.argv[2] ? read(process.argv[2]) : null;

let failures = 0;
const check = (cond, msg) => { if (cond) console.log('  ok   ' + msg); else { failures++; console.error('  FAIL ' + msg); } };

const browser = await chromium.launch();
const dirs = [];

async function boot({ data, locale = 'en-US', storage = {} }) {
  const dir = mkdtempSync(join(tmpdir(), 'lc-'));
  dirs.push(dir);
  copyFileSync(join(root, 'src/LaptopCheck.html'), join(dir, 'LaptopCheck.html'));
  if (data) writeFileSync(join(dir, 'data.js'), data);
  const context = await browser.newContext({ locale });
  await context.addInitScript(s => {
    if (!sessionStorage.getItem('lc_seeded')) {
      for (const [k, v] of Object.entries(s)) localStorage.setItem('lc_' + k, JSON.stringify(v));
      sessionStorage.setItem('lc_seeded', '1');
    }
  }, storage);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.goto(pathToFileURL(join(dir, 'LaptopCheck.html')).href);
  return { page, errors, context };
}
const statusOf = (page, name) => page.evaluate(n => {
  const row = [...document.querySelectorAll('#autoBox tr')].find(r => r.querySelector('td.n')?.textContent === n);
  return row ? row.querySelector('.st').className.replace('st ', '') : null;
}, name);
const count = (page, sel) => page.locator(sel).count();

try {
  if (customJs) {
    console.log('0) boots with the given data file');
    const { page, errors, context } = await boot({ data: customJs });
    check(errors.length === 0, 'no script errors ' + errors.join(' | '));
    check(await page.evaluate(() => !!window.AUTO && window.AUTO.tool === 'LaptopCheck'), 'data.js defines window.AUTO');
    check(await count(page, '#autoBox .card') >= 5, 'auto check renders category cards');
    check(await count(page, '#autoBox .st') >= 15, 'auto check produced judged rows');
    await context.close();
  }

  console.log('1) boots with sample data (en)');
  {
    const { page, errors, context } = await boot({ data: sampleJs });
    check(errors.length === 0, 'no script errors ' + errors.join(' | '));
    check(await count(page, '#autoBox .card') >= 8, 'auto check renders category cards');
    check(await statusOf(page, 'Battery health') === 'ok', 'battery 88.4% → OK');
    check(await statusOf(page, 'SSD wear') === 'ok', 'SSD wear 2% → OK');
    check(await statusOf(page, 'Webcam') === 'ok', 'single camera string is handled');
    check(await count(page, '#nav button') === 10, 'navigation has 10 sections');
    check(await count(page, '#kb .k') > 60, 'keyboard renders');
    check(await count(page, '#grid .cell') === 84, 'touch grid renders');
    await context.close();
  }

  console.log('2) listing specs are compared');
  {
    const { page, context } = await boot({ data: sampleJs, storage: { spec: { model: 'UX3405', cpu: '225H', ram: 16, storage: 512, batt: 95 } } });
    check(await statusOf(page, 'Model') === 'ok', 'model matches listing');
    check(await statusOf(page, 'CPU') === 'ok', 'CPU matches listing');
    check(await statusOf(page, 'RAM') === 'ok', 'RAM matches listing');
    check(await statusOf(page, 'Battery health') === 'warn', 'battery 88% vs claimed 95% → Check');
    await context.close();
  }
  {
    const { page, context } = await boot({ data: sampleJs, storage: { spec: { cpu: 'i7-1360P', ram: 32, touch: true } } });
    check(await statusOf(page, 'CPU') === 'warn', 'wrong CPU → Check');
    check(await statusOf(page, 'RAM') === 'fail', 'less RAM than listed → Problem');
    await page.fill('[data-spec="cpu"]', '225H');
    check(await statusOf(page, 'CPU') === 'ok', 'editing the spec field re-judges live');
    await context.close();
  }

  console.log('3) bad hardware is flagged');
  {
    const bad = sampleJs
      .replace('"health": 88.4', '"health": 61.2')
      .replace('"wear": 2', '"wear": 41')
      .replace('"kernelPower": 1', '"kernelPower": 14')
      .replace('"errors": []', '"errors": [{"name": "Unknown device", "code": 28}]')
      .replace('"touchscreen": true', '"touchscreen": false');
    const { page, errors, context } = await boot({ data: bad, storage: { spec: { touch: true } } });
    check(errors.length === 0, 'no script errors');
    check(await statusOf(page, 'Battery health') === 'fail', 'battery 61% → Problem');
    check(await statusOf(page, 'SSD wear') === 'fail', 'wear 41% → Problem');
    check(await statusOf(page, 'Unexpected shutdowns') === 'fail', '14 shutdowns → Problem');
    check(await statusOf(page, 'Device errors') === 'fail', 'device error code 28 → Problem');
    check(await statusOf(page, 'Touchscreen') === 'fail', 'listing says touch but none found → Problem');
    await context.close();
  }

  console.log('4) desktop / no data / Korean');
  {
    const desktop = sampleJs.replace(/"battery": \{[^}]*\}/, '"battery": null').replace('"isLaptop": true', '"isLaptop": false');
    const { page, errors, context } = await boot({ data: desktop });
    check(errors.length === 0, 'desktop data boots');
    check(await statusOf(page, 'Battery') === 'info', 'desktop without battery → Info');
    await context.close();
  }
  {
    const { page, errors, context } = await boot({ data: null });
    check(errors.length === 0, 'boots without data.js ' + errors.join(' | '));
    check(await count(page, '#autoBox .notice') === 1, 'shows the "run START.bat" notice');
    await context.close();
  }
  {
    const { page, errors, context } = await boot({ data: sampleJs, locale: 'ko-KR' });
    check(errors.length === 0, 'Korean UI boots');
    check(await page.textContent('h1 span') === '중고 노트북 점검', 'Korean title from browser language');
    check(await statusOf(page, '배터리 건강도') === 'ok', 'Korean labels in table');
    await context.close();
  }

  console.log('5) interactions');
  {
    const { page, errors, context } = await boot({ data: sampleJs });
    await page.click('#langSeg button[data-lang="ko"]');
    check(await page.textContent('h1 span') === '중고 노트북 점검', 'language switch works');
    await page.click('#modeSeg button[data-mode="full"]');
    const full = await count(page, '.pf');
    await page.click('#modeSeg button[data-mode="quick"]');
    const quick = await count(page, '.pf');
    check(quick < full, `quick mode shows fewer items (${quick} < ${full})`);
    await page.click('#nav button[data-sec="keyboard"]');
    await page.keyboard.press('a');
    await page.keyboard.press('F5');
    check(await count(page, '#kb .k.hit') === 2, 'key presses light up keys (F5 does not reload)');
    await page.click('#nav button[data-sec="screen"]');
    await page.click('.pf[data-id="scr_dead"] button[data-v="fail"]');
    await page.click('#nav button[data-sec="summary"]');
    check(await count(page, '#verdict .verdict.fail') === 1, 'a failed manual item → Problem verdict');
    await page.click('#nav button[data-sec="cpu"]');
    check((await page.textContent('#cpuBtn')).includes('30'), 'quick mode uses a 30 s load test');
    check(errors.length === 0, 'no script errors during interaction ' + errors.join(' | '));
    await context.close();
  }
} finally {
  await browser.close();
  dirs.forEach(d => rmSync(d, { recursive: true, force: true }));
}

console.log(failures ? `\n${failures} check(s) failed` : '\nall checks passed');
process.exit(failures ? 1 : 0);
