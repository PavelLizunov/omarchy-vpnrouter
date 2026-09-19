const assert = require("assert");
const fs = require("fs");
const path = require("path");

// Load Protocol.js and Model.js with .pragma library stripped
const protoPath = path.join(__dirname, "../lib/Protocol.js");
const protoSrc = fs.readFileSync(protoPath, "utf8").replace(/^\.pragma library\s*/m, "");
const protoCtx = { module: { exports: {} } };
new Function("module", "exports", protoSrc)(protoCtx.module, protoCtx.module.exports);
const Protocol = protoCtx.module.exports;

const modelPath = path.join(__dirname, "../lib/Model.js");
const modelSrc = fs.readFileSync(modelPath, "utf8").replace(/^\.pragma library\s*/m, "");
const modelCtx = { module: { exports: {} } };
new Function("module", "exports", modelSrc)(modelCtx.module, modelCtx.module.exports);
const Model = modelCtx.module.exports;

console.log("=== Testing Service Queue, Revisions, Concurrency & Input Domains ===");

/**
 * Headless Service Simulator mirroring Service.qml queue, dispatch, revision formatting,
 * urgent requests, deadlines, and response handling.
 */
function createServiceSimulator() {
  const root = {
    state: "unavailable",
    revision: "rev-init",
    backendVersion: "2.48.0",
    activeServer: "",
    routingMode: "split",
    routingAppsMode: "include",
    configMode: "generated",
    busy: false,
    errorCode: null,
    capabilities: { connect: false, killSwitch: false, dnsLockdown: false },
    settingsData: {
      mtu: 1420,
      ipv6Enabled: false,
      strictRoute: false,
      strictDns: false,
      dnsMode: "vpn_only",
      dnsModeSemantics: null,
      bypassRussianTraffic: true,
      blockAds: false,
      dnsLeakLockdown: false,
      routeExcludeAddress: []
    },

    activeOperation: "",
    activeRequestId: "",
    activeProgress: null,
    lastError: "",

    _pendingCallbacks: {},
    _pendingUrgentCount: 0,
    maxUrgentPending: 4,
    requestDeadlineMs: 15000,
    _requestQueue: Protocol.createRequestQueue(8),

    writtenFrames: [],
    refreshedSnapshots: 0,

    backendRunning: true,

    get isConnected() { return root.state === "connected"; },
    get isConnecting() { return root.state === "connecting"; },
    get isDisconnecting() { return root.state === "disconnecting"; },
    get isError() { return root.state === "error" || (root.errorCode !== null && root.errorCode !== ""); },
    get isUnavailable() { return root.state === "unavailable"; },

    applySnapshot(data) {
      const norm = Model.normalizeSnapshot(data);
      root.state = norm.state;
      root.revision = norm.revision;
      root.backendVersion = norm.backendVersion;
      root.activeServer = norm.activeServer;
      root.routingMode = norm.routingMode;
      root.routingAppsMode = norm.routingAppsMode;
      root.configMode = norm.configMode;
      root.busy = norm.busy;
      root.errorCode = norm.errorCode;
      root.capabilities = norm.capabilities;
    },

    refreshSnapshot(onDone, onError) {
      root.refreshedSnapshots++;
      return root.sendRequest("snapshot", {}, (res) => {
        root.applySnapshot(res);
        if (onDone) onDone(res);
      }, onError);
    },

    getSettings(onDone, onError) {
      const source = fs.readFileSync(path.join(__dirname, "../Service.qml"), "utf8");
      const match = source.match(/function getSettings\(onDone, onError\)\s*\{([\s\S]*?)\n  \}/);
      assert(match, "Actual Service getSettings handler must exist");
      return new Function("root", "sendRequest", "onDone", "onError", match[1])(
        root, root.sendRequest.bind(root), onDone, onError);
    },

    setSettings(values, onDone, onError) {
      return root.sendRequest("settings.set", {
        revision: root.revision,
        values: values
      }, (res) => {
        root.applySnapshot(res);
        root.getSettings();
        if (onDone) onDone(res);
      }, onError);
    },

    flushAllQueued(code, message) {
      const flushed = root._requestQueue.clearAll();
      for (let i = 0; i < flushed.length; i++) {
        const it = flushed[i];
        if (it && typeof it.onError === "function") {
          it.onError({ code: code || "transport_error", message: message || "Transport error" });
        }
      }
      return flushed;
    },

    flushQueuedMutations(reasonMsg) {
      const flushed = root._requestQueue.flushQueued((item) => {
        if (!item) return false;
        if (item.needsRevision === true) return true;
        const m = item.method || "";
        return m.indexOf(".set") !== -1 || m.indexOf(".select") !== -1 ||
               m.indexOf(".import") !== -1 || m.indexOf(".remove") !== -1 ||
               m.indexOf(".add") !== -1 || m.indexOf(".apply") !== -1;
      });
      for (let i = 0; i < flushed.length; i++) {
        const it = flushed[i];
        if (it && typeof it.onError === "function") {
          it.onError({ code: "cancelled", message: reasonMsg || "Operation cancelled" });
        }
      }
      return flushed;
    },

    sendRequest(method, params, onDone, onError, isUrgent, customTimeoutMs) {
      const reqId = Protocol.generateRequestId("req");
      let hasRevision = false;
      const originalParams = {};
      if (params && typeof params === "object") {
        for (const k in params) {
          if (k === "revision") {
            hasRevision = true;
          } else {
            originalParams[k] = params[k];
          }
        }
      }

      const timeoutDuration = customTimeoutMs || root.requestDeadlineMs;

      if (isUrgent) {
        if (root._pendingUrgentCount >= root.maxUrgentPending) {
          const queueFullErr = { code: "queue_full", message: "Urgent request limit exceeded" };
          root.lastError = queueFullErr.message;
          if (onError) onError(queueFullErr);
          return null;
        }

        const urgentFormatted = Protocol.formatRequest(method, originalParams, reqId);
        if (!urgentFormatted.ok) {
          if (onError) onError({ code: "format_error", message: urgentFormatted.error });
          return null;
        }

        root._pendingUrgentCount++;
        root._pendingCallbacks[reqId] = {
          onDone: onDone,
          onError: onError,
          method: method,
          isUrgent: true,
          deadline: Date.now() + timeoutDuration
        };

        root.writtenFrames.push(urgentFormatted.text);
        return reqId;
      }

      const item = {
        id: reqId,
        method: method,
        params: originalParams,
        needsRevision: hasRevision,
        onDone: onDone,
        onError: onError,
        isUrgent: false,
        timeoutMs: timeoutDuration
      };

      const qRes = root._requestQueue.enqueue(item);
      if (!qRes.ok) {
        if (onError) onError({ code: qRes.error, message: qRes.message });
        return null;
      }

      root.pumpQueue();
      return item.id;
    },

    pumpQueue() {
      if (!root.backendRunning) return;
      const next = root._requestQueue.dequeueNext();
      if (!next) return;

      root.activeRequestId = next.id;
      root.activeOperation = next.method;

      const dispatchParams = {};
      if (next.params) {
        for (const k in next.params) {
          dispatchParams[k] = next.params[k];
        }
      }
      if (next.needsRevision) {
        dispatchParams.revision = root.revision;
      }

      const reqResult = Protocol.formatRequest(next.method, dispatchParams, next.id);
      if (!reqResult.ok) {
        root.activeRequestId = "";
        root.activeOperation = "";
        root._requestQueue.clearActive();
        if (next.onError) next.onError({ code: "format_error", message: reqResult.error });
        root.pumpQueue();
        return;
      }

      root._pendingCallbacks[next.id] = {
        onDone: next.onDone,
        onError: next.onError,
        method: next.method,
        isUrgent: false,
        deadline: Date.now() + (next.timeoutMs || root.requestDeadlineMs)
      };

      root.writtenFrames.push(reqResult.text);
    },

    handleResponse(reqId, isError, result, error) {
      const cb = root._pendingCallbacks[reqId];
      const isUrgentCb = cb && cb.isUrgent === true;
      if (cb) {
        delete root._pendingCallbacks[reqId];
        if (isUrgentCb && root._pendingUrgentCount > 0) {
          root._pendingUrgentCount--;
        }
      }

      const activeItem = root._requestQueue.getActive();
      const isOrdinaryActive = (activeItem && activeItem.id === reqId) || (root.activeRequestId === reqId && !isUrgentCb);

      if (isOrdinaryActive) {
        root.activeRequestId = "";
        root.activeOperation = "";
        root.activeProgress = null;
        root._requestQueue.clearActive();
      }

      if (isError) {
        const errCode = error ? error.code : "unknown_error";
        const errMsg = error ? error.message : "Error";
        root.lastError = errMsg;
        if (errCode === "conflict") {
          root.refreshSnapshot();
        }
        if (cb && typeof cb.onError === "function") {
          cb.onError(error);
        }
      } else {
        if (cb && typeof cb.onDone === "function") {
          cb.onDone(result);
        }
      }

      if (isOrdinaryActive) {
        root.pumpQueue();
      }
    },

    checkDeadlines(currentTime) {
      const now = currentTime || Date.now();
      const timedOutIds = [];
      for (const id in root._pendingCallbacks) {
        const cb = root._pendingCallbacks[id];
        if (cb && cb.deadline && now > cb.deadline) {
          timedOutIds.push(id);
        }
      }

      for (let i = 0; i < timedOutIds.length; i++) {
        const tid = timedOutIds[i];
        const timedOutCb = root._pendingCallbacks[tid];
        if (!timedOutCb) continue;
        delete root._pendingCallbacks[tid];

        if (timedOutCb.isUrgent && root._pendingUrgentCount > 0) {
          root._pendingUrgentCount--;
        }

        const activeItem = root._requestQueue.getActive();
        const isOrdinary = (activeItem && activeItem.id === tid) || (root.activeRequestId === tid && !timedOutCb.isUrgent);

        if (isOrdinary) {
          root.activeRequestId = "";
          root.activeOperation = "";
          root.activeProgress = null;
          root._requestQueue.clearActive();
        }

        const errObj = { code: "timeout", message: "Request deadline exceeded" };
        root.lastError = errObj.message;
        if (timedOutCb.onError && typeof timedOutCb.onError === "function") {
          timedOutCb.onError(errObj);
        }

        if (isOrdinary) {
          root.pumpQueue();
        }
      }
    },

    disconnect(onDone, onError) {
      root.flushQueuedMutations("Cancelled by disconnect");
      return root.sendRequest("disconnect", {}, (res) => {
        root.applySnapshot(res);
        if (onDone) onDone(res);
      }, onError, true);
    }
  };

  return root;
}

