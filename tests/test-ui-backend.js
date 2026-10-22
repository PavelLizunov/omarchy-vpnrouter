const assert = require('assert');
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const repo = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(repo, file), 'utf8');
function library(file) {
  const module = {exports: {}};
  new Function('module', read(file).replace(/^\.pragma library\s*/m, ''))(module);
  return module.exports;
}
const Model = library('lib/Model.js');
const Protocol = library('lib/Protocol.js');
const I18n = library('lib/I18n.js');
I18n.setCatalogs(JSON.parse(read('locales/en.json')), JSON.parse(read('locales/ru.json')));
I18n.setLocale('en');

// Execute the actual QML function bodies; no copied service simulator or shell.
function qmlFunctions(file, context) {
  context.i18nRevision = 0;
  vm.createContext(context);
  for (const match of read(file).matchAll(/^  function (\w+)\(([^)]*)\) \{([\s\S]*?)^  \}/gm)) {
    vm.runInContext(`function ${match[1]}(${match[2]}) {${match[3]}\n}`, context);
    context.root[match[1]] = context[match[1]];
  }
  return context.root;
}
const written = [];
const later = [];
const timer = {interval: 0, restarts: 0, stopped: false,
  restart() { this.restarts++; this.stopped = false; }, stop() { this.stopped = true; }};
const root = {
  _pendingCallbacks: {}, _pendingUrgentCount: 0, maxUrgentPending: 4,
  _requestQueue: Protocol.createRequestQueue(8), _accumulator: {reset() {}},
  _shuttingDown: false, requestDeadlineMs: 15000, retryBackoffMs: 2000, retryCount: 0,
  activeRequestId: '', activeOperation: '', activeProgress: null, revision: 'r1',
  fakeBackend: {write(text) { written.push(JSON.parse(text)); }},
  capabilities: {connect: false, killSwitch: false, dnsLockdown: false},
  servers: [], freeServers: [], errorNotice() {}, stateChangedNotice() {}, progressNotice() {}
};
const ctx = {root, Model, Protocol, I18n, retryTimer: timer,
  backendProc: {running: true}, Qt: {callLater(fn) { later.push(fn); }}};
for (const key of Object.keys(root)) {
  Object.defineProperty(ctx, key, {get: () => root[key], set: value => { root[key] = value; }, configurable: true});
}
qmlFunctions('Service.qml', ctx);
const snapshot = {state: 'disconnected', revision: 'r2', busy: false,
  unavailableReason: 'sing-box runtime is missing capabilities; reinstall the vpnrouter-headless package',
  capabilities: {connect: false, killSwitch: false, dnsLockdown: false}};
function reply(result, isError = false) {
  const request = written.at(-1);
  root.handleResponse(request.id, isError, isError ? null : result, isError ? result : null);
}
root.applySnapshot(snapshot);
assert.strictEqual(root.unavailableReason, snapshot.unavailableReason);
assert.strictEqual(Model.normalizeSnapshot({...snapshot, unavailableReason: null}).unavailableReason, '');
assert.strictEqual(Model.normalizeSnapshot({...snapshot, unavailableReason: {}}).unavailableReason, '');
assert.strictEqual(root.connect(), null);
assert.strictEqual(root.lastError, snapshot.unavailableReason);
assert.strictEqual(written.length, 0, 'Unavailable connect must never be dispatched');

// Fast start/exit cycles grow; only a valid snapshot RESPONSE resets the delay.
const delays = [];
for (let i = 0; i < 5; i++) {
  root.backendStarted();
  root.backendExited(1);
  delays.push(timer.interval);
}
assert.deepStrictEqual(delays, [2000, 3000, 4500, 6750, 10125]);
root.applySnapshot(snapshot); // state event is not a successful handshake
assert.strictEqual(root.retryCount, 5);
root.refreshSnapshot();
reply(null);
assert.strictEqual(root.retryCount, 5, 'Malformed success result must not reset backoff');
root.refreshSnapshot();
reply({code: 'unavailable', message: 'The requested service or feature is unavailable.'}, true);
assert.strictEqual(root.retryCount, 5, 'An error response must not reset backoff');
root.refreshSnapshot();
reply(snapshot);
assert.strictEqual(root.retryCount, 0);
assert.strictEqual(root.retryBackoffMs, 2000);
for (let i = 0; i < 20; i++) root.backendExited(1);
assert.strictEqual(root.retryBackoffMs, 30000, 'Retry delay is capped at 30 seconds');
root.backendExited(127);
assert.strictEqual(root.backendMissing, true);
assert.strictEqual(timer.stopped, true);
assert.strictEqual(root.activeOperation, '');
assert.strictEqual(root.busy, false);
assert.strictEqual(root.capabilities.connect, false);
root._shuttingDown = true;
const before = timer.restarts;
root.backendExited(1);
assert.strictEqual(timer.restarts, before);
root._shuttingDown = false;

