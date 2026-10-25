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
assert.strictEqual(root.snapshotLoaded, true, "Snapshot receipt is explicit, even if revision could be empty");
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
  assert.strictEqual(root.snapshotLoaded, false, "A new process needs a fresh snapshot");
  root.snapshotLoaded = true;
  root.backendExited(1);
  assert.strictEqual(root.snapshotLoaded, false, "Exit invalidates displayed status readiness");
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
  assert(Model.verificationText(root[field], items, I18n).includes(I18n.t(extra.error ? "backend.connectUnavailable" : "error.generic")));
  root[method](id);
  reply({code: 'unavailable', message: 'VPN runtime is unavailable'}, true);
  assert(Model.verificationText(root[field], items, I18n).includes(I18n.t("backend.connectUnavailable")));
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

// A read-only refresh must never imitate a VPN connection attempt.
const busySource = read('ui/HeroCard.qml').match(/readonly property bool busy: (.*)/)[1];
const isConnectionBusy = new Function('service', `return (${busySource})`);
for (const method of ['snapshot','servers.list','subscriptions.list','apps.list','settings.get']) {
  assert.strictEqual(isConnectionBusy({busy:true,isConnecting:false,isDisconnecting:false,activeOperation:method}),false);
}
assert.strictEqual(isConnectionBusy({busy:true,isConnecting:true,activeOperation:'connect'}),true);
assert.strictEqual(isConnectionBusy({busy:true,isDisconnecting:true,activeOperation:'disconnect'}),true);
assert.strictEqual(binding('ui/HeroCard.qml', /enabled: (.*)/,
  {connected:false,canConnect:true,busy:false,operationBusy:true,needsSetup:false}),false);
console.log('PASS: collection refresh has no connection arc and keeps Connect admission disabled');

// Night 2: execute real handlers for paginated collections and probe edge cases.
root._requestQueue.clearAll(); root._pendingCallbacks = {}; root.activeRequestId = '';
root.fakeBackend = {write(text) { written.push(JSON.parse(text)); }};
ctx.backendProc.running = true;
for (const [method, field, totalField] of [['listServers','servers','serversTotal'],
  ['listSubscriptions','subscriptions','subscriptionsTotal'],['listFree','freeServers','freeTotal']]) {
  const first = Array.from({length:100}, (_,i) => ({id:'row-'+i,name:'Server '+i,latencyMs:null}));
  const second = Array.from({length:25}, (_,i) => ({id:'row-'+(100+i),name:'Server '+(100+i),latencyMs:0}));
  root[method](0,100); reply({items:first,total:125});
  root[method](100,100); reply({items:second,total:125});
  assert.strictEqual(root[field].length,125);
  assert.strictEqual(root[field][124].id,'row-124');
  assert.strictEqual(root[totalField],125);
  const previous = root[field]; let invalid;
  root[method](0,100,null,err => {invalid=err;}); reply({items:'malformed',total:125});
  assert.strictEqual(invalid.code,'invalid_response');
  assert.strictEqual(root[field],previous,'Malformed page preserves usable rows');
  root[method](0,100); reply({items:[],total:0});
  assert.strictEqual(root[field].length,0); assert.strictEqual(root[totalField],0);
}
root.servers=[{id:'probe',name:'Probe fixture',latencyMs:77}];
for (const latencyMs of [0,42,null]) {
  root.testServer('probe'); reply({id:'probe',reachable:latencyMs!==null,latencyMs});
  assert.strictEqual(root.servers[0].latencyMs,latencyMs);
  const text=Model.testText(root.serverTest,root.servers,I18n);
  assert(text.includes(latencyMs===null?'No latency measured':latencyMs+' ms'));
}
root.testServer('probe'); reply({code:'not_found',message:'Server not found'},true);
assert.match(Model.testText(root.serverTest,root.servers,I18n),/Latency test failed/);
for(const locale of ['en','ru']) {
  I18n.setLocale(locale);
  assert(Model.testText({id:'probe',errorCode:'timeout'},root.servers,I18n).includes(I18n.t('test.timeout',['Probe fixture'])));
}
I18n.setLocale('en');
root.fakeBackend=null; ctx.backendProc.running=false;
let missing;
assert.strictEqual(root.importServers('fixture',null,err => {missing=err;}),null);
assert.strictEqual(missing.code,'not_running');
assert.strictEqual(root._requestQueue.size(),0,'Missing helper cannot strand a form in an undispatched queue');
root.fakeBackend={write(text) {written.push(JSON.parse(text));}};ctx.backendProc.running=true;
root.refreshSnapshot();
for(let i=0;i<8;i++) root.refreshSnapshot();
root.lastError='';assert.strictEqual(root.refreshSnapshot(),null);
assert.strictEqual(root.lastError,I18n.t('error.queueFull'),'A button without a callback still reports queue rejection');
root.backendExited(1);
assert.strictEqual(Object.keys(root._pendingCallbacks).length,0);
assert.strictEqual(root._requestQueue.size(),0);
assert.strictEqual(root.capabilities.connect,false);
assert.strictEqual(Protocol.parseFrame('{"v":1,"event":"state","data":[]}').error,'invalid_event_data');
console.log('PASS: real QML pagination 125 rows, malformed/empty pages, probe null/0/error, missing backend, queue overflow and crash cleanup');
root.fakeBackend={write(text) {written.push(JSON.parse(text));}};ctx.backendProc.running=true;
for(const [method,params,expected] of [['connect',{},100000],['disconnect',{},35000],['servers.verify',{id:'probe'},20000],['free.verify',{id:'probe'},20000],['servers.test',{id:'probe'},15000]]) {
  root.sendRequest(method,params);const cb=root._pendingCallbacks[written.at(-1).id];
  assert(cb.deadline-Date.now()>expected-1000 && cb.deadline-Date.now()<=expected);
  reply(snapshot);
}
root.subscriptionsTotal=3;root.refreshSubscription();
assert(root._pendingCallbacks[written.at(-1).id].deadline-Date.now()>59000);
root.backendExited(1);
console.log('PASS: request budgets cover backend connect/warmup/stop, verification and multi-subscription refresh');
root.fakeBackend={write(text) {written.push(JSON.parse(text));}};ctx.backendProc.running=true;
root.state='disconnected';root.capabilities={connect:true};root.connect();
assert.strictEqual(root.connect(),null,'A quick bar double click cannot duplicate connect');
root.backendExited(1);
root.fakeBackend={write(text) {written.push(JSON.parse(text));}};ctx.backendProc.running=true;
root.disconnect();assert.strictEqual(root.disconnect(),null,'A pending urgent disconnect is not duplicated');
root.backendExited(1);
console.log('PASS: quick bar controls ignore duplicate lifecycle requests (fake transport only)');