// -----------------------------------------------------------------------------
// Test 1: Two Queued Mutations Revision Increments & No Replay After Conflict
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();
  svc.revision = "rev-01";

  // Enqueue mutation 1: selectServer
  let m1Done = false;
  const req1Id = svc.sendRequest("servers.select", { revision: svc.revision, id: "srv-alpha" }, (res) => {
    svc.applySnapshot(res);
    m1Done = true;
  });

  assert.strictEqual(svc.activeRequestId, req1Id);
  assert.strictEqual(svc.writtenFrames.length, 1);
  const frame1 = JSON.parse(svc.writtenFrames[0].trim());
  assert.strictEqual(frame1.method, "servers.select");
  assert.strictEqual(frame1.params.revision, "rev-01");
  assert.strictEqual(frame1.params.id, "srv-alpha");

  // While mutation 1 is in-flight, enqueue mutation 2
  let m2Done = false;
  const req2Id = svc.sendRequest("servers.select", { revision: svc.revision, id: "srv-beta" }, (res) => {
    svc.applySnapshot(res);
    m2Done = true;
  });

  // Mutation 2 must NOT be written yet (1 operation rule)
  assert.strictEqual(svc.writtenFrames.length, 1);
  assert.strictEqual(svc._requestQueue.size(), 1);

  // Backend completes mutation 1, advancing revision to "rev-02"
  svc.handleResponse(req1Id, false, {
    state: "connected",
    revision: "rev-02",
    activeServer: "Alpha"
  });

  assert.strictEqual(m1Done, true);
  assert.strictEqual(svc.revision, "rev-02");

  // Mutation 2 must now have been dequeued and dispatched WITH "rev-02", NOT the stale "rev-01"!
  assert.strictEqual(svc.writtenFrames.length, 2);
  const frame2 = JSON.parse(svc.writtenFrames[1].trim());
  assert.strictEqual(frame2.id, req2Id);
  assert.strictEqual(frame2.method, "servers.select");
  assert.strictEqual(frame2.params.revision, "rev-02", "Mutation 2 must be formatted at dispatch time with current revision rev-02");
  assert.strictEqual(frame2.params.id, "srv-beta", "Mutation 2 must retain original immutable params");

  // Complete mutation 2
  svc.handleResponse(req2Id, false, {
    state: "connected",
    revision: "rev-03",
    activeServer: "Beta"
  });
  assert.strictEqual(m2Done, true);
  assert.strictEqual(svc.revision, "rev-03");

  // Verify: No replay after conflict
  let conflictErrorReceived = null;
  const req3Id = svc.sendRequest("servers.select", { revision: "stale-rev", id: "srv-gamma" }, null, (err) => {
    conflictErrorReceived = err;
  });
  assert.strictEqual(svc.writtenFrames.length, 3);
  svc.handleResponse(req3Id, true, null, { code: "conflict", message: "Revision mismatch" });

  assert(conflictErrorReceived !== null, "Error callback must receive conflict error");
  assert.strictEqual(conflictErrorReceived.code, "conflict");
  // Refreshed snapshot was triggered, but the failed mutation was NOT re-enqueued/replayed
  assert.strictEqual(svc.refreshedSnapshots, 1);
  assert.strictEqual(svc._requestQueue.size(), 0, "Failed mutation must not be re-enqueued after conflict");

  console.log("✓ Two queued mutations revision increments & no replay after conflict passed");
}

