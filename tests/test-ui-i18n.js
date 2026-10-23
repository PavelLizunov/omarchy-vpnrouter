const assert = require("assert");
const fs = require("fs");
const path = require("path");

// Load I18n.js with .pragma library stripped
const i18nPath = path.join(__dirname, "../lib/I18n.js");
const i18nSrc = fs.readFileSync(i18nPath, "utf8").replace(/^\.pragma library\s*/m, "");

const context = { module: { exports: {} } };
const fn = new Function("module", "exports", i18nSrc);
fn(context.module, context.module.exports);
const I18n = context.module.exports;

console.log("=== Testing I18n and Locale Files ===");

const enPath = path.join(__dirname, "../locales/en.json");
const ruPath = path.join(__dirname, "../locales/ru.json");

const enJson = JSON.parse(fs.readFileSync(enPath, "utf8"));
const ruJson = JSON.parse(fs.readFileSync(ruPath, "utf8"));

// 1. Locale Key Parity
{
  const enKeys = Object.keys(enJson).sort();
  const ruKeys = Object.keys(ruJson).sort();

  const missingInRu = enKeys.filter(k => !ruJson.hasOwnProperty(k));
  const missingInEn = ruKeys.filter(k => !enJson.hasOwnProperty(k));

  assert.deepStrictEqual(missingInRu, [], "Keys missing in ru.json: " + missingInRu.join(", "));
  assert.deepStrictEqual(missingInEn, [], "Keys missing in en.json: " + missingInEn.join(", "));
  assert.strictEqual(enKeys.length, ruKeys.length, "Key count must match");
  assert(enKeys.length >= 60, "Expected at least 60 localized keys, got " + enKeys.length);

  // Check no empty values
  for (const k of enKeys) {
    assert(enJson[k].trim().length > 0, `en.json key ${k} must not be empty`);
    assert(ruJson[k].trim().length > 0, `ru.json key ${k} must not be empty`);
  }

  console.log(`✓ 100% key parity across ${enKeys.length} keys in en.json and ru.json`);
}

// 2. I18n Engine Formatting & Fallback
{
  I18n.setCatalogs(enJson, ruJson);
  I18n.setLocale("en");

  assert.strictEqual(I18n.t("app.name"), "VPNRouter");
  assert.strictEqual(I18n.t("state.connected"), "Connected");
  assert.strictEqual(I18n.t("subscriptions.serversCount", [5]), "Servers: 5");
  assert.strictEqual(I18n.t("diagnostics.exportedPath", ["/tmp/diag.tar.gz"]), "Bundle exported to: /tmp/diag.tar.gz");

  // Switch to Russian
  I18n.setLocale("ru");
  assert.strictEqual(I18n.t("app.name"), "VPNRouter");
  assert.strictEqual(I18n.t("state.connected"), "Подключено");
  assert.strictEqual(I18n.t("subscriptions.serversCount", [5]), "Серверы: 5");
  assert.strictEqual(I18n.t("diagnostics.exportedPath", ["/tmp/diag.tar.gz"]), "Отчёт сохранён в: /tmp/diag.tar.gz");

  // Fallback to English if key missing in Russian
  const mockEn = { onlyInEn: "Hello" };
  const mockRu = {};
  I18n.setCatalogs(mockEn, mockRu);
  assert.strictEqual(I18n.t("onlyInEn", null, "ru"), "Hello");

  // Fallback to raw key if missing completely
  assert.strictEqual(I18n.t("non.existent.key"), "non.existent.key");

  console.log("✓ I18n interpolation and fallback passed");
}

// 3. System Locale Detection
{
  assert.strictEqual(I18n.detectSystemLocale("ru_RU.UTF-8"), "ru");
  assert.strictEqual(I18n.detectSystemLocale("ru_UA.UTF-8"), "ru");
  assert.strictEqual(I18n.detectSystemLocale("be_BY.UTF-8"), "ru");
  assert.strictEqual(I18n.detectSystemLocale("en_US.UTF-8"), "en");
  assert.strictEqual(I18n.detectSystemLocale("de_DE.UTF-8"), "en");
  console.log("✓ System locale detection passed");
}

// 4. I18n Reactivity, Revision Tracking, and Subscriptions
{
  const startRev = I18n.getRevision();
  let callCount = 0;
  let lastRev = -1;

  const cb = (rev) => {
    callCount++;
    lastRev = rev;
  };

  I18n.addListener(cb);

  I18n.setLocale("ru");
  assert.strictEqual(callCount, 1, "Listener must fire on setLocale");
  assert.strictEqual(lastRev, startRev + 1, "Revision must increment on setLocale");
  assert.strictEqual(I18n.getEffectiveLocale(), "ru", "Effective locale must be ru");

  I18n.setCatalogs({ "test.key": "Value" }, null);
  assert.strictEqual(callCount, 2, "Listener must fire on setCatalogs");
  assert.strictEqual(lastRev, startRev + 2, "Revision must increment on setCatalogs");

  I18n.removeListener(cb);
  I18n.setLocale("en");
  assert.strictEqual(callCount, 2, "Listener must not fire after removeListener");
  assert.strictEqual(I18n.getRevision(), startRev + 3, "Revision must still increment");
  assert.strictEqual(I18n.getEffectiveLocale(), "en", "Effective locale must be en");

  console.log("✓ I18n reactivity, revision tracking, and listener subscriptions passed");
}

console.log("ALL I18N TESTS PASSED!\n");

