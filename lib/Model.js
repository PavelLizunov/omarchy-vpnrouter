.pragma library

/**
 * Model.js - Pure business logic, conversions, state helpers and validators
 * for VPNRouter on Omarchy Quattro.
 */

var PROTOCOLS = ["vless", "vmess", "shadowsocks", "wireguard", "trojan", "hysteria2", "tuic"];

function formatLatency(ms) {
  if (ms === null || ms === undefined || !isFinite(ms) || ms < 0) return "—";
  return Math.round(ms) + " ms";
}

function latencyTier(ms) {
  if (ms === null || ms === undefined || !isFinite(ms) || ms < 0) return "unknown";
  if (ms < 100) return "good";
  if (ms < 250) return "medium";
  return "poor";
}

function stateLabel(st, i18n) {
  var key = "state." + (st || "unavailable");
  return i18n ? i18n.t(key) : st;
}

function stateGlyph(st) {
  switch (st) {
    case "connected":
      return "󰖂";
    case "connecting":
      return "󰦞";
    case "disconnecting":
      return "󱚤";
    case "error":
      return "󰅚";
    case "unavailable":
      return "󰀦";
    case "disconnected":
    default:
      return "󰖂";
  }
}

function protocolDisplay(proto) {
  if (!proto) return "Unknown";
  var p = String(proto).toLowerCase();
  switch (p) {
    case "vless": return "VLESS";
    case "vmess": return "VMess";
    case "shadowsocks": case "ss": return "Shadowsocks";
    case "wireguard": case "wg": return "WireGuard";
    case "trojan": return "Trojan";
    case "hysteria2": case "hy2": return "Hysteria 2";
    case "tuic": return "TUIC";
    default: return proto.toUpperCase();
  }
}

function filterServers(items, query) {
  if (!items || !Array.isArray(items)) return [];
  if (!query || typeof query !== "string" || query.trim().length === 0) return items;
  var q = query.trim().toLowerCase();
  return items.filter(function(s) {
    if (!s) return false;
    var name = (s.name || "").toLowerCase();
    var proto = (s.protocol || "").toLowerCase();
    return name.indexOf(q) !== -1 || proto.indexOf(q) !== -1;
  });
}

function sortServers(items, sortBy) {
  if (!items || !Array.isArray(items)) return [];
  var copy = items.slice();
  copy.sort(function(a, b) {
    if (sortBy === "latency") {
      var latA = (a.latencyMs !== null && a.latencyMs !== undefined) ? a.latencyMs : 999999;
      var latB = (b.latencyMs !== null && b.latencyMs !== undefined) ? b.latencyMs : 999999;
      return latA - latB;
    }
    if (sortBy === "name") {
      return String(a.name || "").localeCompare(String(b.name || ""));
    }
    // Default: selected first, then name
    if (a.selected && !b.selected) return -1;
    if (!a.selected && b.selected) return 1;
    return String(a.name || "").localeCompare(String(b.name || ""));
  });
  return copy;
}

function filterApps(names, query) {
  if (!names || !Array.isArray(names)) return [];
  if (!query || typeof query !== "string" || query.trim().length === 0) return names;
  var q = query.trim().toLowerCase();
  return names.filter(function(name) {
    return String(name || "").toLowerCase().indexOf(q) !== -1;
  });
}

function validateMtu(value) {
  var num = parseInt(value, 10);
  if (!isFinite(num)) return 1420;
  if (num < 576) return 576;
  if (num > 9000) return 9000;
  return num;
}

function validateCidr(cidr) {
  if (!cidr || typeof cidr !== "string") return false;
  var parts = cidr.trim().split("/");
  if (parts.length !== 2) return false;
  var ipParts = parts[0].split(".");
  if (ipParts.length !== 4) return false;
  for (var i = 0; i < 4; i++) {
    var n = parseInt(ipParts[i], 10);
    if (!isFinite(n) || n < 0 || n > 255) return false;
  }
  var mask = parseInt(parts[1], 10);
  if (!isFinite(mask) || mask < 0 || mask > 32) return false;
  return true;
}

function cleanCidrList(raw) {
  if (Array.isArray(raw)) {
    return raw.map(function(s) { return String(s || "").trim(); }).filter(validateCidr);
  }
  if (typeof raw === "string") {
    return raw.split(/[\n,]+/).map(function(s) { return s.trim(); }).filter(validateCidr);
  }
  return [];
}

function formatCidrList(list) {
  if (!list || !Array.isArray(list)) return "";
  return list.join("\n");
}

function mapConfigMode(mode) {
  if (mode === undefined || mode === null) return "generated";
  if (typeof mode === "number") {
    switch (mode) {
      case 0: return "generated";
      case 1: return "subscribe";
      case 2: return "custom";
      default: return "generated";
    }
  }
  var str = String(mode).trim().toLowerCase();
  switch (str) {
    case "0":
    case "generated":
    case "manual":
    case "vless":
      return "generated";
    case "1":
    case "subscribe":
    case "subscriptions":
    case "subscription":
      return "subscribe";
    case "2":
    case "custom":
      return "custom";
    default:
      return "generated";
  }
}

function normalizeSnapshot(data) {
  var d = data || {};
  return {
    state: String(d.state || "unavailable"),
    revision: String(d.revision || ""),
    backendVersion: String(d.backendVersion || ""),
    activeServer: String(d.activeServer || ""),
    routingMode: String(d.routingMode || "split"),
    routingAppsMode: String(d.routingAppsMode || "include"),
    configMode: mapConfigMode(d.configMode),
    busy: d.busy === true,
    errorCode: d.errorCode ? String(d.errorCode) : null,
    capabilities: {
      connect: !!(d.capabilities && d.capabilities.connect === true),
      killSwitch: !!(d.capabilities && d.capabilities.killSwitch === true),
      dnsLockdown: !!(d.capabilities && d.capabilities.dnsLockdown === true)
    }
  };
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PROTOCOLS: PROTOCOLS,
    formatLatency: formatLatency,
    latencyTier: latencyTier,
    stateLabel: stateLabel,
    stateGlyph: stateGlyph,
    protocolDisplay: protocolDisplay,
    filterServers: filterServers,
    sortServers: sortServers,
    filterApps: filterApps,
    validateMtu: validateMtu,
    validateCidr: validateCidr,
    cleanCidrList: cleanCidrList,
    formatCidrList: formatCidrList,
    mapConfigMode: mapConfigMode,
    normalizeSnapshot: normalizeSnapshot
  };
}