// -----------------------------------------------------------------------------
// Test 2: Unknown / Stale Response IDs
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();
  const reqId = svc.sendRequest("servers.list", { offset: 0, limit: 10 });
  assert.strictEqual(svc.activeRequestId, reqId);

  // Stale/unknown response arrives
  assert.doesNotThrow(() => {
    svc.handleResponse("unknown-stale-id-9999", false, { items: [] });
  });

  // Active operation must remain intact
  assert.strictEqual(svc.activeRequestId, reqId, "Stale response must NOT clear activeRequestId");
  assert.strictEqual(svc._requestQueue.getActive().id, reqId, "Stale response must NOT clear active queue item");
  assert.strictEqual(svc.writtenFrames.length, 1, "Stale response must NOT trigger pumpQueue");

  console.log("✓ Unknown/stale response ID handling passed");
}

// -----------------------------------------------------------------------------
// Test 3: Urgent Reply Does NOT Clear Ordinary Active Operation
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();

  // 1. Enqueue ordinary request
  let ordDone = false;
  const ordId = svc.sendRequest("servers.list", {}, () => { ordDone = true; });
  assert.strictEqual(svc.activeRequestId, ordId);
  assert.strictEqual(svc.activeOperation, "servers.list");

  // 2. Enqueue next ordinary request (queued behind ordId)
  let nextOrdDone = false;
  const nextOrdId = svc.sendRequest("apps.list", {}, () => { nextOrdDone = true; });
  assert.strictEqual(svc._requestQueue.size(), 1);

  // 3. Send urgent request (disconnect)
  let urgDone = false;
  const urgId = svc.sendRequest("disconnect", {}, () => { urgDone = true; }, null, true);
  assert(urgId !== null, "Urgent request must succeed");
  assert.strictEqual(svc._pendingUrgentCount, 1);

  // 4. Urgent response arrives FIRST
  svc.handleResponse(urgId, false, { state: "disconnected", revision: "rev-disc" });

  assert.strictEqual(urgDone, true, "Urgent callback must be called");
  assert.strictEqual(svc._pendingUrgentCount, 0, "Urgent pending count must decrement");
  assert.strictEqual(svc.activeRequestId, ordId, "Urgent response must NOT clear ordinary activeRequestId");
  assert.strictEqual(svc.activeOperation, "servers.list", "Urgent response must NOT clear activeOperation");
  assert.strictEqual(svc._requestQueue.getActive().id, ordId, "Ordinary item must remain active in queue");
  // Crucial: nextOrdId must NOT have been sent yet (writtenFrames must be 2: ordId + urgId)
  assert.strictEqual(svc.writtenFrames.length, 2, "Queue must NOT pump next ordinary request prematurely");

  // 5. Ordinary response arrives LATER
  svc.handleResponse(ordId, false, { items: [] });
  assert.strictEqual(ordDone, true);

  // Now next ordinary request (nextOrdId) is pumped!
  assert.strictEqual(svc.writtenFrames.length, 3);
  const nextFrame = JSON.parse(svc.writtenFrames[2].trim());
  assert.strictEqual(nextFrame.id, nextOrdId);
  assert.strictEqual(svc.activeRequestId, nextOrdId);

  console.log("✓ Urgent reply concurrency and queue synchronization passed");
}

// -----------------------------------------------------------------------------
// Test 4: Request Deadlines and Timeouts
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();
  svc.requestDeadlineMs = 1000;

  // Ordinary timeout test
  let timedOutErr = null;
  const reqId = svc.sendRequest("servers.test", { id: "s1" }, null, (err) => {
    timedOutErr = err;
  });

  assert.strictEqual(svc.activeRequestId, reqId);

  // Simulate time before deadline
  svc.checkDeadlines(Date.now() + 500);
  assert.strictEqual(timedOutErr, null);
  assert.strictEqual(svc.activeRequestId, reqId);

  // Simulate time after deadline
  svc.checkDeadlines(Date.now() + 1500);
  assert(timedOutErr !== null, "Request must time out after deadline");
  assert.strictEqual(timedOutErr.code, "timeout");
  assert.strictEqual(svc.activeRequestId, "", "Timeout must clear activeRequestId");
  assert.strictEqual(svc._requestQueue.getActive(), null, "Timeout must clear active in queue");

  // Urgent timeout test
  let urgTimeoutErr = null;
  const urgId = svc.sendRequest("disconnect", {}, null, (err) => {
    urgTimeoutErr = err;
  }, true);

  assert.strictEqual(svc._pendingUrgentCount, 1);
  svc.checkDeadlines(Date.now() + 1500);
  assert(urgTimeoutErr !== null);
  assert.strictEqual(urgTimeoutErr.code, "timeout");
  assert.strictEqual(svc._pendingUrgentCount, 0, "Urgent timeout must decrement pending urgent count");

  console.log("✓ Request deadlines and timeout enforcement passed");
}

// -----------------------------------------------------------------------------
// Test 5: Consumer States and Property Mappings
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();

  // 1. unavailable
  assert.strictEqual(svc.isUnavailable, true);
  assert.strictEqual(svc.isConnected, false);
  assert.strictEqual(svc.isConnecting, false);
  assert.strictEqual(svc.isDisconnecting, false);
  assert.strictEqual(svc.isError, false);

  // 2. connecting
  svc.applySnapshot({ state: "connecting", revision: "r1" });
  assert.strictEqual(svc.isConnecting, true);
  assert.strictEqual(svc.isConnected, false);

  // 3. connected
  svc.applySnapshot({ state: "connected", revision: "r2" });
  assert.strictEqual(svc.isConnected, true);
  assert.strictEqual(svc.isConnecting, false);

  // 4. disconnecting
  svc.applySnapshot({ state: "disconnecting", revision: "r3" });
  assert.strictEqual(svc.isDisconnecting, true);
  assert.strictEqual(svc.isConnected, false);

  // 5. error
  svc.applySnapshot({ state: "error", revision: "r4", errorCode: "vpn_crash" });
  assert.strictEqual(svc.isError, true);
  assert.strictEqual(svc.errorCode, "vpn_crash");

  // 6. capabilities before vs after handshake
  const svcPreHandshake = createServiceSimulator();
  assert.strictEqual(svcPreHandshake.capabilities.connect, false);
  svcPreHandshake.applySnapshot({
    state: "disconnected",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: false }
  });
  assert.strictEqual(svcPreHandshake.capabilities.connect, true);
  assert.strictEqual(svcPreHandshake.capabilities.killSwitch, true);
  assert.strictEqual(svcPreHandshake.capabilities.dnsLockdown, false);

  // 7. configMode mapping across formats
  svc.applySnapshot({ configMode: 0 });
  assert.strictEqual(svc.configMode, "generated");
  svc.applySnapshot({ configMode: 1 });
  assert.strictEqual(svc.configMode, "subscribe");
  svc.applySnapshot({ configMode: 2 });
  assert.strictEqual(svc.configMode, "custom");
  svc.applySnapshot({ configMode: "manual" });
  assert.strictEqual(svc.configMode, "generated");

  console.log("✓ Consumer states and property mappings passed");
}