// Every literal UI lookup must resolve, including the formerly hardcoded labels.
{
  I18n.setCatalogs(enJson, ruJson);
  const qmlFiles = ['BarWidget.qml', 'Panel.qml', 'Service.qml',
    ...fs.readdirSync(path.join(__dirname, '../ui')).filter(f => f.endsWith('.qml')).map(f => 'ui/' + f)];
  for (const file of qmlFiles) {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    for (const match of source.matchAll(/(?:\btr|I18n\.t)\("([^"]+)"/g)) {
      if (match[1].endsWith('.')) continue; // dynamic state prefix
      assert(enJson[match[1]], `${file}: missing en key ${match[1]}`);
      assert(ruJson[match[1]], `${file}: missing ru key ${match[1]}`);
    }
    assert(!/\|\| "(?:Server|Unnamed Server|Subscription|Free Server|Check)"/.test(source), file);
    assert(!/"Rules exported \("|\? "FULL VPN" : "SPLIT"/.test(source), file);
  }
  for (const key of Object.keys(enJson)) {
    const placeholders = text => (text.match(/\{[^}]+\}/g) || []).sort();
    assert.deepStrictEqual(placeholders(enJson[key]), placeholders(ruJson[key]), key);
  }
  for (const locale of ['en', 'ru']) {
    I18n.setLocale(locale);
    for (const key of ['servers.fallbackName', 'servers.unnamed', 'subscriptions.fallbackName',
      'free.fallbackName', 'diagnostics.fallbackName', 'rules.exported', 'routing.fullBadge',
      'routing.splitBadge', 'backend.notInstalled', 'backend.installHint']) {
      assert.notStrictEqual(I18n.t(key), key);
    }
  }
  assert.strictEqual(I18n.t('rules.exported', ['JSON']), 'Правила экспортированы (JSON)');
  console.log('✓ UI lookups, fallback labels, routing badges and locale placeholders passed');
}

// Reproduce the live host's split script contexts: the UI's copy has no catalogs.
// Execute the production QML functions instead of preloading the UI fixture.
{
  const serviceSource = fs.readFileSync(path.join(__dirname, '../Service.qml'), 'utf8');
  function qmlFunction(source, name) {
    const match = source.match(new RegExp('function ' + name + '\\(([^)]*)\\)\\s*\\{([\\s\\S]*?)\\n  \\}'));
    assert(match, name);
    return { args: match[1], body: match[2] };
  }
  const emptyModule = { exports: {} };
  new Function('module', 'exports', i18nSrc)(emptyModule, emptyModule.exports);
  const emptyUiI18n = emptyModule.exports;
  assert.strictEqual(emptyUiI18n.t('app.name'), 'app.name');
  I18n.setCatalogs(enJson, ruJson);
  const service = { i18nRevision: 0, settings: {} };
  const commons = { I18n: { language: 'ru' } };
  service.hostI18n = commons.I18n;
  for (const name of ['tr', 'systemLanguage', 'setLocale']) {
    const f = qmlFunction(serviceSource, name);
    service[name] = new Function('root', 'Commons', 'I18n', `return function(${f.args}) {${f.body}}`)(service, commons, I18n);
  }
  const qmlFiles = ['Panel.qml', ...fs.readdirSync(path.join(__dirname, '../ui')).filter(f => f.endsWith('.qml')).map(f => 'ui/' + f)];
  const consumers = qmlFiles.map(file => {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    if (!source.includes('function tr(')) return null;
    const f = qmlFunction(source, 'tr');
    return new Function('root', 'I18n', 'i18nRevision', `return function(${f.args}) {${f.body}}`)({ service }, emptyUiI18n, 0);
  }).filter(Boolean);
  service.setLocale('auto');
  assert.strictEqual(service.effectiveLocale, 'ru', 'Auto follows Commons.I18n, independently of LANG');
  for (const translate of consumers) {
    assert.strictEqual(translate('app.name'), 'VPNRouter');
    assert.strictEqual(translate('state.disconnected'), 'Отключено');
    assert.strictEqual(translate('latency.ms', [12]), '12 мс');
  }
  service.setLocale('en');
  commons.I18n.language = 'ru';
  service.setLocale(service.locale); // Same callback as shell language changes.
  assert.strictEqual(service.effectiveLocale, 'en', 'Explicit override survives shell language changes');
  service.setLocale('auto');
  commons.I18n.language = 'en';
  service.setLocale(service.locale);
  assert.strictEqual(service.effectiveLocale, 'en', 'Auto tracks subsequent shell changes');
  service.hostI18n = null;
  const language = qmlFunction(serviceSource, 'systemLanguage');
  service.systemLanguage = new Function('root', 'Quickshell', `return function() {${language.body}}`)(service, {env: () => 'ru_RU.UTF-8'});
  service.setLocale('auto');
  assert.strictEqual(service.effectiveLocale, 'ru', 'Old host resolves auto from LANG');
  const panelSource = fs.readFileSync(path.join(__dirname, '../Panel.qml'), 'utf8');
  const toggle = qmlFunction(panelSource, 'toggleLocale');
  const saved = [];
  const hostWidget = { updateSetting: (key, value) => saved.push([key, value]) };
  const cycle = new Function('root', 'service', 'hostWidget', `return function() {${toggle.body}}`)({ service }, service, hostWidget);
  for (const expected of ['en', 'ru', 'auto']) {
    cycle();
    assert.strictEqual(service.locale, expected);
    assert.deepStrictEqual(saved.at(-1), ['locale', expected]);
  }
  console.log('✓ Real QML translators resolve across empty UI contexts and follow shell language/overrides');
}

// Product wording must describe the service, not its implementation layers.
for (const [key, value] of Object.entries(ruJson)) {
  assert(!/\b(?:backend|runtime|helper|TUN|legacy|Smart)\b/i.test(value), `${key}: implementation jargon in Russian UI`);
}
assert.strictEqual(ruJson['backend.notInstalled'], 'Служба VPNRouter не установлена');
assert.strictEqual(enJson['backend.notInstalled'], 'VPNRouter service is not installed');
