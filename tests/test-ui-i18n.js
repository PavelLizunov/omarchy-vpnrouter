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
  assert.strictEqual(I18n.t("subscriptions.serversCount", [5]), "5 servers");
  assert.strictEqual(I18n.t("diagnostics.exportedPath", ["/tmp/diag.tar.gz"]), "Bundle exported to: /tmp/diag.tar.gz");

  // Switch to Russian
  I18n.setLocale("ru");
  assert.strictEqual(I18n.t("app.name"), "VPNRouter");
  assert.strictEqual(I18n.t("state.connected"), "Подключено");
  assert.strictEqual(I18n.t("subscriptions.serversCount", [5]), "5 серверов");
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