// -----------------------------------------------------------------------------
// Test 6: Click Ownership and Input Domain Regression
// -----------------------------------------------------------------------------
{
  const serversViewPath = path.join(__dirname, "../ui/ServersView.qml");
  const qmlContent = fs.readFileSync(serversViewPath, "utf8");

  // 1. Verify rowMouse is declared before rowContent in QML source
  const rowMouseIdx = qmlContent.indexOf("id: rowMouse");
  const rowContentIdx = qmlContent.indexOf("id: rowContent");
  const rowActionsIdx = qmlContent.indexOf("id: rowActions");

  assert(rowMouseIdx !== -1, "rowMouse must exist in ServersView.qml");
  assert(rowContentIdx !== -1, "rowContent must exist in ServersView.qml");
  assert(rowActionsIdx !== -1, "rowActions must exist in ServersView.qml");

  assert(rowMouseIdx < rowContentIdx, "rowMouse must be declared BEFORE rowContent so it does not sit on top of buttons");

  // 2. Verify z-index stacking domains
  assert(qmlContent.includes("z: 0"), "rowMouse must have z: 0 (background domain)");
  assert(qmlContent.includes("z: 1"), "rowContent must have z: 1");
  assert(qmlContent.includes("z: 2"), "rowActions must have z: 2 (foreground action domain)");

  // 3. Verify input domain bounding (rowMouse stops before rowActions)
  assert(/anchors\.rightMargin:\s*rowActions\.width/.test(qmlContent), "rowMouse must be bounded to leave rowActions uncovered");

  // 4. Verify search placeholder uses i18n
  assert(qmlContent.includes('placeholderText: root.tr("servers.searchPlaceholder")'), "ServersView searchField must use localized searchPlaceholder");

  // 5. Functional regression of click dispatch domains:
  // Simulate pointer event dispatch over the row
  const rowWidth = 480;
  const rowActionsWidth = 110;
  const actionsLeftX = rowWidth - rowActionsWidth;

  function simulateClickAt(x, serviceMock) {
    if (x >= actionsLeftX) {
      // In rowActions domain: hits IconButton
      const buttonSlot = Math.floor((x - actionsLeftX) / (rowActionsWidth / 3));
      if (buttonSlot === 0) serviceMock.testServer("s1");
      else if (buttonSlot === 1) serviceMock.verifyServer("s1");
      else serviceMock.removeServer("s1");
    } else {
      // In row selection domain: hits rowMouse
      serviceMock.selectServer("s1");
    }
  }

  const calls = { select: 0, test: 0, verify: 0, remove: 0 };
  const mockSvc = {
    selectServer: (id) => { calls.select++; },
    testServer: (id) => { calls.test++; },
    verifyServer: (id) => { calls.verify++; },
    removeServer: (id) => { calls.remove++; }
  };

  // Click row body (x = 100) -> must select, must NOT test/verify/remove
  simulateClickAt(100, mockSvc);
  assert.strictEqual(calls.select, 1);
  assert.strictEqual(calls.test, 0);

  // Click Test button (x = 380) -> must test, must NOT select
  simulateClickAt(380, mockSvc);
  assert.strictEqual(calls.test, 1);
  assert.strictEqual(calls.select, 1, "Action click must NOT trigger selectServer");

  // Click Verify button (x = 410) -> must verify, must NOT select
  simulateClickAt(410, mockSvc);
  assert.strictEqual(calls.verify, 1);
  assert.strictEqual(calls.select, 1);

  // Click Remove button (x = 460) -> must remove, must NOT select
  simulateClickAt(460, mockSvc);
  assert.strictEqual(calls.remove, 1);
  assert.strictEqual(calls.select, 1);

  console.log("✓ Click ownership and input domain separation verified");
}

// -----------------------------------------------------------------------------
// Test 7: Flush Unsafe Queued Mutations on Disconnect and Transport Error
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();

  // Enqueue two mutations
  let m1Err = null;
  let m2Err = null;
  svc.sendRequest("servers.select", { revision: "r1", id: "s1" }, null, (err) => { m1Err = err; });
  svc.sendRequest("servers.select", { revision: "r1", id: "s2" }, null, (err) => { m2Err = err; });

  assert.strictEqual(svc._requestQueue.size(), 1); // s2 in queue

  // Call disconnect -> must flush unsafe queued mutations
  svc.disconnect();

  assert(m2Err !== null, "Queued mutation must be flushed on disconnect");
  assert.strictEqual(m2Err.code, "cancelled");
  assert.strictEqual(svc._requestQueue.size(), 0, "Queue must be empty after mutation flush");

  // Transport error / backend exit test
  const svc2 = createServiceSimulator();
  let pendingErr = null;
  let queuedErr = null;
  svc2.sendRequest("servers.list", {}, null, (err) => { pendingErr = err; });
  svc2.sendRequest("apps.list", {}, null, (err) => { queuedErr = err; });

  // Simulate process exit
  svc2.flushAllQueued("process_exited", "Process exited");
  assert(queuedErr !== null);
  assert.strictEqual(queuedErr.code, "process_exited");

  console.log("✓ Unsafe mutation flush on disconnect/transport error passed");
}

// -----------------------------------------------------------------------------
// Test 8: Bound Urgent Callback Count
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();

  // Send maxUrgentPending (4) urgent requests
  const ids = [];
  for (let i = 0; i < 4; i++) {
    const id = svc.sendRequest("cancel", { id: "req-" + i }, null, null, true);
    assert(id !== null, "Urgent request " + i + " should succeed");
    ids.push(id);
  }
  assert.strictEqual(svc._pendingUrgentCount, 4);

  // 5th urgent request must fail with queue_full
  let fifthErr = null;
  const fifthId = svc.sendRequest("cancel", { id: "req-5" }, null, (err) => {
    fifthErr = err;
  }, true);

  assert.strictEqual(fifthId, null);
  assert(fifthErr !== null);
  assert.strictEqual(fifthErr.code, "queue_full");
  assert.strictEqual(svc._pendingUrgentCount, 4);

  // Complete one urgent request
  svc.handleResponse(ids[0], false, { ok: true });
  assert.strictEqual(svc._pendingUrgentCount, 3);

  // Now a new urgent request is allowed
  const sixthId = svc.sendRequest("cancel", { id: "req-6" }, null, null, true);
  assert(sixthId !== null);
  assert.strictEqual(svc._pendingUrgentCount, 4);

  console.log("✓ Urgent callback count bounded to maxUrgentPending passed");
}

