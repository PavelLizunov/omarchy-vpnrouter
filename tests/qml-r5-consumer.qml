// OFFSCREEN FIXTURE: actual Panel/Service/locales, inert backend and window records.
import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import ".." as Vpn
Rectangle {
  id: fixture
  width: 540; height: 640
  color: Commons.Color.background
  property string locale: "en"
  property string scenario: "populated"
  property bool scrollBottom: false
  property real scrollOffset: 0
  property bool runInteractions: false
  property bool previewReady: false
  property var selectedApps: ["chromium"]
  property var windows: []
  property var messages: []
  property var appsView: null
  function find(item, predicate) {
    if (predicate(item)) return item
    var children = item.children || []
    for (var i = 0; i < children.length; i++) {
      var found = find(children[i], predicate)
      if (found) return found
    }
    return null
  }
  function respond(line) {
    var request = JSON.parse(line)
    fixture.messages.push(request.method)
    var result = ({})
    switch (request.method) {
    case "snapshot": result = {state:"disconnected",revision:"fixture",capabilities:{connect:false},unavailableReasonCode:"runtime-capabilities"}; break
    case "servers.list": result = {items:[{id:"fixture",name:"Fixture server",protocol:"vless",source:"manual",removable:true}],total:1}; break
    case "subscriptions.list": result = {items:[],total:0}; break
    case "apps.list":
      result = {include:fixture.selectedApps,exclude:[],running:["bash","cat","chromium"]}
      if (fixture.scenario !== "legacy") result.runningApps = [
        {name:"chatgpt",displayName:"ChatGPT",icon:"chatgpt",desktopId:"chatgpt.desktop"},
        {name:"chromium",displayName:"Chromium",icon:"chromium",desktopId:"chromium.desktop"},
        {name:"com.discordapp.Discord",displayName:"Discord",icon:"com.discordapp.Discord",desktopId:"com.discordapp.Discord.desktop"},
        {name:"dropbox",displayName:"Dropbox",icon:"dropbox",desktopId:"dropbox.desktop"},
        {name:"nvim",displayName:"Neovim",icon:"nvim",desktopId:"nvim.desktop"},
        {name:"thunderbird",displayName:"Thunderbird",icon:"org.mozilla.Thunderbird",desktopId:"org.mozilla.Thunderbird.desktop"},
        {name:"bash"},{name:"cat"},{name:"at-spi-bus-launcher"},{name:"codex"},{name:"bwrap"}
      ]
      break
    case "apps.set": fixture.selectedApps = request.params.names; result = {state:"disconnected",revision:"fixture",capabilities:{connect:false},unavailableReasonCode:"runtime-capabilities"}; break
    case "settings.get": result = {mtu:1420}; break
    case "rules.get": result = {text:"",priority:"toggles_first"}; break
    default:
      if (!/^(profiles.list|free.list|custom.list)$/.test(request.method)) throw new Error("Unexpected fixture request: " + request.method)
      result = {items:[],total:0}
    }
    Qt.callLater(function() { backendService.feedFrame({type:"response",id:request.id,isError:false,result:result}) })
  }
  Vpn.Service { id: backendService; processDisabled: true; fakeBackend: fixture.respond }
  Vpn.Panel { id: consumer; objectName: "consumer"; width: parent.width; height: parent.height; mode: "advanced"; service: backendService }
  Timer {
    interval: 60; running: true
    onTriggered: {
      backendService.setLocale(fixture.locale)
      consumer.currentTab = "apps"
      consumer.open()
      backendService.getApps(); backendService.listServers(); backendService.listSubscriptions()
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      fixture.appsView = fixture.find(consumer,function(x) { return x.otherProcessesExpanded !== undefined })
      if (!fixture.appsView || !backendService.appsLoaded) throw new Error("Apps consumer did not load")
      fixture.appsView.windowToplevels = Qt.binding(function() { return fixture.windows })
      if (fixture.runInteractions) {
        try { checks.test_apps() } catch(e) { console.error("R5_NATIVE_FAIL",String(e),e.stack); return }
      }
      if (fixture.scenario === "expanded") fixture.appsView.otherProcessesExpanded = true
      if (fixture.scenario === "search") {
        var search = fixture.find(fixture.appsView,function(x) { return x.placeholderText === backendService.tr("apps.searchPlaceholder") })
        search.text = "codex"
      }
      settled.start()
    }
  }
  Timer {
    id: settled; interval: 150
    onTriggered: {
      var viewport = fixture.find(consumer,function(x) { return x.objectName === "vpnContentViewport" })
      if (fixture.scrollBottom) viewport.contentY = Math.max(0,viewport.contentHeight-viewport.height)
      else viewport.contentY = Math.min(fixture.scrollOffset,Math.max(0,viewport.contentHeight-viewport.height))
      console.log("R5_READY",JSON.stringify({apps:fixture.appsView.runningApps.length,other:fixture.appsView.otherProcesses.length,expanded:fixture.appsView.otherProcessesExpanded,contentHeight:viewport.contentHeight,pageHeight:viewport.height}))
      fixture.previewReady = true
    }
  }
  TestCase {
    id: checks
    name: "VPNRouterR5Apps"
    when: false
    function test_apps() {
      wait(40)
      var apps = fixture.appsView
      var frame = fixture.find(consumer,function(x) { return x.contentWidth !== undefined && x.availableHeight !== undefined })
      var nav = fixture.find(consumer,function(x) { return x.tabSelected !== undefined })
      var geometry = JSON.stringify([frame.x,frame.y,frame.width,frame.height,nav.x,nav.y])
      compare(apps.runningApps.length,6)
      compare(apps.otherProcesses.length,5)
      verify(!apps.otherProcessesExpanded)
      verify(fixture.find(apps,function(x) { return x.objectName === "vpnAppIcon-codex" }) === null,"Collapsed processes have no row")
      var disclosure = fixture.find(apps,function(x) { return x.objectName === "vpnOtherProcessesToggle" })
      var lastApp = fixture.find(apps,function(x) { return x.objectName === "vpnAppRow-thunderbird" })
      console.log("R5_ROW_GEOMETRY",lastApp.y,lastApp.height,disclosure.y)
      verify(disclosure.y >= lastApp.y + lastApp.height,"Process disclosure must follow the last app without overlap")
      disclosure.forceActiveFocus(); wait(30); keyClick(Qt.Key_Return); wait(30)
      verify(apps.otherProcessesExpanded,"Return expands processes")
      verify(fixture.find(apps,function(x) { return x.objectName === "vpnAppIcon-codex" }) !== null)
      keyClick(Qt.Key_Space); wait(30)
      verify(!apps.otherProcessesExpanded,"Space collapses processes")
      mouseClick(disclosure); wait(30)
      verify(apps.otherProcessesExpanded,"Pointer expands processes")
      mouseClick(disclosure); wait(30)
      verify(!apps.otherProcessesExpanded,"Pointer collapses processes")
      var search = fixture.find(apps,function(x) { return x.placeholderText === backendService.tr("apps.searchPlaceholder") })
      search.forceActiveFocus(); keyClick(Qt.Key_C); keyClick(Qt.Key_O); keyClick(Qt.Key_D); keyClick(Qt.Key_E); keyClick(Qt.Key_X); wait(40)
      compare(apps.runningApps.length,0)
      compare(apps.otherProcesses.length,1)
      verify(apps.otherProcessesExpanded,"Search reveals a previously collapsed process")
      var add = fixture.find(apps,function(x) { return x.selected === false && x.clicked !== undefined && x.variant !== undefined })
      verify(add !== null)
      add.forceActiveFocus(); wait(30); keyClick(Qt.Key_Return); wait(70)
      verify(backendService.apps.include.indexOf("codex") !== -1,"A process search result can be selected")
      var remove = fixture.find(apps,function(x) { return x.tooltipText === backendService.tr("apps.removeApp",["codex"]) })
      remove.forceActiveFocus(); wait(30); keyClick(Qt.Key_Space); wait(70)
      verify(backendService.apps.include.indexOf("codex") === -1)
      search.clear(); wait(30)
      verify(!apps.otherProcessesExpanded)
      fixture.windows = [{lastIpcObject:{class:"CODEX"}}]; wait(30)
      compare(apps.runningApps.length,7,"Opening window promotes process")
      verify(apps.runningApps.some(function(app) { return app.name === "codex" && app.hasWindow }))
      fixture.windows = []; wait(30)
      compare(apps.runningApps.length,6,"Closing window demotes process")
      fixture.windows = [{wayland:{appId:"codex"}}]; wait(30)
      compare(apps.runningApps.length,7,"Wayland appId fallback is reactive")
      fixture.windows = []; wait(30)
      var manual = fixture.find(apps,function(x) { return x.placeholderText === backendService.tr("apps.customAppPlaceholder") })
      manual.text = "CustomCaseApp"; manual.forceActiveFocus(); keyClick(Qt.Key_Return); wait(70)
      verify(backendService.apps.include.indexOf("CustomCaseApp") !== -1,"Manual exact-case process name survives")
      var manualRemove = fixture.find(apps,function(x) { return x.tooltipText === backendService.tr("apps.removeApp",["CustomCaseApp"]) })
      manualRemove.forceActiveFocus(); wait(30); keyClick(Qt.Key_Space); wait(70)
      search.text = "no-such-process"; wait(30)
      compare(apps.runningApps.length + apps.otherProcesses.length,0)
      verify(fixture.find(apps,function(x) { return x.text === backendService.tr("apps.noMatches") && x.visible }) !== null)
      search.clear(); wait(30)
      console.log("R5_GEOMETRY",geometry,JSON.stringify([frame.x,frame.y,frame.width,frame.height,nav.x,nav.y]))
      compare(JSON.stringify([frame.x,frame.y,frame.width,frame.height,nav.x,nav.y]),geometry,"Disclosures/search/window updates preserve frame and nav")
      manual.forceActiveFocus(); keyClick(Qt.Key_Escape); wait(30)
      verify(!consumer.opened,"Escape dismisses panel")
      consumer.open(); wait(40)
      console.log("R5_NATIVE_RESULT",JSON.stringify({geometry:JSON.parse(geometry),disclosureKeys:true,searchHiddenProcess:true,addRemove:true,manualExactCase:true,windowOpenClose:true,waylandFallback:true,noMatches:true,escape:true,requests:fixture.messages}))
    }
  }
}
