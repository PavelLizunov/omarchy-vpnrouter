.pragma library

/**
 * Model.js - Pure business logic, conversions, state helpers and validators
 * for VPNRouter on Omarchy Quattro.
 */

var PROTOCOLS = ["vless", "vmess", "shadowsocks", "wireguard", "trojan", "hysteria2", "tuic"];

function formatLatency(ms, i18n) {
  if (typeof ms !== "number" || !isFinite(ms) || ms < 0) return "—";
  return i18n ? i18n.t("latency.ms", [Math.round(ms)]) : Math.round(ms) + "\u00a0ms";
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
      return "󰌙";
    case "error":
      return "󰅚";
    case "unavailable":
      return "󰀦";
    case "disconnected":
    default:
      return "󰖂";
  }
}

function protocolDisplay(proto, i18n) {
  if (!proto) return i18n ? i18n.t("protocol.unknown") : "Unknown";
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

// Match the installed Hyprland toplevel contract without process enumeration.
function appHasWindow(app, toplevels) {
  var name = app.name.toLowerCase();
  for (var i = 0; i < toplevels.length; i++) {
    var window = toplevels[i];
    if (!window) continue;
    var ipc = window.lastIpcObject || {};
    var pid = Number(ipc.pid);
    // The current backend has no pid; accept it if a newer peer supplies one.
    if (pid > 0 && (Number(app.pid) === pid || (Array.isArray(app.pids) && app.pids.indexOf(pid) !== -1))) return true;
    var classes = [ipc["class"], ipc.initialClass, window.wayland ? window.wayland.appId : ""];
    for (var j = 0; j < classes.length; j++) {
      if (typeof classes[j] === "string" && classes[j].toLowerCase() === name) return true;
    }
  }
  return false;
}

// Legacy process lists have no desktop/UID provenance; do not suggest them.
function runningApplications(data, query, toplevels) {
  if (!data || !Array.isArray(data.runningApps)) return [];
  var seen = Object.create(null);
  var q = String(query || "").trim().toLowerCase();
  return data.runningApps.slice(0, 200).filter(function(app) {
    if (!app || typeof app.name !== "string" || !app.name || app.name.length > 256 || /[\/\\\x00-\x1f]/.test(app.name)) return false;
    if (/^(systemd.*|dbus.*|pipewire.*|wireplumber|sshd?|cron[d]?|.*-daemon|.*\.service|kworker.*)$/i.test(app.name)) return false;
    if (seen[app.name]) return false;
    seen[app.name] = true;
    return !q || (app.name + " " + (app.displayName || "")).toLowerCase().indexOf(q) !== -1;
  }).map(function(app) {
    return {
      name: app.name,
      displayName: typeof app.displayName === "string" ? app.displayName.slice(0, 256) : app.name,
      // Only freedesktop icon names, never URLs or file paths from the peer.
      icon: typeof app.icon === "string" && /^[A-Za-z0-9_.-]{1,128}$/.test(app.icon) ? app.icon : "application-x-executable",
      desktopId: typeof app.desktopId === "string" ? app.desktopId : null,
      hasWindow: toplevels ? appHasWindow(app, toplevels) : app.hasWindow === true
    };
  }).sort(function(a, b) {
    var guiA = a.hasWindow || !!a.desktopId, guiB = b.hasWindow || !!b.desktopId;
    return guiA !== guiB ? (guiA ? -1 : 1) : a.displayName.localeCompare(b.displayName);
  });
}

function serverSourceKey(server) {
  return server.source === "manual" ? "manual" : server.source === "subscription" ? "subscription:" + (server.subscriptionId || "") : "unknown";
}

function groupedServers(servers, query) {
  return filterServers(servers, query).slice().sort(function(a, b) {
    var ak = serverSourceKey(a), bk = serverSourceKey(b);
    return ak === bk ? String(a.name || "").localeCompare(String(b.name || "")) : ak.localeCompare(bk);
  });
}

function serverSourceLabel(server, subscriptions, i18n) {
  if (server.source === "manual") return i18n.t("servers.sourceManual");
  if (server.source === "subscription") {
    for (var i = 0; i < subscriptions.length; i++) {
      if (subscriptions[i].id === server.subscriptionId) return subscriptions[i].name || i18n.t("subscriptions.fallbackName");
    }
    return i18n.t("subscriptions.fallbackName");
  }
  return i18n.t("servers.sourceUnknown");
}

function backendStarting(service) {
  if (!service) return false;
  var loaded = typeof service.snapshotLoaded === "boolean" ? service.snapshotLoaded : !!service.revision;
  return service.state === "unavailable" && !service.backendMissing &&
    (service.starting === true || (service.helperPresent === true && !loaded && !service.lastError));
}

function unavailableText(service, i18n) {
  var code = service ? service.unavailableReasonCode : null;
  if (["runtime-missing", "runtime-capabilities", "runtime-untrusted", "sandbox", "ownership", "other"].indexOf(code) !== -1)
    return i18n.t("backend.reason." + code);
  return service && service.unavailableReason ? service.unavailableReason : i18n.t("backend.connectUnavailable");
}

function diagnosticIsUnconfigured(item) {
  var message = typeof item.message === "string" ? item.message : "";
  var status = String(item.status || item.severity || "").toLowerCase();
  if (message === "Not configured yet: add a subscription or a server") return status === "info" || status === "warn" || status === "warning";
  // Exact legacy first-launch notices only; preserve all other warnings/errors.
  return (status === "warn" || status === "warning") && /^(config\.yaml missing at .+|directory missing: .+) \(will be created on first launch\)$/.test(message);
}

function diagnosticSeverity(item) {
  if (diagnosticIsUnconfigured(item)) return "info";
  var status = String(item.status || item.severity || "").toLowerCase();
  if (status === "pass" || status === "ok") return "pass";
  if (status === "fail" || status === "error") return "fail";
  if (status === "info") return "info";
  if (status === "warn" || status === "warning") return "warn";
  return "unknown";
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

function nonnegativeNumber(value) {
  return typeof value === "number" && isFinite(value) && value >= 0 ? value : null;
}

function normalizeTelemetry(value) {
  if (!value || typeof value !== "object" || nonnegativeNumber(value.connectedSinceUnixMs) === null) return null;
  return { connectedSinceUnixMs: value.connectedSinceUnixMs,
    downloadBytes: nonnegativeNumber(value.downloadBytes), uploadBytes: nonnegativeNumber(value.uploadBytes) };
}

function connectionElapsed(telemetry, now) {
  if (!telemetry) return "";
  var seconds = Math.max(0, Math.floor((now - telemetry.connectedSinceUnixMs) / 1000));
  var hours = Math.floor(seconds / 3600);
  var minutes = Math.floor(seconds / 60) % 60;
  return (hours ? hours + ":" + (minutes < 10 ? "0" : "") : "") + minutes + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60;
}

function trafficMiB(bytes) {
  return nonnegativeNumber(bytes) === null ? "—" : (bytes / 1048576).toFixed(1);
}

function normalizeSnapshot(data) {
  var d = data || {};
  return {
    state: String(d.state || "unavailable"),
    revision: String(d.revision || ""),
    backendVersion: String(d.backendVersion || ""),
    activeServer: String(d.activeServer || ""),
    telemetry: d.state === "connected" ? normalizeTelemetry(d.telemetry) : null,
    routingMode: String(d.routingMode || "split"),
    routingAppsMode: String(d.routingAppsMode || "include"),
    configMode: mapConfigMode(d.configMode),
    busy: d.busy === true,
    errorCode: d.errorCode ? String(d.errorCode) : null,
    unavailableReasonCode: typeof d.unavailableReasonCode === "string" ? d.unavailableReasonCode : null,
    unavailableReason: typeof d.unavailableReason === "string" ? d.unavailableReason : "",
    capabilities: {
      connect: !!(d.capabilities && d.capabilities.connect === true),
      killSwitch: !!(d.capabilities && d.capabilities.killSwitch === true),
      dnsLockdown: !!(d.capabilities && d.capabilities.dnsLockdown === true)
    }
  };
}

// The active queue item owns the resource ID; progress events need not carry it.
function probeOperation(service, scope, id) {
  if (!service || [scope + ".test", scope + ".verify"].indexOf(service.activeOperation) === -1) return "";
  var active = service._requestQueue ? service._requestQueue.getActive() : null;
  if (!active || active.method !== service.activeOperation || !active.params || active.params.id !== id) return "";
  return service.activeOperation === scope + ".test" ? "test" : "verify";
}

function verificationText(result, items, i18n) {
  if (!result) return "";
  var name = result.id || i18n.t("servers.fallbackName");
  for (var i = 0; i < items.length; i++) {
    if (items[i].id === result.id) { name = items[i].name || name; break; }
  }
  if (result.ok === true) {
    return i18n.t("verify.passed", [name, formatLatency(result.latencyMs, i18n)]);
  }
  var detail = result.errorKey ? i18n.t(result.errorKey) : result.error || result.status || i18n.t("state.unavailable");
  var detailKey = ({
    unavailable: "backend.connectUnavailable", UnsupportedByVerifier: "verify.unsupported",
    Precondition: "verify.precondition", LocalSpawn: "backend.connectUnavailable",
    SocksBind: "verify.socks", ProxiedHttp: "verify.http",
    Timeout: "error.timeout", Cancelled: "error.cancelled", failed: "error.generic",
    timeout: "error.timeout", unreachable: "state.unavailable", untested: "state.unavailable",
    tlsfailed: "verify.http", implausible: "verify.precondition"
  })[detail];
  if (detailKey) detail = i18n.t(detailKey);
  return i18n.t("verify.failed", [name, detail]);
}

function testText(result, items, i18n) {
  if (!result) return "";
  var name = result.id || i18n.t("servers.fallbackName");
  for (var i = 0; i < items.length; i++) {
    if (items[i].id === result.id) { name = items[i].name || name; break; }
  }
  if (result.errorCode) return i18n.t(result.errorCode === "timeout" ? "test.timeout" : "test.failed", [name]);
  if (typeof result.latencyMs === "number" && isFinite(result.latencyMs) && result.latencyMs >= 0)
    return i18n.t("test.measured", [name, formatLatency(result.latencyMs, i18n)]);
  if (result.reachable === true) return i18n.t("test.reachable", [name]);
  return i18n.t("test.unmeasured", [name]);
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    runningApplications: runningApplications,
    groupedServers: groupedServers,
    serverSourceKey: serverSourceKey,
    serverSourceLabel: serverSourceLabel,
    backendStarting: backendStarting,
    unavailableText: unavailableText,
    diagnosticSeverity: diagnosticSeverity,
    diagnosticIsUnconfigured: diagnosticIsUnconfigured,
    probeOperation: probeOperation,
    verificationText: verificationText,
    testText: testText,
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
    normalizeTelemetry: normalizeTelemetry,
    connectionElapsed: connectionElapsed,
    trafficMiB: trafficMiB,
    normalizeSnapshot: normalizeSnapshot
  };
}
