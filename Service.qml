import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "lib/Protocol.js" as Protocol
import "lib/Model.js" as Model
import "lib/I18n.js" as I18n

Item {
  id: root

  property var settings: ({})

  // ---- Service Lifecycle and Binary Resolution ------------------------------
  readonly property string helperPath: {
    var raw = Qt.resolvedUrl("bin/vpnrouter-headless").toString()
    return raw.replace("file://", "")
  }

  property bool helperPresent: false
  property bool backendMissing: false
  property string unavailableReason: ""
  property var unavailableReasonCode: null
  property bool serversLoaded: false
  property bool subscriptionsLoaded: false
  property bool starting: false
  property int retryCount: 0
  property int retryBackoffMs: 2000

  // ---- Protocol and Queue ----------------------------------------------------
  property var _pendingCallbacks: ({}) // id -> { onDone, onError, method, isUrgent, deadline }
  property int _pendingUrgentCount: 0
  readonly property int maxUrgentPending: 4
  property int requestDeadlineMs: 15000
  property var _requestQueue: Protocol.createRequestQueue(8)
  property var _accumulator: null

  // ---- Reactive State Model --------------------------------------------------
  property string state: "unavailable"
  property string revision: ""
  property string backendVersion: ""
  property string activeServer: ""
  property string routingMode: "split"
  property string routingAppsMode: "include"
  property string configMode: "generated"
  property bool busy: false
  property string errorCode: ""
  property string lastError: ""
  // Safe default: connect is false until handshake/snapshot explicitly confirms it
  property var capabilities: ({ connect: false, killSwitch: false, dnsLockdown: false })

  // Active in-flight operation description (for pending/busy indicator)
  property string activeOperation: ""
  property string activeRequestId: ""
  property var activeProgress: null // { id, stage, completed, total }

  // Testing & Harness Controls
  property bool processDisabled: false
  property var fakeBackend: null

  // I18n Reactivity State
  property int i18nRevision: 0
  property string locale: "auto"
  property string effectiveLocale: I18n.getEffectiveLocale()

  // Collections
  property var servers: []
  property int serversTotal: 0
  property var subscriptions: []
  property int subscriptionsTotal: 0
  property var serverVerification: null
  property var freeVerification: null
  property var freeServers: []
  property int freeTotal: 0
  property bool appsLoaded: false
  property var apps: ({ include: [], exclude: [], running: [] })
  property var profiles: []
  property var rules: ({ text: "", priority: "toggles_first" })
  property var customConfigs: []
  property var settingsData: ({
    mtu: 1420,
    ipv6Enabled: false,
    strictRoute: false,
    strictDns: false,
    dnsMode: "vpn_only",
    bypassRussianTraffic: true,
    blockAds: false,
    dnsLeakLockdown: false,
    routeExcludeAddress: []
  })
  property var diagnosticsItems: []
  property string diagnosticsExportPath: ""

  // Convenience computed properties
  readonly property bool isConnected: state === "connected"
  readonly property bool isConnecting: state === "connecting"
  readonly property bool isDisconnecting: state === "disconnecting"
  readonly property bool isError: state === "error" || errorCode !== ""
  readonly property bool isUnavailable: state === "unavailable"

  signal stateChangedNotice(string newState)
  signal progressNotice(var progressObj)
  signal errorNotice(string code, string message)

  // UI entry points can have distinct JS import contexts in the live host.
  // Translate through this service, which owns the loaded catalogs.
  function tr(key, args) {
    var _ = root.i18nRevision
    return I18n.t(key, args)
  }

  // Omarchy 4.0.4 has no Commons.I18n singleton.
  readonly property var hostI18n: typeof Commons.I18n !== "undefined" ? Commons.I18n : null

  function systemLanguage() {
    return root.hostI18n && typeof root.hostI18n.language === "string"
      ? root.hostI18n.language : Quickshell.env("LANG")
  }

  Connections {
    target: root.hostI18n
    ignoreUnknownSignals: true
    function onLanguageChanged() { root.setLocale(root.locale) }
  }

  function setLocale(loc) {
    var userLang = root.systemLanguage()
    I18n.setLocale(loc, userLang)
    root.locale = loc
    root.effectiveLocale = I18n.getEffectiveLocale()
    root.i18nRevision++
    if (root.settings) {
      root.settings.locale = loc
    }
  }

  onSettingsChanged: {
    var userLang = root.systemLanguage()
    var configuredLocale = settings && settings.locale ? settings.locale : "auto"
    I18n.setLocale(configuredLocale, userLang)
    root.locale = configuredLocale
    root.effectiveLocale = I18n.getEffectiveLocale()
    root.i18nRevision++
  }

  // ---- Locale loader --------------------------------------------------------
  FileView {
    id: enFile
    path: Qt.resolvedUrl("locales/en.json").toString().replace("file://", "")
    printErrors: true
    blockLoading: true
    onLoadFailed: function(error) { console.warn("VPNRouter catalog load failed", path, error) }
    onLoaded: {
      try {
        var obj = JSON.parse(text())
        I18n.setCatalogs(obj, null)
        root.i18nRevision++
      } catch (e) { console.warn("VPNRouter invalid catalog", path, String(e)) }
    }
  }

  FileView {
    id: ruFile
    path: Qt.resolvedUrl("locales/ru.json").toString().replace("file://", "")
    printErrors: true
    blockLoading: true
    onLoadFailed: function(error) { console.warn("VPNRouter catalog load failed", path, error) }
    onLoaded: {
      try {
        var obj = JSON.parse(text())
        I18n.setCatalogs(null, obj)
        root.i18nRevision++
      } catch (e) { console.warn("VPNRouter invalid catalog", path, String(e)) }
    }
  }

  property var _i18nListener: function(r) {
    root.i18nRevision = r
    root.effectiveLocale = I18n.getEffectiveLocale()
  }

  Component.onCompleted: {
    var userLang = root.systemLanguage()
    var configuredLocale = settings && settings.locale ? settings.locale : "auto"
    I18n.setLocale(configuredLocale, userLang)
    root.locale = configuredLocale
    root.effectiveLocale = I18n.getEffectiveLocale()
    I18n.addListener(_i18nListener)
    initAccumulator()
    checkHelperAndStart()
  }

  Component.onDestruction: {
    I18n.removeListener(_i18nListener)
    tearDown()
  }

  function initAccumulator() {
    _accumulator = Protocol.createChunkAccumulator(
      function(frame) {
        handleIncomingFrame(frame)
      },
      function(err) {
        lastError = I18n.t("error.protocol")
        errorNotice(err.code || "protocol_error", lastError)
        if (err.code === "buffer_overflow") {
          root.flushAllQueued("transport_error", I18n.t("error.protocol"))
        }
      }
    )
  }

  function flushAllQueued(code, message) {
    var flushed = _requestQueue.clearAll()
    for (var i = 0; i < flushed.length; i++) {
      var it = flushed[i]
      if (it && typeof it.onError === "function") {
        it.onError({ code: code || "transport_error", message: message || I18n.t("error.transport") })
      }
    }
  }

  function flushQueuedMutations(reasonMsg) {
    var flushed = _requestQueue.flushQueued(function(item) {
      if (!item) return false
      if (item.needsRevision === true) return true
      var m = item.method || ""
      return m.indexOf(".set") !== -1 || m.indexOf(".select") !== -1 ||
             m.indexOf(".import") !== -1 || m.indexOf(".remove") !== -1 ||
             m.indexOf(".add") !== -1 || m.indexOf(".apply") !== -1
    })
    for (var i = 0; i < flushed.length; i++) {
      var it = flushed[i]
      if (it && typeof it.onError === "function") {
        it.onError({ code: "cancelled", message: reasonMsg || I18n.t("error.cancelled") })
      }
    }
  }

  function checkDeadlines(currentTime) {
    var now = currentTime || Date.now()
    var timedOutIds = []
    for (var id in root._pendingCallbacks) {
      var cb = root._pendingCallbacks[id]
      if (cb && cb.deadline && now > cb.deadline) {
        timedOutIds.push(id)
      }
    }

    for (var i = 0; i < timedOutIds.length; i++) {
      var tid = timedOutIds[i]
      var timedOutCb = root._pendingCallbacks[tid]
      if (!timedOutCb) continue
      delete root._pendingCallbacks[tid]

      if (timedOutCb.isUrgent && root._pendingUrgentCount > 0) {
        root._pendingUrgentCount--
      }

      var activeItem = root._requestQueue.getActive()
      var isOrdinary = (activeItem && activeItem.id === tid) || (root.activeRequestId === tid && !timedOutCb.isUrgent)

      if (isOrdinary) {
        root.activeRequestId = ""
        root.activeOperation = ""
        root.activeProgress = null
        root._requestQueue.clearActive()
      }

      var errObj = { code: "timeout", message: I18n.t("error.timeout") }
      root.lastError = errObj.message
      root.errorNotice("timeout", errObj.message)
      if (timedOutCb.onError && typeof timedOutCb.onError === "function") {
        timedOutCb.onError(errObj)
      }

      if (isOrdinary) {
        root.pumpQueue()
      }
    }
  }

  Timer {
    id: deadlineWatchdog
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.checkDeadlines()
  }

  function feedChunk(chunk) {
    if (_accumulator) _accumulator.feed(chunk)
  }

  function feedFrame(frame) {
    handleIncomingFrame(frame)
  }

  property bool _shuttingDown: false

  function checkHelperAndStart() {
    if (processDisabled) return
    if (backendProc.running) return
    root._shuttingDown = false
    starting = true
    backendProc.running = true
  }

  function tearDown() {
    root._shuttingDown = true
    retryTimer.stop()
    if (backendProc.running) {
      backendProc.signal(15) // SIGTERM
    }
  }

  // ---- Process Wiring -------------------------------------------------------
  Process {
    id: backendProc
    command: [root.helperPath, "--stdio"]
    stdinEnabled: true

    stdout: SplitParser {
      splitMarker: "" // Raw unbuffered chunks; bounded by root._accumulator
      onRead: function(chunk) {
        if (root._accumulator) {
          root._accumulator.feed(chunk)
        }
      }
    }

    onStarted: root.backendStarted()
    onExited: function(exitCode) { root.backendExited(exitCode) }
  }

  function backendStarted() {
    root.helperPresent = true
    root.backendMissing = false
    root.starting = false
    // Starting a wrapper is not a successful handshake.
    Qt.callLater(function() { if (backendProc.running) root.refreshSnapshot() })
  }

  function backendExited(exitCode) {
    root.starting = false
    root.helperPresent = false
    root.backendMissing = exitCode === 127
    root.state = "unavailable"
    root.capabilities = ({ connect: false, killSwitch: false, dnsLockdown: false })
    root.unavailableReason = ""
    root.unavailableReasonCode = null
    root.appsLoaded = false
    root.serversLoaded = false
    root.subscriptionsLoaded = false
    root.busy = false
    root.activeOperation = ""
    root.activeRequestId = ""
    root.activeProgress = null
    if (root._accumulator) root._accumulator.reset()

    var message = I18n.t("backend.exited", [exitCode])
    for (var id in root._pendingCallbacks) {
      var cb = root._pendingCallbacks[id]
      if (cb && typeof cb.onError === "function") {
        cb.onError({ code: "process_exited", message: message })
      }
    }
    root._pendingCallbacks = ({})
    root._pendingUrgentCount = 0
    root.flushAllQueued("process_exited", message)

    if (root._shuttingDown) return
    if (root.backendMissing) {
      root.lastError = ""
      retryTimer.stop()
      return
    }
    root.lastError = I18n.t("backend.retrying", [exitCode])
    root.retryBackoffMs = Math.min(30000, Math.round(root.retryBackoffMs * (root.retryCount > 0 ? 1.5 : 1)))
    root.retryCount++
    retryTimer.interval = root.retryBackoffMs
    retryTimer.restart()
  }

  Timer {
    id: retryTimer
    repeat: false
    onTriggered: {
      root.checkHelperAndStart()
    }
  }

  // ---- Protocol Frame Handling ----------------------------------------------
  function handleIncomingFrame(frame) {
    if (!frame) return

    if (frame.type === "event") {
      handleEvent(frame.event, frame.data)
      return
    }

    if (frame.type === "response") {
      handleResponse(frame.id, frame.isError, frame.result, frame.error)
      return
    }
  }

  function handleEvent(eventName, eventData) {
    if (eventName === "state") {
      applySnapshot(eventData)
      stateChangedNotice(root.state)
    } else if (eventName === "progress") {
      if (eventData) {
        root.activeProgress = {
          // Feature events carry a resource ID or no ID, not a request ID.
          id: String(eventData.id || ""),
          stage: String(eventData.stage || ""),
          completed: Number(eventData.completed) || 0,
          total: Number(eventData.total) || 1
        }
        progressNotice(root.activeProgress)
      }
    }
  }

  function handleResponse(reqId, isError, result, error) {
    var cb = root._pendingCallbacks[reqId]
    var isUrgentCb = cb && cb.isUrgent === true
    if (cb) {
      delete root._pendingCallbacks[reqId]
      if (isUrgentCb && root._pendingUrgentCount > 0) {
        root._pendingUrgentCount--
      }
    }

    // Only clear active if this response matches ordinary in-flight operation
    var activeItem = root._requestQueue.getActive()
    var isOrdinaryActive = (activeItem && activeItem.id === reqId) || (root.activeRequestId === reqId && !isUrgentCb)

    if (isOrdinaryActive) {
      root.activeRequestId = ""
      root.activeOperation = ""
      root.activeProgress = null
      root._requestQueue.clearActive()
    }

    if (isError) {
      var errCode = error ? error.code : "unknown_error"
      var errMsg = error ? error.message : I18n.t("error.generic")
      if (errCode === "not_removable") errMsg = root.tr("error.notRemovable")
      // Forms with an error callback own localized, operation-specific feedback.
      // Keep the hero for otherwise unhandled service failures.
      if (!cb || typeof cb.onError !== "function") root.lastError = errMsg
      if (errCode === "conflict") {
        root.flushQueuedMutations(I18n.t("error.conflict"))
        root.refreshSnapshot()
      }
      root.errorNotice(errCode, errMsg)
      if (cb && typeof cb.onError === "function") {
        cb.onError(error)
      }
    } else {
      if (cb && typeof cb.onDone === "function") {
        cb.onDone(result)
      }
    }

    // Only pump queue if ordinary active operation completed
    if (isOrdinaryActive) {
      // Mutation results are captured while backend busy=true; their terminal
      // response means that this serialized operation has finished.
      if (!isError) root.busy = false
      root.pumpQueue()
    }
  }

  function applySnapshot(data) {
    var norm = Model.normalizeSnapshot(data)
    root.state = norm.state
    root.revision = norm.revision
    root.backendVersion = norm.backendVersion
    root.activeServer = norm.activeServer
    root.routingMode = norm.routingMode
    root.routingAppsMode = norm.routingAppsMode
    root.configMode = norm.configMode
    root.busy = norm.busy
    root.errorCode = norm.errorCode || ""
    root.capabilities = norm.capabilities
    root.unavailableReason = norm.unavailableReason
    root.unavailableReasonCode = norm.unavailableReasonCode || null
  }

  // ---- Dispatch and Queue ---------------------------------------------------
  function sendRequest(method, params, onDone, onError, isUrgent, customTimeoutMs) {
    var reqId = Protocol.generateRequestId("req")
    var hasRevision = false
    var originalParams = {}
    if (params && typeof params === "object") {
      for (var k in params) {
        if (k === "revision") {
          hasRevision = true
        } else {
          originalParams[k] = params[k]
        }
      }
    }

    var timeoutDuration = customTimeoutMs || root.requestDeadlineMs

    if (isUrgent) {
      // Bound urgent callback count
      if (root._pendingUrgentCount >= root.maxUrgentPending) {
        var queueFullErr = { code: "queue_full", message: I18n.t("error.queueFull") }
        root.lastError = queueFullErr.message
        if (onError) onError(queueFullErr)
        return null
      }

      var urgentFormatted = Protocol.formatRequest(method, originalParams, reqId)
      if (!urgentFormatted.ok) {
        if (onError) onError({ code: "format_error", message: I18n.t("error.format") })
        return null
      }

      root._pendingUrgentCount++
      root._pendingCallbacks[reqId] = {
        onDone: onDone,
        onError: onError,
        method: method,
        isUrgent: true,
        deadline: Date.now() + timeoutDuration
      }

      if (fakeBackend) {
        if (typeof fakeBackend.write === "function") fakeBackend.write(urgentFormatted.text)
        else if (typeof fakeBackend === "function") fakeBackend(urgentFormatted.text)
        return reqId
      } else if (backendProc.running) {
        backendProc.write(urgentFormatted.text)
        return reqId
      } else {
        root._pendingUrgentCount--
        delete root._pendingCallbacks[reqId]
        if (onError) onError({ code: "not_running", message: I18n.t("backend.notRunning") })
        return null
      }
    }

    var item = {
      id: reqId,
      method: method,
      params: originalParams,
      needsRevision: hasRevision,
      onDone: onDone,
      onError: onError,
      isUrgent: false,
      timeoutMs: timeoutDuration
    }

    var qRes = root._requestQueue.enqueue(item)
    if (!qRes.ok) {
      if (onError) onError({ code: qRes.error, message: I18n.t("error.queueFull") })
      return null
    }

    root.pumpQueue()
    return item.id
  }

  function pumpQueue() {
    if (!backendProc.running && !fakeBackend) return
    var next = root._requestQueue.dequeueNext()
    if (!next) return

    root.activeRequestId = next.id
    root.activeOperation = next.method

    var dispatchParams = {}
    if (next.params) {
      for (var k in next.params) {
        dispatchParams[k] = next.params[k]
      }
    }
    if (next.needsRevision) {
      dispatchParams.revision = root.revision
    }

    var reqResult = Protocol.formatRequest(next.method, dispatchParams, next.id)
    if (!reqResult.ok) {
      root.activeRequestId = ""
      root.activeOperation = ""
      root._requestQueue.clearActive()
      if (next.onError) next.onError({ code: "format_error", message: I18n.t("error.format") })
      root.pumpQueue()
      return
    }

    root._pendingCallbacks[next.id] = {
      onDone: next.onDone,
      onError: next.onError,
      method: next.method,
      isUrgent: false,
      deadline: Date.now() + (next.timeoutMs || root.requestDeadlineMs)
    }

    if (fakeBackend) {
      if (typeof fakeBackend.write === "function") fakeBackend.write(reqResult.text)
      else if (typeof fakeBackend === "function") fakeBackend(reqResult.text)
    } else {
      backendProc.write(reqResult.text)
    }
  }

  // ---- Public API Actions ---------------------------------------------------

  function refreshSnapshot(onDone, onError) {
    return sendRequest("snapshot", {}, function(res) {
      if (!res || typeof res.state !== "string" || typeof res.revision !== "string" ||
          !res.capabilities || typeof res.capabilities.connect !== "boolean") {
        root.lastError = I18n.t("error.protocol")
        if (onError) onError({ code: "invalid_snapshot", message: root.lastError })
        return
      }
      applySnapshot(res)
      root.retryCount = 0
      root.retryBackoffMs = 2000
      root.lastError = ""
      if (onDone) onDone(res)
    }, onError)
  }

  function connect(onDone, onError) {
    if (!root.capabilities || !root.capabilities.connect) {
      var msg = Model.unavailableText(root, ({ t: root.tr }))
      root.lastError = msg
      root.errorNotice("capability_unavailable", msg)
      if (onError) onError({ code: "capability_unavailable", message: msg })
      return null
    }
    return sendRequest("connect", { revision: root.revision }, function(res) {
      applySnapshot(res)
      if (onDone) onDone(res)
    }, onError)
  }

  function disconnect(onDone, onError) {
    // Flush unsafe queued mutations on disconnect
    root.flushQueuedMutations(I18n.t("error.cancelled"))
    return sendRequest("disconnect", {}, function(res) {
      applySnapshot(res)
      if (onDone) onDone(res)
    }, onError, true)
  }

  function cancel(targetId) {
    var idToCancel = targetId || root.activeRequestId
    if (!idToCancel) return null
    return sendRequest("cancel", { id: idToCancel }, function(res) {
      // The target stays pending until its terminal response arrives.
      if (res && res.cancelled === true) root.activeProgress = null
    }, null, true)
  }

  // Servers
  function listServers(offset, limit, onDone, onError) {
    return sendRequest("servers.list", { offset: offset || 0, limit: limit || 100 }, function(res) {
      root.servers = (res && res.items) ? res.items : []
      root.serversLoaded = true
      root.serversTotal = (res && res.total) ? res.total : root.servers.length
      if (onDone) onDone(root.servers)
    }, onError)
  }

  function selectServer(id, onDone, onError) {
    return sendRequest("servers.select", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listServers()
      if (onDone) onDone(res)
    }, onError)
  }

  function importServers(text, onDone, onError) {
    return sendRequest("servers.import", { revision: root.revision, text: text }, function(res) {
      applySnapshot(res)
      listServers()
      if (onDone) onDone(res)
    }, onError)
  }

  function removeServer(id, onDone, onError) {
    return sendRequest("servers.remove", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listServers()
      if (onDone) onDone(res)
    }, onError)
  }

  function testServer(id, onDone, onError) {
    return sendRequest("servers.test", { id: id }, function(res) {
      if (res && res.id) {
        var copy = root.servers.slice()
        for (var i = 0; i < copy.length; i++) {
          if (copy[i].id === res.id) {
            copy[i].latencyMs = res.latencyMs
            break
          }
        }
        root.servers = copy
      }
      if (onDone) onDone(res)
    }, onError)
  }

  function verifyServer(id, onDone, onError) {
    root.serverVerification = null
    return sendRequest("servers.verify", { id: id }, function(res) {
      root.serverVerification = res
      if (onDone) onDone(res)
    }, function(err) {
      root.serverVerification = { id: id, ok: false, error: err.message }
      if (onError) onError(err)
    })
  }

  // Subscriptions
  function listSubscriptions(offset, limit, onDone, onError) {
    return sendRequest("subscriptions.list", { offset: offset || 0, limit: limit || 100 }, function(res) {
      root.subscriptions = (res && res.items) ? res.items : []
      root.subscriptionsLoaded = true
      root.subscriptionsTotal = (res && res.total) ? res.total : root.subscriptions.length
      if (onDone) onDone(root.subscriptions)
    }, onError)
  }

  function addSubscription(name, url, onDone, onError) {
    return sendRequest("subscriptions.add", { revision: root.revision, name: name, url: url }, function(res) {
      applySnapshot(res)
      listSubscriptions()
      if (onDone) onDone(res)
    }, onError)
  }

  function removeSubscription(id, onDone, onError) {
    return sendRequest("subscriptions.remove", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listSubscriptions()
      if (onDone) onDone(res)
    }, onError)
  }

  function refreshSubscription(id, onDone, onError) {
    var params = { revision: root.revision }
    if (id) params.id = id
    return sendRequest("subscriptions.refresh", params, function(res) {
      applySnapshot(res)
      listSubscriptions()
      listServers()
      if (onDone) onDone(res)
    }, onError)
  }

  function enableSubscription(id, enabled, onDone, onError) {
    return sendRequest("subscriptions.enable", { revision: root.revision, id: id, enabled: enabled }, function(res) {
      applySnapshot(res)
      listSubscriptions()
      if (onDone) onDone(res)
    }, onError)
  }

  // Free Pool
  function listFree(offset, limit, onDone, onError) {
    return sendRequest("free.list", { offset: offset || 0, limit: limit || 100 }, function(res) {
      root.freeServers = (res && res.items) ? res.items : []
      root.freeTotal = (res && res.total) ? res.total : root.freeServers.length
      if (onDone) onDone(root.freeServers)
    }, onError)
  }

  function refreshFree(onDone, onError) {
    return sendRequest("free.refresh", {}, function(res) {
      listFree()
      if (onDone) onDone(res)
    }, onError)
  }

  function testFree(id, onDone, onError) {
    return sendRequest("free.test", { id: id }, function(res) {
      if (res && res.id) {
        var copy = root.freeServers.slice()
        for (var i = 0; i < copy.length; i++) {
          if (copy[i].id === res.id) {
            copy[i].latencyMs = res.latencyMs
            break
          }
        }
        root.freeServers = copy
      }
      if (onDone) onDone(res)
    }, onError)
  }

  function verifyFree(id, onDone, onError) {
    root.freeVerification = null
    return sendRequest("free.verify", { id: id }, function(res) {
      root.freeVerification = res
      if (onDone) onDone(res)
    }, function(err) {
      root.freeVerification = { id: id, ok: false, error: err.message }
      if (onError) onError(err)
    })
  }

  function applyFree(id, onDone, onError) {
    return sendRequest("free.apply", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listServers()
      if (onDone) onDone(res)
    }, onError)
  }

  // Apps & Routing
  function getApps(onDone, onError) {
    return sendRequest("apps.list", {}, function(res) {
      root.apps = {
        include: (res && res.include) ? res.include : [],
        exclude: (res && res.exclude) ? res.exclude : [],
        running: (res && res.running) ? res.running : [],
        runningApps: res && Array.isArray(res.runningApps) ? res.runningApps : null
      }
      root.appsLoaded = true
      if (onDone) onDone(root.apps)
    }, onError)
  }

  function setApps(mode, names, onDone, onError) {
    return sendRequest("apps.set", { revision: root.revision, mode: mode, names: names }, function(res) {
      applySnapshot(res)
      getApps()
      if (onDone) onDone(res)
    }, onError)
  }

  function setRouting(routingMode, routingAppsMode, onDone, onError) {
    return sendRequest("routing.set", {
      revision: root.revision,
      routingMode: routingMode,
      routingAppsMode: routingAppsMode
    }, function(res) {
      applySnapshot(res)
      if (onDone) onDone(res)
    }, onError)
  }

  // Profiles
  function listProfiles(onDone, onError) {
    return sendRequest("profiles.list", {}, function(res) {
      root.profiles = (res && res.items) ? res.items : []
      if (onDone) onDone(root.profiles)
    }, onError)
  }

  function selectProfiles(ids, onDone, onError) {
    return sendRequest("profiles.select", { revision: root.revision, ids: ids }, function(res) {
      applySnapshot(res)
      listProfiles()
      if (onDone) onDone(res)
    }, onError)
  }

  function refreshProfiles(onDone, onError) {
    return sendRequest("profiles.refresh", {}, function(res) {
      listProfiles()
      if (onDone) onDone(res)
    }, onError)
  }

  // Rules
  function getRules(onDone, onError) {
    return sendRequest("rules.get", {}, function(res) {
      root.rules = {
        text: (res && res.text) ? res.text : "",
        priority: (res && res.priority) ? res.priority : "toggles_first"
      }
      if (onDone) onDone(root.rules)
    }, onError)
  }

  function setRules(text, priority, onDone, onError) {
    return sendRequest("rules.set", {
      revision: root.revision,
      text: text,
      priority: priority
    }, function(res) {
      applySnapshot(res)
      getRules()
      if (onDone) onDone(res)
    }, onError)
  }

  function importRules(text, format, onDone, onError) {
    return sendRequest("rules.import", {
      revision: root.revision,
      text: text,
      format: format || "json"
    }, function(res) {
      applySnapshot(res)
      getRules()
      if (onDone) onDone(res)
    }, onError)
  }

  function exportRules(format, onDone, onError) {
    return sendRequest("rules.export", { format: format || "json" }, function(res) {
      if (onDone) onDone(res ? res.text : "")
    }, onError)
  }

  // Custom Configurations
  function listCustom(onDone, onError) {
    return sendRequest("custom.list", {}, function(res) {
      root.customConfigs = (res && res.items) ? res.items : []
      if (onDone) onDone(root.customConfigs)
    }, onError)
  }

  function importCustom(name, text, onDone, onError) {
    return sendRequest("custom.import", {
      revision: root.revision,
      name: name,
      text: text
    }, function(res) {
      applySnapshot(res)
      listCustom()
      if (onDone) onDone(res)
    }, onError)
  }

  function selectCustom(id, onDone, onError) {
    return sendRequest("custom.select", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listCustom()
      if (onDone) onDone(res)
    }, onError)
  }

  function removeCustom(id, onDone, onError) {
    return sendRequest("custom.remove", { revision: root.revision, id: id }, function(res) {
      applySnapshot(res)
      listCustom()
      if (onDone) onDone(res)
    }, onError)
  }

  // Settings
  function getSettings(onDone, onError) {
    return sendRequest("settings.get", {}, function(res) {
      if (res) {
        root.settingsData = {
          mtu: res.mtu !== undefined ? res.mtu : 1420,
          ipv6Enabled: res.ipv6Enabled === true,
          strictRoute: res.strictRoute === true,
          strictDns: res.strictDns === true,
          dnsMode: res.dnsMode || "vpn_only",
          dnsModeOverride: res.dnsModeOverride !== undefined ? res.dnsModeOverride : (res.dnsMode || "vpn_only"),
          dnsModeSemantics: res.dnsModeSemantics || null,
          bypassRussianTraffic: res.bypassRussianTraffic !== false,
          blockAds: res.blockAds === true,
          dnsLeakLockdown: res.dnsLeakLockdown === true,
          routeExcludeAddress: Array.isArray(res.routeExcludeAddress) ? res.routeExcludeAddress : []
        }
      }
      if (onDone) onDone(root.settingsData)
    }, onError)
  }

  function setSettings(values, onDone, onError) {
    return sendRequest("settings.set", {
      revision: root.revision,
      values: values
    }, function(res) {
      applySnapshot(res)
      getSettings()
      if (onDone) onDone(res)
    }, onError)
  }

  // Diagnostics
  function checkDiagnostics(onDone, onError) {
    return sendRequest("diagnostics.check", {}, function(res) {
      root.diagnosticsItems = (res && res.items) ? res.items : []
      if (onDone) onDone(root.diagnosticsItems)
    }, onError)
  }

  function exportDiagnostics(onDone, onError) {
    root.diagnosticsExportPath = ""
    return sendRequest("diagnostics.export", {}, function(res) {
      root.diagnosticsExportPath = (res && res.path) ? res.path : ""
      if (onDone) onDone(root.diagnosticsExportPath)
    }, onError)
  }
}