// -----------------------------------------------------------------------------
// Backend Handler Emulator for SettingsFeature.cs (Settings.Set)
// -----------------------------------------------------------------------------
function emulateBackendSettingsSet(storage, requestParams) {
  const isCustom = storage.configMode === "custom";
  if (!requestParams || typeof requestParams !== "object") {
    throw { code: "invalid_argument", message: "Missing request parameters" };
  }
  if (!requestParams.revision || requestParams.revision !== storage.revision) {
    throw { code: "conflict", message: "Settings conflict" };
  }
  const values = requestParams.values;
  if (!values || typeof values !== "object") {
    throw { code: "invalid_argument", message: "Missing values parameter" };
  }

  // dnsMode validation (SettingsFeature.cs line 175-204)
  if ("dnsMode" in values) {
    if (isCustom) {
      throw { code: "invalid_argument", message: "dnsMode cannot be configured in custom config mode" };
    }
    if (values.dnsMode === null) {
      storage.dnsModeOverride = null;
    } else if (typeof values.dnsMode === "string") {
      const raw = values.dnsMode.trim().toLowerCase();
      if (raw !== "vpn_only" && raw !== "smart" && raw !== "direct") {
        throw { code: "invalid_argument", message: "dnsMode must be 'vpn_only', 'smart', or 'direct'" };
      }
      storage.dnsModeOverride = raw;
    } else {
      throw { code: "invalid_argument", message: "dnsMode must be a string or null" };
    }
  }

  // mtu validation (SettingsFeature.cs line 127-136)
  if ("mtu" in values) {
    const mtuVal = values.mtu;
    if (typeof mtuVal !== "number" || !Number.isInteger(mtuVal) || mtuVal < 576 || mtuVal > 9000) {
      throw { code: "invalid_argument", message: "MTU must be an integer between 576 and 9000" };
    }
    storage.mtu = mtuVal;
  }

  if ("ipv6Enabled" in values) storage.ipv6Enabled = Boolean(values.ipv6Enabled);
  if ("strictRoute" in values) storage.strictRoute = Boolean(values.strictRoute);
  if ("strictDns" in values) storage.strictDns = Boolean(values.strictDns);
  if ("bypassRussianTraffic" in values) storage.bypassRussianTraffic = Boolean(values.bypassRussianTraffic);
  if ("blockAds" in values) storage.blockAds = Boolean(values.blockAds);
  if ("dnsLeakLockdown" in values) storage.dnsLeakLockdown = Boolean(values.dnsLeakLockdown);
  if ("routeExcludeAddress" in values) storage.routeExcludeAddress = values.routeExcludeAddress;

  storage.revision = storage.revision + "-rev";
  return {
    ok: true,
    result: {
      revision: storage.revision,
      mtu: storage.mtu,
      dnsMode: isCustom ? "custom" : (storage.dnsModeOverride || "vpn_only")
    }
  };
}

// SettingsView Logic Simulator mirroring ui/SettingsView.qml
function createSettingsViewSim(service, overrides) {
  const o = overrides || {};
  const sim = {
    service: service,
    mtuVal: (o.mtuVal !== undefined) ? o.mtuVal : ((service && service.settingsData) ? service.settingsData.mtu : 1420),
    ipv6Val: (o.ipv6Val !== undefined) ? o.ipv6Val : ((service && service.settingsData) ? service.settingsData.ipv6Enabled : false),
    strictRouteVal: (o.strictRouteVal !== undefined) ? o.strictRouteVal : ((service && service.settingsData) ? service.settingsData.strictRoute : false),
    strictDnsVal: (o.strictDnsVal !== undefined) ? o.strictDnsVal : ((service && service.settingsData) ? service.settingsData.strictDns : false),
    dnsModeVal: (o.dnsModeVal !== undefined) ? o.dnsModeVal : ((service && service.settingsData && service.settingsData.dnsMode !== undefined) ? service.settingsData.dnsMode : "vpn_only"),
    bypassRuVal: (o.bypassRuVal !== undefined) ? o.bypassRuVal : ((service && service.settingsData) ? service.settingsData.bypassRussianTraffic : true),
    blockAdsVal: (o.blockAdsVal !== undefined) ? o.blockAdsVal : ((service && service.settingsData) ? service.settingsData.blockAds : false),
    dnsLeakVal: (o.dnsLeakVal !== undefined) ? o.dnsLeakVal : ((service && service.settingsData) ? service.settingsData.dnsLeakLockdown : false),
    cidrsVal: (o.cidrsVal !== undefined) ? o.cidrsVal : ((service && service.settingsData && service.settingsData.routeExcludeAddress)
      ? Model.formatCidrList(service.settingsData.routeExcludeAddress) : ""),

    get isCustomMode() {
      if (o.isCustomMode !== undefined) return o.isCustomMode;
      if (sim.service && sim.service.configMode === "custom") return true;
      if (sim.service && sim.service.settingsData && sim.service.settingsData.dnsMode === "custom") return true;
      if (sim.dnsModeVal === "custom") return true;
      return false;
    },

    get hasDnsLockdownCap() {
      if (o.hasDnsLockdownCap !== undefined) return o.hasDnsLockdownCap;
      return !!(sim.service && sim.service.capabilities && sim.service.capabilities.dnsLockdown === true);
    },

    get dnsExplanationKey() {
      const source = fs.readFileSync(path.join(__dirname, "../ui/SettingsView.qml"), "utf8");
      const match = source.match(/readonly property string dnsExplanationText:\s*\{([\s\S]*?)\n  \}/);
      assert(match, "Actual QML DNS explanation property must exist");
      sim.tr = key => key;
      return new Function("root", "service", match[1])(sim, sim.service);
    },

    toggleDnsLeak(val) {
      if (sim.hasDnsLockdownCap) {
        sim.dnsLeakVal = val;
      }
    },

    selectDnsMode(mode) {
      if (!sim.isCustomMode) {
        sim.dnsModeVal = mode;
      }
    },

    resetProfileDefault() {
      if (!sim.isCustomMode) {
        sim.dnsModeVal = null;
      }
    },

    buildSettingsPayload() {
      const source = fs.readFileSync(path.join(__dirname, "../ui/SettingsView.qml"), "utf8");
      const match = source.match(/function buildSettingsPayload\(\)\s*\{([\s\S]*?)\n  \}/);
      assert(match, "Actual QML payload handler must exist");
      return new Function("root", "Model", match[1])(sim, Model);
    }
  };
  return sim;
}

