const assert = require("assert");
const fs = require("fs");
const path = require("path");

console.log("=== Testing Plugin Manifest and QML Contracts ===");

const rootDir = path.join(__dirname, "..");

// 1. Manifest Contract
{
  const manifestPath = path.join(rootDir, "manifest.json");
  assert(fs.existsSync(manifestPath), "manifest.json must exist");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

  assert.strictEqual(manifest.schemaVersion, 1, "schemaVersion must be 1");
  assert.strictEqual(manifest.id, "io.github.pavellizunov.vpnrouter", "Plugin ID must be io.github.pavellizunov.vpnrouter");
  assert.strictEqual(manifest.license, "GPL-3.0-or-later", "License must be GPL-3.0-or-later, NOT MIT");
  assert(Array.isArray(manifest.kinds), "kinds must be an array");
  assert(manifest.kinds.includes("bar-widget"), "kinds must include bar-widget");
  assert(manifest.kinds.includes("service"), "kinds must include service");
  assert.strictEqual(manifest.entryPoints.barWidget, "BarWidget.qml", "barWidget entryPoint must be BarWidget.qml");
  assert.strictEqual(manifest.entryPoints.service, "Service.qml", "service entryPoint must be Service.qml");

  console.log("✓ Manifest contract validated (GPL-3.0-or-later, bar-widget + service)");
}

// 2. QML Files Structure & Balanced Syntax Check
const qmlFiles = [
  "BarWidget.qml",
  "Panel.qml",
  "Service.qml",
  "ui/Button.qml",
  "ui/IconButton.qml",
  "ui/Toggle.qml",
  "ui/TextField.qml",
  "ui/StatusBadge.qml",
  "ui/Header.qml",
  "ui/HeroCard.qml",
  "ui/Navigation.qml",
  "ui/ServersView.qml",
  "ui/SubscriptionsView.qml",
  "ui/FreePoolView.qml",
  "ui/AppsView.qml",
  "ui/ProfilesView.qml",
  "ui/RulesView.qml",
  "ui/CustomConfigView.qml",
  "ui/SettingsView.qml",
  "ui/DiagnosticsView.qml"
];

function checkBalancedBrackets(text, filename) {
  const stack = [];
  let inString = false;
  let stringChar = '';
  let inLineComment = false;
  let inBlockComment = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const next = text[i + 1];

    if (inLineComment) {
      if (ch === '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (ch === '*' && next === '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inString) {
      if (ch === '\\') {
        i++; // skip escaped char
      } else if (ch === stringChar) {
        inString = false;
      }
      continue;
    }

    if (ch === '/' && next === '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (ch === '/' && next === '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (ch === '"' || ch === "'") {
      inString = true;
      stringChar = ch;
      continue;
    }

    if (ch === '{' || ch === '(' || ch === '[') {
      stack.push({ char: ch, line: (text.slice(0, i).match(/\n/g) || []).length + 1 });
    } else if (ch === '}' || ch === ')' || ch === ']') {
      const match = stack.pop();
      assert(match, `${filename}: unexpected closing ${ch} at line ${(text.slice(0, i).match(/\n/g) || []).length + 1}`);
      const pairs = { '}': '{', ')': '(', ']': '[' };
      assert.strictEqual(match.char, pairs[ch], `${filename}: mismatched ${match.char} and ${ch} at line ${match.line}`);
    }
  }
  assert.strictEqual(stack.length, 0, `${filename}: unclosed ${stack.map(s => s.char + " at line " + s.line).join(", ")}`);
}

for (const file of qmlFiles) {
  const fullPath = path.join(rootDir, file);
  assert(fs.existsSync(fullPath), `Required file ${file} must exist`);
  const content = fs.readFileSync(fullPath, "utf8");
  assert(content.length > 50, `${file} must have substantive content`);
  checkBalancedBrackets(content, file);
}
console.log(`✓ All ${qmlFiles.length} QML files exist and passed syntax bracket validation`);

// 3. Secrets Safety Verification
{
  const subView = fs.readFileSync(path.join(rootDir, "ui/SubscriptionsView.qml"), "utf8");
  assert(subView.includes("isPassword: true"), "Subscription URL field must have isPassword: true");
  assert(subView.includes("subUrlInput.clear()"), "Subscription URL field must be cleared after send");

  const serviceQml = fs.readFileSync(path.join(rootDir, "Service.qml"), "utf8");
  assert(serviceQml.includes("bin/vpnrouter-headless"), "Service must reference bin/vpnrouter-headless");
  assert(!serviceQml.includes("sudo"), "Service must never invoke sudo");

  console.log("✓ Secrets safety and password mode verification passed");
}

// 4. QML Architecture & API Invariants Verification
{
  // Header duplicate signal fix
  const headerQml = fs.readFileSync(path.join(rootDir, "ui/Header.qml"), "utf8");
  assert(!headerQml.includes("signal modeChanged"), "Header.qml must NOT declare duplicate signal modeChanged for property mode");
  assert(headerQml.includes("signal modeChangeRequested"), "Header.qml must declare signal modeChangeRequested");

  // Panel uses modeChangeRequested
  const panelQml = fs.readFileSync(path.join(rootDir, "Panel.qml"), "utf8");
  assert(panelQml.includes("onModeChangeRequested"), "Panel.qml must handle onModeChangeRequested");
  assert(panelQml.includes("focusTarget: keyCatcher"), "Panel.qml must set KeyboardPanel focusTarget to keyCatcher");
  assert(panelQml.includes("PanelKeyCatcher"), "Panel.qml must wrap content with PanelKeyCatcher");

  // Service safe connect defaults before handshake
  const serviceQml = fs.readFileSync(path.join(rootDir, "Service.qml"), "utf8");
  assert(/capabilities:\s*\(\{\s*connect:\s*false/.test(serviceQml), "Service.qml must default capabilities.connect to false before handshake");
  assert(serviceQml.includes("Connect capability unavailable before handshake"), "Service.qml connect() must fail closed before handshake");

  // BarWidget lifecycle: no fallback Service, only injected or host service
  const barWidgetQml = fs.readFileSync(path.join(rootDir, "BarWidget.qml"), "utf8");
  assert(!barWidgetQml.includes("fallbackServiceLoader"), "BarWidget.qml must NOT instantiate fallback Service; only injected or host service");
  assert(!/^\s*Service\s*\{/m.test(barWidgetQml), "BarWidget.qml must NOT instantiate child Service");
  assert(barWidgetQml.includes("effectiveService"), "BarWidget.qml must declare effectiveService");

  // I18n reactivity across UI views
  const viewsWithI18n = [
    "ui/Header.qml", "ui/HeroCard.qml", "ui/StatusBadge.qml", "ui/Navigation.qml",
    "ui/ServersView.qml", "ui/SubscriptionsView.qml", "ui/FreePoolView.qml",
    "ui/AppsView.qml", "ui/ProfilesView.qml", "ui/RulesView.qml",
    "ui/CustomConfigView.qml", "ui/SettingsView.qml", "ui/DiagnosticsView.qml"
  ];
  for (const v of viewsWithI18n) {
    const content = fs.readFileSync(path.join(rootDir, v), "utf8");
    assert(content.includes("i18nRevision"), `${v} must declare i18nRevision property for translation reactivity`);
    assert(content.includes("function tr(") || content.includes("root.tr("), `${v} must provide reactive translation helper`);
  }

  console.log("✓ QML Architecture, signal safety, and I18n reactivity invariants verified");
}

console.log("ALL CONTRACT TESTS PASSED!\n");
