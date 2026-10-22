const assert = require('assert');
const fs = require('fs');
const vm = require('vm');
const path = require('path');
const repo = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(repo, file), 'utf8');
function library(file) {
  const module = {exports: {}};
  new Function('module', read(file).replace(/^\.pragma library\s*/m, ''))(module);
  return module.exports;
}
const Model = library('lib/Model.js');
const I18n = library('lib/I18n.js');
I18n.setCatalogs(JSON.parse(read('locales/en.json')), JSON.parse(read('locales/ru.json')));
const apps = {runningApps: [
  {name: 'helper', displayName: 'Background helper'},
  {name: 'firefox', displayName: 'Firefox Browser', desktopId: 'firefox.desktop', icon: 'firefox'},
  {name: 'steam', displayName: 'Steam', hasWindow: true, icon: 'https://invalid/icon'},
  {name: 'firefox', displayName: 'Duplicate'},
  {name: 'systemd', desktopId: 'misclassified.desktop'},
  {name: 'dbus-broker'}, {name: 'pipewire'}, {name: 'kworker/1:1'},
  {name: '../unsafe'}, null
]};
assert.deepStrictEqual(Model.runningApplications({running: ['systemd', 'firefox']}), [], 'Old peers must not expose raw process suggestions');
assert.deepStrictEqual(Model.runningApplications(apps).map(x => x.name), ['firefox', 'steam', 'helper']);
assert.deepStrictEqual(Model.runningApplications(apps, 'browser').map(x => x.name), ['firefox']);
assert.deepStrictEqual(Model.runningApplications(apps, 'FIREFOX').map(x => x.name), ['firefox']);
assert.strictEqual(Model.runningApplications(apps, 'steam')[0].icon, 'application-x-executable');
assert.strictEqual(Model.runningApplications(apps, 'firefox')[0].name, 'firefox', 'Display search never changes the exact match key');
assert.strictEqual(Model.runningApplications({runningApps: Array.from({length: 300}, (_, i) => ({name: 'app' + i}))}).length, 200);
const servers = [{id: 's', name: 'Sub', source: 'subscription', subscriptionId: 'one', removable: false},
  {id: 'u', name: 'Legacy'}, {id: 'm', name: 'Manual', source: 'manual', removable: true}];