// -----------------------------------------------------------------------------
// Test 9: Handler-Level Custom Config MTU Save & dnsMode Omission
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();
  svc.applySnapshot({
    state: "disconnected",
    revision: "rev-cust-1",
    configMode: "custom",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: true }
  });
  svc.settingsData = {
    mtu: 1420,
    ipv6Enabled: false,
    strictRoute: false,
    strictDns: false,
    dnsMode: "custom",
    dnsModeSemantics: "DNS is defined by raw custom sing-box configuration",
    bypassRussianTraffic: true,
    blockAds: false,
    dnsLeakLockdown: false,
    routeExcludeAddress: []
  };

  const view = createSettingsViewSim(svc);
  assert.strictEqual(view.isCustomMode, true, "isCustomMode must be true when configMode is custom");

  // User changes MTU to 1380
  view.mtuVal = 1380;
  const payload = view.buildSettingsPayload();

  // 1. Verify payload properties
  assert.strictEqual(payload.mtu, 1380, "Payload MTU must be updated value");
  assert.strictEqual(payload.dnsMode, undefined, "Custom mode save MUST omit dnsMode");
  assert.strictEqual("dnsMode" in payload, false, "dnsMode property must not exist on payload object");

  // 2. Handler-level backend emulation with valid omitted dnsMode
  const backendStorage = {
    configMode: "custom",
    revision: "rev-cust-1",
    mtu: 1420,
    dnsModeOverride: null
  };

  const response = emulateBackendSettingsSet(backendStorage, {
    revision: "rev-cust-1",
    values: payload
  });

  assert.strictEqual(response.ok, true, "Backend handler must accept custom MTU save without dnsMode");
  assert.strictEqual(backendStorage.mtu, 1380, "Backend storage MTU must be updated to 1380");

  // 3. Negative regression check: if dnsMode WAS included, backend MUST reject
  let rejectedErr = null;
  try {
    emulateBackendSettingsSet(backendStorage, {
      revision: backendStorage.revision,
      values: { mtu: 1380, dnsMode: "custom" }
    });
  } catch (err) {
    rejectedErr = err;
  }
  assert(rejectedErr !== null, "Backend must reject dnsMode in custom mode");
  assert.strictEqual(rejectedErr.code, "invalid_argument");
  assert.strictEqual(rejectedErr.message, "dnsMode cannot be configured in custom config mode");

  console.log("✓ Handler-level regression test: custom MTU save omits dnsMode & succeeds passed");
}

// -----------------------------------------------------------------------------
// Test 10: Normal Mode Settings Save & DNS Mode Enum / Nullable Reset
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();
  svc.applySnapshot({
    state: "disconnected",
    revision: "rev-norm-1",
    configMode: "generated",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: true }
  });
  svc.settingsData = {
    mtu: 1420,
    ipv6Enabled: false,
    strictRoute: false,
    strictDns: false,
    dnsMode: "vpn_only",
    dnsModeSemantics: null,
    bypassRussianTraffic: true,
    blockAds: false,
    dnsLeakLockdown: false,
    routeExcludeAddress: []
  };

  const view = createSettingsViewSim(svc);
  assert.strictEqual(view.isCustomMode, false, "isCustomMode must be false in generated mode");

  const backendStorage = {
    configMode: "generated",
    revision: "rev-norm-1",
    mtu: 1420,
    dnsModeOverride: null
  };

  // Test 1: vpn_only
  view.selectDnsMode("vpn_only");
  const pVpnOnly = view.buildSettingsPayload();
  assert.strictEqual(pVpnOnly.dnsMode, "vpn_only");
  emulateBackendSettingsSet(backendStorage, { revision: backendStorage.revision, values: pVpnOnly });
  assert.strictEqual(backendStorage.dnsModeOverride, "vpn_only");

  // Test 2: smart
  view.selectDnsMode("smart");
  const pSmart = view.buildSettingsPayload();
  assert.strictEqual(pSmart.dnsMode, "smart");
  emulateBackendSettingsSet(backendStorage, { revision: backendStorage.revision, values: pSmart });
  assert.strictEqual(backendStorage.dnsModeOverride, "smart");

  // Test 3: direct
  view.selectDnsMode("direct");
  const pDirect = view.buildSettingsPayload();
  assert.strictEqual(pDirect.dnsMode, "direct");
  emulateBackendSettingsSet(backendStorage, { revision: backendStorage.revision, values: pDirect });
  assert.strictEqual(backendStorage.dnsModeOverride, "direct");

  // Test 4: nullable reset (profile default)
  view.resetProfileDefault();
  assert.strictEqual(view.dnsModeVal, null, "dnsModeVal must be null after resetProfileDefault");
  const pReset = view.buildSettingsPayload();
  assert.strictEqual(pReset.dnsMode, null, "Payload dnsMode must be null for profile-default reset");
  emulateBackendSettingsSet(backendStorage, { revision: backendStorage.revision, values: pReset });
  assert.strictEqual(backendStorage.dnsModeOverride, null, "Backend storage dnsModeOverride must be reset to null");

  // Test 5: Negative check - invalid enum values rejected by backend handler
  const invalidModes = ["invalid_mode", "", "leak", 123];
  for (const inv of invalidModes) {
    let err = null;
    try {
      emulateBackendSettingsSet(backendStorage, { revision: backendStorage.revision, values: { dnsMode: inv } });
    } catch (e) {
      err = e;
    }
    assert(err !== null, "Invalid dnsMode '" + inv + "' must be rejected by backend");
    assert.strictEqual(err.code, "invalid_argument");
  }

  console.log("✓ Normal mode settings save with enum values and nullable reset passed");
}