// Real wire results differ for configured/free servers; show both outcomes.
root.servers = [{id: 'srv_1', name: 'My server'}];
root.freeServers = [{id: 'free_1', name: 'Free one'}];
for (const [method, field, items, id, extra] of [
  ['verifyServer', 'serverVerification', root.servers, 'srv_1', {error: 'unavailable'}],
  ['verifyFree', 'freeVerification', root.freeServers, 'free_1', {status: 'failed'}]
]) {
  root[method](id);
  assert.strictEqual(written.at(-1).method, method === 'verifyServer' ? 'servers.verify' : 'free.verify');
  assert.deepStrictEqual(written.at(-1).params, {id});
  reply({id, ok: true, latencyMs: 27, ...extra});
  assert.match(Model.verificationText(root[field], items, I18n), /Verification passed: .*27 ms/);
  root[method](id);
  reply({id, ok: false, latencyMs: null, ...extra});
  assert.match(Model.verificationText(root[field], items, I18n), /Verification failed:/);
  assert(Model.verificationText(root[field], items, I18n).includes(extra.error || extra.status));
  root[method](id);
  reply({code: 'unavailable', message: 'VPN runtime is unavailable'}, true);
  assert.match(Model.verificationText(root[field], items, I18n), /VPN runtime is unavailable/);
}
I18n.setLocale('ru');
assert.match(Model.verificationText({id: 'srv_1', ok: true, latencyMs: 27}, root.servers, I18n), /Проверка пройдена: My server \(27 мс\)/);
I18n.setLocale('en');

// Cancel false is not completion. A true acknowledgement still awaits target response.
root.activeRequestId = 'target'; root.activeOperation = 'servers.verify'; root.activeProgress = {completed: 0};
root.cancel(); reply({cancelled: false});
assert.strictEqual(root.activeOperation, 'servers.verify');
assert(root.activeProgress);
root.cancel(); reply({cancelled: true});
assert.strictEqual(root.activeOperation, 'servers.verify');
assert.strictEqual(root.activeProgress, null);
root.activeRequestId = ''; root.activeOperation = '';
// Backend mutation snapshot can carry busy=true after its final busy=false event.
root.setRouting('split', 'include');
root.handleEvent('state', snapshot);
reply({...snapshot, busy: true});
assert.strictEqual(root.busy, false, 'Terminal ordinary response cannot leave a stale busy spinner');
root.handleEvent('progress', {stage: 'refresh_subscription', completed: 1, total: 2});
assert.strictEqual(root.activeProgress.id, '');
root.handleEvent('progress', {id: 'srv_1', stage: 'verify_start', completed: 0, total: 1});
assert.strictEqual(root.activeProgress.id, 'srv_1');

const hero = {service: {...snapshot, backendMissing: false}, connected: false, busy: false,
  canConnect: false, tr: I18n.t};
qmlFunctions('ui/HeroCard.qml', {root: hero, I18n, Model});
assert.strictEqual(hero.availabilityText(), snapshot.unavailableReason);
hero.service.backendMissing = true;
assert.match(hero.availabilityText(), /^VPNRouter service is not installed\n.*vpnrouter-headless/);
hero.connected = true;
assert.strictEqual(hero.availabilityText(), '');
// Execute the real control bindings as JavaScript with both capability values.
function binding(file, pattern, values) {
  const match = read(file).match(pattern); assert(match);
  return new Function('root', `return (${match[1]})`)(values);
}
assert.strictEqual(binding('ui/SettingsView.qml', /checked: (root.hasDnsLockdownCap && root.dnsLeakVal)/,
  {hasDnsLockdownCap: false, dnsLeakVal: true}), false);
assert.strictEqual(binding('ui/SettingsView.qml', /checked: (root.hasDnsLockdownCap && root.dnsLeakVal)/,
  {hasDnsLockdownCap: true, dnsLeakVal: true}), true);
for (const [values, expected] of [
  [{connected:false,canConnect:false,busy:false,needsSetup:false}, false],
  [{connected:false,canConnect:true,busy:false,needsSetup:false}, true],
  [{connected:true,canConnect:false,busy:false,needsSetup:false}, true],
  [{connected:true,canConnect:true,busy:true,needsSetup:false}, false],
  [{connected:false,canConnect:true,busy:false,needsSetup:true}, false]
]) {
  assert.strictEqual(binding('ui/HeroCard.qml', /enabled: (.*)/, values), expected);
}
assert.strictEqual(root.capabilities.killSwitch, false);
assert(!/checked:.*killSwitch/i.test(read('ui/SettingsView.qml')), 'No unsupported kill-switch toggle');
const settingsRoot = {hasDnsLockdownCap: false, dnsLeakVal: true, cidrsVal: '', mtuVal: 1420};
qmlFunctions('ui/SettingsView.qml', {root: settingsRoot, I18n, Model});
assert(!('dnsLeakLockdown' in settingsRoot.buildSettingsPayload()));
console.log('PASS: actual QML backend contract, availability, retry, verify, cancellation and protection bindings');

// Qt 6.12 also exports a Color type; qualify the shell palette like installed clock.
for (const file of ['BarWidget.qml', 'Panel.qml',
  ...fs.readdirSync(path.join(repo, 'ui')).filter(f => f.endsWith('.qml')).map(f => 'ui/' + f)]) {
  assert(!/(?<![.\w])Color\./.test(read(file)), `${file}: ambiguous shell palette`);
  assert(!/\w+Commons\.Color/.test(read(file)), `${file}: preserve existing color property names`);
}
