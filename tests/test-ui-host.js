const assert = require('assert');
const fs = require('fs');
const path = require('path');

// Exercise actual QML JavaScript bodies without starting another shell.
function body(file, name, args) {
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const match = source.match(new RegExp('  function ' + name + '\\([^)]*\\) \\{([\\s\\S]*?)\\n  \\}'));
  assert(match, `${file}: ${name} must exist`);
  return new Function(...args, match[1]);
}

const settings = {mode: 'advanced', locale: 'ru'};
const root = {bar: {}, settings, effectiveService: {}, hostWidget: {}};
const button = {};
const item = {};
const loader = {item};
const syncPanel = body('BarWidget.qml', 'syncPanel', ['root', 'panelLoader', 'button']);
syncPanel(root, loader, button);
assert.strictEqual(item.settings, settings);
assert.strictEqual(item.bar, root.bar);
assert.strictEqual(item.service, root.effectiveService);
assert.strictEqual(item.anchorItem, button);
assert.strictEqual(item.hostWidget, root);
syncPanel(root, {item: null}, button);

let localeCalls = 0;
const service = {locale: 'auto', setLocale(value) { this.locale = value; localeCalls++; }};
const syncSettings = body('BarWidget.qml', 'syncSettings', ['syncPanel', 'setting', 'effectiveService']);
syncSettings(() => {}, key => settings[key], service);
syncSettings(() => {}, key => settings[key], service);
assert.strictEqual(service.locale, 'ru');
assert.strictEqual(localeCalls, 1, 'Repeated settings sync must not reset locale listeners');
syncSettings(() => {}, () => 'auto', null);

const switchPanel = body('Panel.qml', 'switchPanel', ['root', 'direction']);
root.bar.switchPanelFrom = (owner, direction) => {
  assert.strictEqual(owner, root.hostWidget);
  assert.strictEqual(direction, -1);
  return true;
};
assert.strictEqual(switchPanel(root, -1), true);
assert.strictEqual(switchPanel({bar: null}, 1), false);

const applySnapshot = body('Service.qml', 'applySnapshot', ['root', 'data', 'Model']);
const snapshotRoot = {};
applySnapshot(snapshotRoot, {}, {normalizeSnapshot: () => ({errorCode: null})});
assert.strictEqual(snapshotRoot.errorCode, '', 'Absent error must remain an empty QML string');
console.log('PASS: actual QML host context, locale, panel switching and absent error');

// Old hosts omit Commons.I18n entirely; startup must still resolve LANG.
const systemLanguage = body('Service.qml', 'systemLanguage', ['root', 'Quickshell']);
const env = {env(name) { assert.strictEqual(name, 'LANG'); return 'ru_RU.UTF-8'; }};
assert.strictEqual(systemLanguage({hostI18n: null}, env), 'ru_RU.UTF-8');
assert.strictEqual(systemLanguage({hostI18n: {}}, env), 'ru_RU.UTF-8');
assert.strictEqual(systemLanguage({hostI18n: {language: 'en'}}, env), 'en');
assert.strictEqual(systemLanguage({hostI18n: {language: 'ru'}}, env), 'ru');
console.log('PASS: host language feature detection and LANG fallback');

const navigate = body('Service.qml', 'requestNavigation', ['root', 'payloadJson']);
const calls = [];
const navRoot = {pendingNavigation: null, shell: {summon(id, payload) { calls.push([id, payload]); return true; }}};
for (const invalid of ['{', 'null', '[]', '{}', '{"page":"connect"}', '{"page":"home","form":"add"}', 'x'.repeat(1025)]) {
  assert.strictEqual(navigate(navRoot, invalid), false);
  assert.strictEqual(navRoot.pendingNavigation, null);
}
assert.strictEqual(calls.length, 0, 'Invalid navigation must not open the shell');
for (const page of ['home','servers','subscriptions','apps','rules','settings','diagnostics','free','profiles','custom']) {
  assert.strictEqual(navigate(navRoot, JSON.stringify({page})), true);
  assert.deepStrictEqual(navRoot.pendingNavigation, {page, form: ''});
}
for (const [page,form] of [['servers','import'],['subscriptions','add']]) {
  assert.strictEqual(navigate(navRoot, JSON.stringify({page,form})), true);
  assert.deepStrictEqual(navRoot.pendingNavigation, {page,form});
}
navRoot.shell.summon = () => false;
assert.strictEqual(navigate(navRoot, '{"page":"servers"}'), false);
assert.strictEqual(navRoot.pendingNavigation, null);
assert.strictEqual(navigate({shell: null}, '{"page":"servers"}'), false);
console.log('PASS: bounded navigation routes only to supported pages/forms through host summon');

const openBar = body('BarWidget.qml', 'open', ['root','panelLoader','Qt']);
const lifecycle = [];
const panel = {navigate(page,form) { lifecycle.push(['navigate',page,form]); },open() { lifecycle.push(['open']); }};
const opener = {effectiveService: {pendingNavigation:{page:'servers',form:'import'}},panelItem:panel,syncPanel() { lifecycle.push(['sync']); }};
const panelLoader = {active:false};
openBar(opener,panelLoader,{callLater(fn) { fn(); }});
assert.strictEqual(panelLoader.active,true);
assert.strictEqual(opener.effectiveService.pendingNavigation,null);
assert.deepStrictEqual(lifecycle,[['sync'],['navigate','servers','import'],['open']]);
lifecycle.length=0;
openBar(opener,panelLoader,{callLater(fn) { fn(); }});
assert.deepStrictEqual(lifecycle,[['sync'],['open']], 'Normal reopen must not replay a consumed route');
console.log('PASS: actual bar open consumes navigation once before panel lifecycle');

const languages = [];
navRoot.shell.summon = () => true;
navRoot.setLocale = locale => languages.push(locale);
for (const locale of ['en','ru','auto']) {
  assert.strictEqual(navigate(navRoot, JSON.stringify({page:'home',locale})),true);
}
assert.deepStrictEqual(languages,['en','ru','auto']);
assert.strictEqual(navigate(navRoot,'{"page":"home","locale":"unknown"}'),false);
assert.strictEqual(languages.length,3);
console.log('PASS: session-only locale preview validates values without saving host configuration');

const focusSource = fs.readFileSync(path.join(__dirname, '../lib/Focus.js'), 'utf8').replace(/^\.pragma library\s*/m, '');
const reveal = new Function(focusSource + '\nreturn reveal;')();
for (const force of [false, true]) {
  assert.doesNotThrow(() => reveal(null, force), 'A delayed focus callback may outlive its delegate');
}
const viewport = {objectName:'vpnContentViewport',contentItem:{},contentY:0,contentHeight:500,height:100};
const focusItem = {activeFocus:true,parent:viewport,height:30,mapToItem() {return {y:150};}};
reveal(focusItem);assert.strictEqual(viewport.contentY,80,'Living focused controls are still revealed');
focusItem.activeFocus=false;viewport.contentY=0;reveal(focusItem);assert.strictEqual(viewport.contentY,0);
reveal(focusItem,true);assert.strictEqual(viewport.contentY,80,'Forced notice reveal still works');
console.log('PASS: actual focus helper ignores destroyed delegates and preserves focused/forced scrolling');