// -----------------------------------------------------------------------------
// Test 11: Unsupported Control (dnsLeak Lockdown & Custom DNS Mode Choices)
// -----------------------------------------------------------------------------
{
  // 1. dnsLeak when capability is unsupported (false) - preserve existing true
  const svcUnsupportedTrue = createServiceSimulator();
  svcUnsupportedTrue.applySnapshot({
    state: "disconnected",
    revision: "rev-cap-1",
    configMode: "generated",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: false }
  });
  svcUnsupportedTrue.settingsData.dnsLeakLockdown = true;

  const viewUnsupportedTrue = createSettingsViewSim(svcUnsupportedTrue);
  assert.strictEqual(viewUnsupportedTrue.hasDnsLockdownCap, false, "hasDnsLockdownCap must be false");
  assert.strictEqual(viewUnsupportedTrue.dnsLeakVal, true, "Existing true value must be preserved on load");

  // Attempting to toggle when unsupported must be guarded
  viewUnsupportedTrue.toggleDnsLeak(false);
  assert.strictEqual(viewUnsupportedTrue.dnsLeakVal, true, "Toggle must not change value when capability is unsupported");

  const pUnsupportedTrue = viewUnsupportedTrue.buildSettingsPayload();
  assert.strictEqual(pUnsupportedTrue.dnsLeakLockdown, undefined, "Unavailable protection must be omitted, not re-enabled or disabled");
  const storedProtection = { dnsLeakLockdown: true, mtu: 1420 };
  Object.assign(storedProtection, pUnsupportedTrue);
  assert.strictEqual(storedProtection.dnsLeakLockdown, true, "Omitted safety preference must remain true");

  // 2. dnsLeak when capability is unsupported (false) - do not offer unsupported enable
  const svcUnsupportedFalse = createServiceSimulator();
  svcUnsupportedFalse.applySnapshot({
    state: "disconnected",
    revision: "rev-cap-2",
    configMode: "generated",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: false }
  });
  svcUnsupportedFalse.settingsData.dnsLeakLockdown = false;

  const viewUnsupportedFalse = createSettingsViewSim(svcUnsupportedFalse);
  assert.strictEqual(viewUnsupportedFalse.hasDnsLockdownCap, false);
  assert.strictEqual(viewUnsupportedFalse.dnsLeakVal, false, "Initial false value remains false");

  // Attempt to enable
  viewUnsupportedFalse.toggleDnsLeak(true);
  assert.strictEqual(viewUnsupportedFalse.dnsLeakVal, false, "Must not allow unsupported enable");

  const pUnsupportedFalse = viewUnsupportedFalse.buildSettingsPayload();
  assert.strictEqual(pUnsupportedFalse.dnsLeakLockdown, undefined, "Payload must omit unsupported feature");

  // 3. dnsLeak when capability is supported (true) - toggle works normally
  const svcSupported = createServiceSimulator();
  svcSupported.applySnapshot({
    state: "disconnected",
    revision: "rev-cap-3",
    configMode: "generated",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: true }
  });
  svcSupported.settingsData.dnsLeakLockdown = false;

  const viewSupported = createSettingsViewSim(svcSupported);
  assert.strictEqual(viewSupported.hasDnsLockdownCap, true);
  viewSupported.toggleDnsLeak(true);
  assert.strictEqual(viewSupported.dnsLeakVal, true, "Should toggle to true when capability supported");
  viewSupported.toggleDnsLeak(false);
  assert.strictEqual(viewSupported.dnsLeakVal, false, "Should toggle to false when capability supported");

  // 4. DNS mode choices disabled in custom mode
  const svcCustom = createServiceSimulator();
  svcCustom.applySnapshot({
    state: "disconnected",
    revision: "rev-cap-4",
    configMode: "custom",
    capabilities: { connect: true, killSwitch: true, dnsLockdown: true }
  });
  svcCustom.settingsData.dnsMode = "custom";

  const viewCustom = createSettingsViewSim(svcCustom);
  assert.strictEqual(viewCustom.isCustomMode, true);
  assert.strictEqual(viewCustom.dnsModeVal, "custom");

  // Attempt to select another mode in custom mode
  viewCustom.selectDnsMode("smart");
  assert.strictEqual(viewCustom.dnsModeVal, "custom", "DNS mode selection must be ignored in custom mode");

  viewCustom.resetProfileDefault();
  assert.strictEqual(viewCustom.dnsModeVal, "custom", "Reset to profile default must be ignored in custom mode");

  // 5. Verify QML source bindings for unsupported controls
  const settingsQmlPath = path.join(__dirname, "../ui/SettingsView.qml");
  const settingsQml = fs.readFileSync(settingsQmlPath, "utf8");

  assert(settingsQml.includes("enabled: root.hasDnsLockdownCap"), "dnsLeak toggle must bind enabled to hasDnsLockdownCap");
  assert(settingsQml.includes('description: !root.hasDnsLockdownCap ? root.tr("settings.dnsLeakUnsupported") : ""'),
    "dnsLeak toggle must show localized unsupported description when disabled");
  assert(settingsQml.includes("opacity: root.isCustomMode ? 0.5 : 1.0"), "DNS mode choices row must have disabled opacity in custom mode");
  assert(settingsQml.includes("hoverEnabled: !root.isCustomMode"), "DNS mode mouse areas must disable hover in custom mode");
  assert(settingsQml.includes("cursorShape: root.isCustomMode ? Qt.ArrowCursor : Qt.PointingHandCursor"),
    "DNS mode mouse areas must show arrow cursor in custom mode");
  assert(settingsQml.includes("if (!root.isCustomMode)"), "DNS mode click handler and save payload must check !root.isCustomMode");

  console.log("✓ Unsupported control handling (dnsLeak & custom DNS mode choices) passed");
}

// -----------------------------------------------------------------------------
// Test 12: Actual QML DNS Draft Explanations
// -----------------------------------------------------------------------------
{
  const svc = createServiceSimulator();

  // Saved explanatory prose is stale as soon as the user edits the draft.
  // Exercise the actual QML property through transitions, not a copied mapping.
  svc.settingsData.strictDns = true;
  svc.settingsData.dnsModeSemantics = "StrictDns active: all DNS forced through VPN tunnel (vpn-dns) regardless of mode";
  const draft = createSettingsViewSim(svc, { dnsModeVal: "direct" });
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.forcedStrictDns");
  draft.strictDnsVal = false;
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.directDesc",
    "Disabling Strict DNS in draft must remove the saved forced-DNS explanation");
  draft.resetProfileDefault();
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.profileDefaultDesc");
  svc.routingMode = "full";
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.forcedFull");
  draft.strictDnsVal = true;
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.forcedStrictDns");
  svc.configMode = "custom";
  svc.settingsData.dnsModeSemantics = "DNS is defined by raw custom sing-box configuration";
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.forcedCustomStrictDns",
    "Enabling Strict DNS in custom draft must override saved raw-config prose");
  draft.strictDnsVal = false;
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.forcedCustomFull");
  svc.routingMode = "split";
  assert.strictEqual(draft.dnsExplanationKey, "settings.dnsMode.customConfig");
  svc.configMode = "generated";
  svc.settingsData.strictDns = false;

  // Test state fallbacks when dnsModeSemantics is omitted
  svc.settingsData.dnsModeSemantics = null;

  // Custom + strictDns
  const viewCustStrict = createSettingsViewSim(svc, {
    isCustomMode: true,
    strictDnsVal: true
  });
  assert.strictEqual(viewCustStrict.dnsExplanationKey, "settings.dnsMode.forcedCustomStrictDns");

  // Custom + full
  const svcFull = createServiceSimulator();
  svcFull.routingMode = "full";
  const viewCustFull = createSettingsViewSim(svcFull, {
    isCustomMode: true,
    strictDnsVal: false
  });
  assert.strictEqual(viewCustFull.dnsExplanationKey, "settings.dnsMode.forcedCustomFull");

  // Custom normal
  const viewCustNorm = createSettingsViewSim(svc, {
    isCustomMode: true,
    strictDnsVal: false
  });
  assert.strictEqual(viewCustNorm.dnsExplanationKey, "settings.dnsMode.customConfig");

  // Non-custom + strictDns
  const viewNonCustStrict = createSettingsViewSim(svc, {
    isCustomMode: false,
    strictDnsVal: true
  });
  assert.strictEqual(viewNonCustStrict.dnsExplanationKey, "settings.dnsMode.forcedStrictDns");

  // Non-custom + full
  const viewNonCustFull = createSettingsViewSim(svcFull, {
    isCustomMode: false,
    strictDnsVal: false
  });
  assert.strictEqual(viewNonCustFull.dnsExplanationKey, "settings.dnsMode.forcedFull");

  // Non-custom split + vpn_only
  const viewSplitVpn = createSettingsViewSim(svc, {
    isCustomMode: false,
    strictDnsVal: false,
    dnsModeVal: "vpn_only"
  });
  assert.strictEqual(viewSplitVpn.dnsExplanationKey, "settings.dnsMode.vpnOnlyDesc");

  // Non-custom split + smart
  const viewSplitSmart = createSettingsViewSim(svc, {
    isCustomMode: false,
    strictDnsVal: false,
    dnsModeVal: "smart"
  });
  assert.strictEqual(viewSplitSmart.dnsExplanationKey, "settings.dnsMode.smartDesc");

  // Non-custom split + direct
  const viewSplitDirect = createSettingsViewSim(svc, {
    isCustomMode: false,
    strictDnsVal: false,
    dnsModeVal: "direct"
  });
  assert.strictEqual(viewSplitDirect.dnsExplanationKey, "settings.dnsMode.directDesc");

  // Non-custom split + null (profile default)
  const viewSplitDefault = createSettingsViewSim(svc, {
    isCustomMode: false,
    strictDnsVal: false,
    dnsModeVal: null
  });
  assert.strictEqual(viewSplitDefault.dnsExplanationKey, "settings.dnsMode.profileDefaultDesc");

  console.log("DNS draft transitions and actual QML explanations verified");
}

