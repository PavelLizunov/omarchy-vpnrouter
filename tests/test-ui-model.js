const assert = require("assert");
const fs = require("fs");
const path = require("path");

// Load Model.js with .pragma library stripped
const modelPath = path.join(__dirname, "../lib/Model.js");
const modelSrc = fs.readFileSync(modelPath, "utf8").replace(/^\.pragma library\s*/m, "");

const context = { module: { exports: {} } };
const fn = new Function("module", "exports", modelSrc);
fn(context.module, context.module.exports);
const Model = context.module.exports;

console.log("=== Testing Model.js ===");

// 1. Latency formatting & tiers
{
  assert.strictEqual(Model.formatLatency(null), "—");
  assert.strictEqual(Model.formatLatency(undefined), "—");
  assert.strictEqual(Model.formatLatency(-5), "—");
  assert.strictEqual(Model.formatLatency(42.3), "42 ms");
  assert.strictEqual(Model.formatLatency(150), "150 ms");

  assert.strictEqual(Model.latencyTier(null), "unknown");
  assert.strictEqual(Model.latencyTier(50), "good");
  assert.strictEqual(Model.latencyTier(180), "medium");
  assert.strictEqual(Model.latencyTier(300), "poor");
  console.log("✓ Latency helpers passed");
}

// 2. Protocols and Glyphs
{
  assert.strictEqual(Model.protocolDisplay("vless"), "VLESS");
  assert.strictEqual(Model.protocolDisplay("vmess"), "VMess");
  assert.strictEqual(Model.protocolDisplay("wg"), "WireGuard");
  assert.strictEqual(Model.protocolDisplay("ss"), "Shadowsocks");
  assert.strictEqual(Model.protocolDisplay("hysteria2"), "Hysteria 2");

  assert.strictEqual(Model.stateGlyph("connected"), "󰖂");
  assert.strictEqual(Model.stateGlyph("connecting"), "󰦞");
  assert.strictEqual(Model.stateGlyph("disconnecting"), "󱚤");
  assert.strictEqual(Model.stateGlyph("error"), "󰅚");
  assert.strictEqual(Model.stateGlyph("unavailable"), "󰀦");
  console.log("✓ Protocol and glyph helpers passed");
}

// 3. Server Filtering and Sorting
{
  const servers = [
    { id: "s1", name: "Frankfurt VLESS", protocol: "vless", latencyMs: 80, selected: false },
    { id: "s2", name: "Amsterdam WG", protocol: "wireguard", latencyMs: 40, selected: true },
    { id: "s3", name: "Tokyo Shadowsocks", protocol: "ss", latencyMs: 220, selected: false }
  ];

  const filtered = Model.filterServers(servers, "frank");
  assert.strictEqual(filtered.length, 1);
  assert.strictEqual(filtered[0].id, "s1");

  const sortedByLatency = Model.sortServers(servers, "latency");
  assert.strictEqual(sortedByLatency[0].id, "s2"); // 40ms
  assert.strictEqual(sortedByLatency[1].id, "s1"); // 80ms
  assert.strictEqual(sortedByLatency[2].id, "s3"); // 220ms

  const defaultSort = Model.sortServers(servers);
  assert.strictEqual(defaultSort[0].id, "s2"); // Selected first
  console.log("✓ Server filter and sort passed");
}

// 4. MTU and CIDR Validation
{
  assert.strictEqual(Model.validateMtu(1420), 1420);
  assert.strictEqual(Model.validateMtu(500), 576); // Min clamped
  assert.strictEqual(Model.validateMtu(10000), 9000); // Max clamped
  assert.strictEqual(Model.validateMtu("invalid"), 1420);

  assert.strictEqual(Model.validateCidr("192.168.1.0/24"), true);
  assert.strictEqual(Model.validateCidr("10.0.0.0/8"), true);
  assert.strictEqual(Model.validateCidr("172.16.0.0/12"), true);
  assert.strictEqual(Model.validateCidr("not-a-cidr"), false);
  assert.strictEqual(Model.validateCidr("999.999.999.999/24"), false);
  assert.strictEqual(Model.validateCidr("192.168.1.0/35"), false);

  const rawList = ["192.168.1.0/24", "invalid", " 10.0.0.0/8 "];
  const cleaned = Model.cleanCidrList(rawList);
  assert.deepStrictEqual(cleaned, ["192.168.1.0/24", "10.0.0.0/8"]);
  console.log("✓ MTU and CIDR validation passed");
}

// 5. Snapshot Normalization and ConfigMode Mapping
{
  const norm = Model.normalizeSnapshot({
    state: "connected",
    revision: "rev-123",
    activeServer: "Node-1",
    capabilities: { connect: true, killSwitch: true },
    configMode: 1
  });
  assert.strictEqual(norm.state, "connected");
  assert.strictEqual(norm.revision, "rev-123");
  assert.strictEqual(norm.activeServer, "Node-1");
  assert.strictEqual(norm.routingMode, "split");
  assert.strictEqual(norm.configMode, "subscribe"); // enum 1 -> subscribe
  assert.strictEqual(norm.capabilities.killSwitch, true);
  assert.strictEqual(norm.capabilities.dnsLockdown, false);

  // Test all enum and string mappings for configMode
  assert.strictEqual(Model.mapConfigMode(0), "generated");
  assert.strictEqual(Model.mapConfigMode(1), "subscribe");
  assert.strictEqual(Model.mapConfigMode(2), "custom");
  assert.strictEqual(Model.mapConfigMode("0"), "generated");
  assert.strictEqual(Model.mapConfigMode("1"), "subscribe");
  assert.strictEqual(Model.mapConfigMode("2"), "custom");
  assert.strictEqual(Model.mapConfigMode("generated"), "generated");
  assert.strictEqual(Model.mapConfigMode("subscribe"), "subscribe");
  assert.strictEqual(Model.mapConfigMode("custom"), "custom");
  assert.strictEqual(Model.mapConfigMode("manual"), "generated");
  assert.strictEqual(Model.mapConfigMode("vless"), "generated");
  assert.strictEqual(Model.mapConfigMode("subscriptions"), "subscribe");
  assert.strictEqual(Model.mapConfigMode("SUBSCRIBE"), "subscribe");
  assert.strictEqual(Model.mapConfigMode(null), "generated");
  assert.strictEqual(Model.mapConfigMode(undefined), "generated");
  assert.strictEqual(Model.mapConfigMode("unknown_mode"), "generated");

  const fallback = Model.normalizeSnapshot(null);
  assert.strictEqual(fallback.state, "unavailable");
  assert.strictEqual(fallback.routingMode, "split");
  assert.strictEqual(fallback.configMode, "generated");
  console.log("✓ Snapshot normalization and configMode enum/string mapping passed");
}

console.log("ALL MODEL TESTS PASSED!\n");