assert.deepStrictEqual(Model.groupedServers(servers).map(x => x.id), ['m', 's', 'u']);
assert.deepStrictEqual(Model.groupedServers(servers, 'sub').map(x => x.id), ['s']);
assert.deepStrictEqual(servers.map(x => x.id), ['s', 'u', 'm'], 'Grouping must not mutate the service collection');
for (const locale of ['en', 'ru']) {
  I18n.setLocale(locale);
  for (const code of ['runtime-missing', 'runtime-capabilities', 'runtime-untrusted', 'sandbox', 'ownership', 'other']) {
    const s = Model.normalizeSnapshot({unavailableReasonCode: code, unavailableReason: 'English detail'});
    assert.notStrictEqual(Model.unavailableText(s, I18n), 'English detail');
    assert(!Model.unavailableText(s, I18n).startsWith('backend.reason.'));
  }
  assert.strictEqual(Model.unavailableText({unavailableReasonCode: 'future-code', unavailableReason: 'Legacy detail'}, I18n), 'Legacy detail');
  assert.strictEqual(Model.normalizeSnapshot({}).unavailableReasonCode, null);
  assert.strictEqual(Model.serverSourceLabel(servers[0], [{id: 'one', name: 'My plan'}], I18n), 'My plan');
  assert.notStrictEqual(Model.serverSourceLabel(servers[2], [], I18n), 'servers.sourceManual');
  // Invariant noun labels avoid quantity inflection; test zero and Russian 1/2/5/11/21.
  for (const n of [0, 1, 2, 5, 11, 21, 101]) {
    for (const key of ['apps.configuredHeader', 'subscriptions.serversCount']) {
      assert(I18n.t(key, [n]).includes(String(n)));
      assert(!I18n.t(key, [n]).includes('{0}'));
    }
  }
}
for (const [status, expected] of Object.entries({OK: 'pass', pass: 'pass', warn: 'warn', warning: 'warn', info: 'info', error: 'fail', FAIL: 'fail', future: 'unknown'})) {
  assert.strictEqual(Model.diagnosticSeverity({status}), expected);
}
assert.strictEqual(Model.diagnosticSeverity({status: 'warn', message: 'config.yaml missing at [path] (will be created on first launch)'}), 'info');
assert.strictEqual(Model.diagnosticSeverity({status: 'warn', message: 'directory missing: [path] (will be created on first launch)'}), 'info');
assert.strictEqual(Model.diagnosticSeverity({status: 'error', message: 'directory missing: [path] (will be created on first launch)'}), 'fail');
assert.strictEqual(Model.diagnosticSeverity({status: 'warn', message: 'config.yaml missing or unreadable'}), 'warn');
function functions(file, context) {
  context.i18nRevision = 0;
  vm.createContext(context);
  for (const match of read(file).matchAll(/^  function (\w+)\(([^)]*)\) \{([\s\S]*?)^  \}/gm)) {
    vm.runInContext(`function ${match[1]}(${match[2]}) {${match[3]}\n}`, context);
    context.root[match[1]] = context[match[1]];
  }
}
const writes = [];
const root = {service: {setApps: (mode, names) => writes.push({mode, names: [...names]})},
  configuredApps: ['firefox'], routingAppsMode: 'include'};
functions('ui/AppsView.qml', {root, I18n, Model});
root.addApp('firefox');
assert.strictEqual(writes.length, 0, 'No duplicate additions');
root.appLibrary = {iconSource: name => 'shell-icon:' + name};
assert.strictEqual(root.appIconSource('chromium'), 'shell-icon:chromium', 'Use the host app library when injected');
root.addApp('CustomCaseApp');
assert.deepStrictEqual(writes.pop(), {mode: 'include', names: ['firefox', 'CustomCaseApp']}, 'User match names retain exact case');
root.addApp('steam');
assert.deepStrictEqual(writes.pop(), {mode: 'include', names: ['firefox', 'steam']});
root.removeApp('firefox');
assert.deepStrictEqual(writes.pop(), {mode: 'include', names: []});
// Exercise the real navigation function and form behavior using inert callbacks.
const route = {mode: 'simple', setDisplayMode(value) {this.mode = value;}};
let opened = 0;
functions('Panel.qml', {root: route, service: null, I18n, Model, subscriptionsView: {openForm() {opened++;}}, flickableContent: {contentY: 99}});
route.setDisplayMode = value => {route.mode = value;};
route.openSubscriptionForm();
assert.strictEqual(route.mode, 'advanced');
assert.strictEqual(route.currentTab, 'subscriptions');
assert.strictEqual(opened, 1);
let sent = 0;
const input = text => ({text, clear() {this.text = '';}, forceActiveFocus() {}});
const name = input('Example'), url = input('');
const sub = {service: {addSubscription(n, u, done) {sent++; assert.strictEqual(url.text, ''); done();}}, tr: I18n.t};
functions('ui/SubscriptionsView.qml', {root: sub, I18n, Qt: {callLater(f) {f();}}, subNameInput: name, subUrlInput: url});
sub.submit();
assert.strictEqual(sent, 0, 'Empty URL cannot submit');
url.text = 'fixture-only';
sub.submit();
assert.strictEqual(sent, 1);
assert.strictEqual(sub.showAddForm, false);
assert.strictEqual(sub.successNotice, I18n.t('subscriptions.added'));
console.log('PASS: r4 application metadata/legacy fallback, grouping, reason codes, severities, count labels, actual QML selection and first-run form flow');
