const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const repo = process.env.VPNROUTER_TEST_REPO || path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(repo, file), 'utf8');
function library(file) {
  const module = {exports: {}};
  new Function('module', read(file).replace(/^\.pragma library\s*/m, ''))(module);
  return module.exports;
}
const I18n = library('lib/I18n.js');
const Model = library('lib/Model.js');
I18n.setCatalogs(JSON.parse(read('locales/en.json')), JSON.parse(read('locales/ru.json')));
const source = read('ui/RoutingSummary.qml');
const root = {service: {appsLoaded: true, effectiveLocale: 'ru', apps: {runningApps: [
  {name: 'chromium', displayName: 'Chromium'}, {name: 'steam', displayName: 'Steam'}
]}}, value: 'split', exclude: false, names: ['chromium'], tr: I18n.t};
const summary = source.match(/function summaryText\(\) \{([\s\S]*?)\n  \}/);
// The old binding is evaluated as a red control from an isolated base snapshot.
const body = summary ? summary[1] : 'return ' + source.match(/text: root.value === "full"[^\n]+/)[0].slice(6);
root.summaryText = new Function('root', 'I18n', 'Model', 'i18nRevision', body).bind(null, root, I18n, Model, 0);
I18n.setLocale('ru');
assert.equal(root.summaryText(), 'Chromium идёт через VPN. Остальные — напрямую.');
for (const locale of ['en', 'ru']) {
  I18n.setLocale(locale);root.service.effectiveLocale = locale;
  const oracle = new Intl.PluralRules(locale);
  for (let n = 0; n <= 10000; n++) assert.equal(I18n.cardinalCategory(n, locale), oracle.select(n), `${locale}: ${n}`);
  for (const n of [null, undefined, NaN, -1, 1.5, '1', Infinity]) assert.equal(I18n.cardinalCategory(n, locale), null);
  for (const exclude of [false, true]) {
    root.exclude = exclude;
    const route = locale === 'ru' ? (exclude ? 'напрямую' : 'через VPN') : (exclude ? 'direct' : 'through VPN');
    const rest = locale === 'ru' ? (exclude ? 'через VPN' : 'напрямую') : (exclude ? 'use VPN' : 'go direct');
    for (const count of [1, 2, 3, 4, 5, 7, 13, 14, 16, 23, 24, 27, 103, 113]) {
      root.names = ['chromium', 'steam', ...Array.from({length: count}, (_, i) => 'CustomCase' + i)].slice(0, count);
      const original = [...root.names];
      const expected = locale === 'ru'
        ? (count === 1 ? `Chromium идёт ${route}` : count === 2 ? `Chromium и Steam идут ${route}` : `Chromium, Steam и ещё ${count - 2} идут ${route}`) + `. Остальные — ${rest}.`
        : (count === 1 ? `Chromium goes ${route}` : count === 2 ? `Chromium and Steam go ${route}` : `Chromium, Steam and ${count - 2} more go ${route}`) + `. Other apps ${rest}.`;
      assert.equal(root.summaryText(), expected);
      assert.deepEqual(root.names, original, 'Display formatting preserves exact routing keys');
    }
    root.names = [];
    assert.equal(root.summaryText(), I18n.t(exclude ? 'home.appsEmptyExclude' : 'home.appsEmpty'));
  }
  root.names = ['UnknownCase'];
  assert(root.summaryText().startsWith('UnknownCase '), 'Unknown names keep original casing');
  root.service.appsLoaded = false;assert.equal(root.summaryText(), I18n.t('home.appsLoading'));
  root.value = 'full';assert.equal(root.summaryText(), I18n.t('home.allTraffic'));
  root.value = 'split';root.service.appsLoaded = true;
}
console.log('PASS: production routing summary, known/unknown names, both modes/locales, 0/1/2/many, CLDR integer counts against ICU');