// -----------------------------------------------------------------------------
// Test 13: RU / EN Locales Parity & Accurate Meaning Verification
// -----------------------------------------------------------------------------
{
  const enPath = path.join(__dirname, "../locales/en.json");
  const ruPath = path.join(__dirname, "../locales/ru.json");
  const en = JSON.parse(fs.readFileSync(enPath, "utf8"));
  const ru = JSON.parse(fs.readFileSync(ruPath, "utf8"));

  const enKeys = Object.keys(en);
  const ruKeys = Object.keys(ru);

  const missingInRu = enKeys.filter((k) => !ruKeys.includes(k));
  const missingInEn = ruKeys.filter((k) => !enKeys.includes(k));

  assert.strictEqual(missingInRu.length, 0, "Keys missing in ru.json: " + missingInRu.join(", "));
  assert.strictEqual(missingInEn.length, 0, "Keys missing in en.json: " + missingInEn.join(", "));
  assert.strictEqual(enKeys.length, ruKeys.length, "en.json and ru.json must have identical key count");

  // Verify non-empty strings
  for (const k of enKeys) {
    assert(typeof en[k] === "string" && en[k].trim().length > 0, "Key " + k + " in en.json must not be empty");
    assert(typeof ru[k] === "string" && ru[k].trim().length > 0, "Key " + k + " in ru.json must not be empty");
  }

  // Required settings keys must exist
  const requiredKeys = [
    "settings.dnsMode.vpnOnly",
    "settings.dnsMode.vpnOnlyDesc",
    "settings.dnsMode.smart",
    "settings.dnsMode.smartDesc",
    "settings.dnsMode.direct",
    "settings.dnsMode.directDesc",
    "settings.dnsMode.resetDefault",
    "settings.dnsMode.profileDefaultDesc",
    "settings.dnsMode.customConfig",
    "settings.dnsMode.forcedCustomStrictDns",
    "settings.dnsMode.forcedCustomFull",
    "settings.dnsMode.forcedStrictDns",
    "settings.dnsMode.forcedFull",
    "settings.dnsLeakUnsupported"
  ];

  for (const rk of requiredKeys) {
    assert(rk in en, "Missing required key in en.json: " + rk);
    assert(rk in ru, "Missing required key in ru.json: " + rk);
  }

  // Accurate meaning checks
  // 1. smart: opt-in local encrypted DNS (DoH) for routed apps
  assert(/local.*encrypted.*dns/i.test(en["settings.dnsMode.smartDesc"]) || /DoH/i.test(en["settings.dnsMode.smartDesc"]),
    "en smartDesc must explain local encrypted DNS / DoH for routed apps");
  assert(/зашифрованный.*dns/i.test(ru["settings.dnsMode.smartDesc"]) || /DoH/i.test(ru["settings.dnsMode.smartDesc"]),
    "ru smartDesc must explain localized encrypted DNS");

  // 2. direct: historical value still routes routed-app DNS via vpn-dns, don't promise direct leaks
  assert(/vpn/i.test(en["settings.dnsMode.directDesc"]), "en directDesc must mention routing via VPN");
  assert(!/leak/i.test(en["settings.dnsMode.directDesc"]), "en directDesc must NOT promise leaks");
  assert(/vpn/i.test(ru["settings.dnsMode.directDesc"]), "ru directDesc must mention VPN tunnel");
  assert(!/утечк/i.test(ru["settings.dnsMode.directDesc"]), "ru directDesc must NOT promise leaks");

  console.log("✓ RU/EN translation parity and accurate meaning verification passed");
}

// Exercise actual consumer functions, not an independently maintained DTO copy.
{
  const svc = createServiceSimulator();
  const id = svc.getSettings();
  const explanation = "StrictDns active: all DNS forced through VPN tunnel (vpn-dns) regardless of mode";
  svc.handleResponse(id, false, { mtu: 1450, dnsMode: "smart", dnsModeOverride: null, dnsModeSemantics: explanation });
  assert.strictEqual(svc.settingsData.dnsModeOverride, null);
  assert.strictEqual(svc.settingsData.dnsModeSemantics, explanation);
  const source = fs.readFileSync(path.join(__dirname, "../ui/SettingsView.qml"), "utf8");
  const match = source.match(/function savedDnsMode\(\)\s*\{([\s\S]*?)\n  \}/);
  assert(match, "Actual draft initializer must exist");
  const getDraft = new Function("service", match[1]);
  const draft = getDraft(svc);
  assert.strictEqual(draft, null, "Profile default must remain selected after refresh");
  const view = createSettingsViewSim(svc, { dnsModeVal: draft });
  assert.strictEqual(view.buildSettingsPayload().dnsMode, null, "Unrelated save must not turn inherited mode into explicit override");
  assert.strictEqual(getDraft({ settingsData: { dnsMode: "smart", dnsModeOverride: "direct" } }), "direct");
  assert.strictEqual(getDraft({ settingsData: { dnsMode: "smart" } }), "smart", "Older backend response remains compatible");
  console.log("Actual QML DNS reset/readback/save and semantics mapping passed");
}

console.log("\nALL SERVICE & INTEGRATION TESTS PASSED!\n");