// Night 2 resume: late terminals cannot replace a newer operation's state.
root.fakeBackend={write(text) {written.push(JSON.parse(text));}};ctx.backendProc.running=true;
root.verifyServer('probe');
const expiredId=written.at(-1).id;
root.checkDeadlines(root._pendingCallbacks[expiredId].deadline+1);
assert.strictEqual(root.lastErrorKey,'error.timeout');
assert.strictEqual(root.lastErrorMethod,'servers.verify');
root.refreshSnapshot(); reply(snapshot);
assert.strictEqual(root.lastErrorMethod,'servers.verify','Snapshot refresh retains the failed verification');
root.listServers(); reply({items:root.servers,total:root.servers.length});
assert.strictEqual(root.lastErrorMethod,'servers.verify','Unrelated successful reads retain the operation error');
root.verifyServer('probe'); reply({id:'probe',ok:false,error:'Timeout'});
assert.strictEqual(root.lastErrorMethod,'servers.verify','An unsuccessful retry does not erase the original operation error');
root.verifyServer('probe');
const currentId=written.at(-1).id;
root.handleResponse(expiredId,false,{id:'probe',ok:true,latencyMs:900},null);
assert.strictEqual(root.activeRequestId,currentId,'Late success cannot complete the current operation');
assert.strictEqual(root.serverVerification,null,'Late verification cannot overwrite its replacement');
root.handleResponse(expiredId,true,null,{code:'timeout',message:'Late timeout'});
assert.strictEqual(root.lastErrorKey,'error.timeout');
reply({id:'probe',ok:true,latencyMs:42});
assert.strictEqual(root.lastError,'','Successful retry clears the same operation error');
root.verifyServer('probe'); reply({code:'timeout',message:'Raw timeout'},true);
for(const locale of ['en','ru']) {
  I18n.setLocale(locale);
  assert(Model.verificationText(root.serverVerification,root.servers,I18n).includes(I18n.t('error.timeout')));
  assert(Model.testText({id:'probe',reachable:true,latencyMs:null},root.servers,I18n).includes(I18n.t('test.reachable',['Probe fixture'])));
}
for (const locale of ['en','ru']) {
  I18n.setLocale(locale);
  assert(!/UDP/.test(I18n.t('test.reachable', ['Probe fixture'])), 'No probe kind is supplied by this response');
  for (const protocol of ['vless', 'hysteria2', 'tuic']) {
    const items = [{id:'probe',name:'Probe fixture',protocol}];
    assert.strictEqual(Model.testText({id:'probe',reachable:true,latencyMs:null},items,I18n), I18n.t('test.reachable',['Probe fixture']));
    assert.strictEqual(Model.testText({id:'probe',reachable:true,latencyMs:0},items,I18n), I18n.t('test.measured',['Probe fixture',I18n.t('latency.ms',[0])]));
  }
}
I18n.setLocale('en');
console.log('PASS: expired responses, error recovery and EN/RU protocol-neutral null/zero feedback');

root.state='disconnected';root.capabilities={connect:true};root.configMode='generated';root.serversLoaded=true;root.servers=[];
const beforeEmptyConnect=written.length;
assert.strictEqual(root.connect(),null,'Quick connect cannot submit an empty generated configuration');
root.configMode='custom';root.activeServer='';
assert.strictEqual(root.connect(),null,'Quick connect cannot submit an absent custom configuration');
assert.strictEqual(written.length,beforeEmptyConnect);
console.log('PASS: quick connect rejects empty generated and custom configurations without backend writes');

// Only a validated startup response announces readiness to an open panel.
root._requestQueue.clearAll();root._pendingCallbacks={};root.activeRequestId='';root.activeOperation='';
let readyCount=0;
root.backendReady=()=>{readyCount++;};
ctx.backendProc.running=true;
for (const [result, expected] of [[null,0],[snapshot,1]]) {
  later.length=0;root.backendStarted();later.shift()();reply(result);
  assert.strictEqual(readyCount,expected,'Only a valid startup snapshot announces readiness');
}
root.handleEvent('state',snapshot);
root.refreshSnapshot();reply(snapshot);
assert.strictEqual(readyCount,1,'State events and ordinary refreshes cannot repeat startup readiness');
later.length=0;root.backendStarted();ctx.backendProc.running=false;
const beforeStoppedStartup=written.length;later.shift()();
assert.strictEqual(written.length,beforeStoppedStartup,'An exited process cannot start a delayed handshake');
ctx.backendProc.running=true;
console.log('PASS: validated startup readiness, malformed response rejection and exit-before-handshake guard');
