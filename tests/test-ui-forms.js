// Execute the production QML handlers; no duplicated form implementation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const modelModule = {exports: {}};
new Function('module', fs.readFileSync(path.join(__dirname, '../lib/Model.js'), 'utf8').replace(/^\.pragma library\s*/m, ''))(modelModule);
const Model = modelModule.exports;
function load(file, root, ids = {}) {
  const context = {root, Model, I18n: {t: key => key}, i18nRevision: 0, Qt: {callLater: fn => fn()}, feedback: {reveal() {}}, ...ids};
  vm.createContext(context);
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  for (const match of source.matchAll(/^  function (\w+)\(([^)]*)\) \{([\s\S]*?)^  \}/gm)) {
    vm.runInContext(`function ${match[1]}(${match[2]}) {${match[3]}\n}`, context);
    root[match[1]] = context[match[1]];
  }
  return root;
}
const input = text => ({text, clear() {this.text = '';}, forceActiveFocus() {}});
const base = () => ({pending: false, tr: key => key});
{
  const name = input(''), url = input('');
  let sends = 0, done, fail;
  const root = load('ui/SubscriptionsView.qml', {...base(), showAddForm: true, service: {
    addSubscription(n, u, ok, error) {sends++; done = ok; fail = error; assert.equal(url.text, u);}
  }}, {subNameInput: name, subUrlInput: url, addToggle: input('')});
  root.submit(); assert.equal(root.errorKey, 'form.required'); assert.equal(sends, 0);
  name.text = 'Fixture';
  for (const invalid of ['invalid', 'file:///tmp/sub', 'https://', 'https://bad host', 'https://example.invalid/' + 'x'.repeat(2048)]) {
    url.text = invalid; root.submit(); assert.equal(root.errorKey, 'subscriptions.invalidUrl');
  }
  assert.equal(sends, 0);
  url.text = 'https://example.invalid/sub'; name.text = 'x'.repeat(257); root.submit(); assert.equal(root.errorKey, 'form.nameTooLong');
  name.text = 'Fixture'; root.submit(); assert.equal(root.pending, true); root.submit(); assert.equal(sends, 1);
  root.cancelForm(); assert.equal(root.showAddForm, true, 'Pending form cannot be cleared');
  fail(); assert.equal(root.pending, false); assert.equal(url.text, 'https://example.invalid/sub'); assert.equal(root.errorKey, 'subscriptions.addFailed');
  root.submit(); done(); assert.equal(url.text, ''); assert.equal(name.text, ''); assert.equal(root.showAddForm, false);
  root.showAddForm = true; name.text = 'Discard'; url.text = 'Discard'; root.cancelForm(); assert.equal(url.text, ''); assert.equal(name.text, '');
}
{
  const area = input(''); let done, fail, sends = 0;
  const root = load('ui/ServersView.qml', {...base(), showImportBox: true, service: {
    importServers(text, ok, error) {sends++; done = ok; fail = error;}
  }}, {importArea: area, importToggleBtn: input('')});
  root.submit(); assert.equal(root.noticeKey, 'form.required'); assert.equal(sends, 0);
  area.text = 'unrecognized text'; root.submit(); fail({code: 'invalid_argument'});
  assert.equal(root.showImportBox, true); assert.equal(area.text, 'unrecognized text'); assert.equal(root.noticeKey, 'servers.invalidImport');
  root.submit(); done(); assert.equal(root.showImportBox, false); assert.equal(area.text, ''); assert.equal(root.noticeKey, 'servers.imported');
}
{
  const name = input('Fixture'), area = input(''); let done, fail, sends = 0;
  const root = load('ui/CustomConfigView.qml', {...base(), showImportForm: true, service: {
    importCustom(n, text, ok, error) {sends++; done = ok; fail = error;}
  }}, {customNameInput: name, customTextArea: area, importToggle: input('')});
  for (const invalid of ['{', 'null', '[]', '"value"', '1']) {
    area.text = invalid; root.submit(); assert.equal(root.noticeKey, 'custom.invalidJson');
  }
  assert.equal(sends, 0);
  area.text = '{"outbounds":[]}'; root.submit(); fail({code: 'invalid_argument'});
  assert.equal(root.noticeKey, 'custom.invalidConfig'); assert.equal(root.showImportForm, true); assert.equal(area.text, '{"outbounds":[]}');
  root.submit(); done(); assert.equal(root.showImportForm, false); assert.equal(area.text, ''); assert.equal(name.text, '');
}
{
  const mtu = input('abc'), cidr = input('bad subnet\n2001:db8::/32'); let values, done, fail;
  const root = load('ui/SettingsView.qml', {...base(), mtuVal: 1420, hasDnsLockdownCap: false, service: {
    setSettings(payload, ok, error) {values = payload; done = ok; fail = error;}
  }}, {mtuInput: mtu, cidrEdit: cidr});
  root.submit(); assert.equal(values, undefined); assert.equal(root.saveNotice, 'settings.invalidMtu');
  for (const invalid of ['', '575', '9001', '1400.5', '1e3']) {mtu.text = invalid; root.submit(); assert.equal(values, undefined);}
  mtu.text = '1400'; root.submit(); assert.equal(values.mtu, 1400);
  assert.deepEqual(Array.from(values.routeExcludeAddress), ['bad subnet', '2001:db8::/32'], 'Backend validates every CIDR; none silently disappear');
  assert.equal('dnsLeakLockdown' in values, false);
  fail({code: 'invalid_argument'}); assert.equal(root.saveNotice, 'settings.invalid'); assert.equal(cidr.text, 'bad subnet\n2001:db8::/32');
  root.submit(); done(); assert.equal(root.saveNotice, 'settings.saved');
}
{
  const area = input('UNSAVED DRAFT'); let done, fail;
  const root = load('ui/RulesView.qml', {...base(), importExportFormat: 'json', service: {
    exportRules(format, ok, error) {done = ok; fail = error;}
  }}, {rulesTextEdit: area});
  root.exportText(); assert.equal(root.pending, true); done('{"rules":[]}');
  assert.equal(area.text, 'UNSAVED DRAFT'); assert.equal(root.exportedText, '{"rules":[]}'); assert.equal(root.statusNotice, 'rules.exportReady');
  root.exportText(); fail({code: 'transport_error'}); assert.equal(root.exportedText, ''); assert.equal(root.statusNotice, 'form.failed');
}
console.log('PASS: production form handlers validate, retain drafts on failure, prevent duplicate submission, clear on success/cancel, and preserve exported drafts/CIDRs');
