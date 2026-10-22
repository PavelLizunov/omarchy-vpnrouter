// OFFSCREEN TEST FIXTURE ONLY. Real Service/locales; inert responses, no backend process.
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
 property string tab: "servers"
 property string scenario: "empty"
 property bool missingService: false
 property bool previewReady: false
 property bool runInteractions: false
 property bool scrollBottom: false
 property string appQuery: ""
 property var result: ({})
 property var messages: []
 property var selectedApps: scenario === "populated" ? ["chromium"] : []
 function find(item, predicate) {
   if (predicate(item)) return item
   var children = item.children || []
   for (var i = 0; i < children.length; i++) { var found = find(children[i], predicate); if (found) return found }
   return null
 }
 function all(item, predicate, list) {
   if (predicate(item)) list.push(item)
   var children = item.children || []
   for (var i = 0; i < children.length; i++) all(children[i], predicate, list)
   return list
 }
 function respond(line) {
   var request = JSON.parse(line)
   messages.push(request.method)
   var res = ({})
   switch (request.method) {
   case "snapshot": res = {state:"disconnected", revision:"fixture", capabilities:{connect:false}, unavailableReasonCode:"runtime-capabilities"}; break
   case "servers.list": res = {items: scenario === "populated" ? [
     {id:"manual",name:"Manual fixture", protocol:"vless", source:"manual", removable:true},
     {id:"sub",name:"Subscription fixture with a very long display name to test clipping", protocol:"shadowsocks", source:"subscription",subscriptionId:"one",removable:false},
     {id:"legacy",name:"Legacy source unknown",protocol:"wireguard"} ] : [], total:scenario === "populated" ? 3 : 0}; break
   case "subscriptions.list": res = {items: scenario === "populated" ? [{id:"one",name:"Example subscription (fixture)",serverCount:1,enabled:true}] : [], total:scenario === "populated" ? 1 : 0}; break
   case "apps.list": res = {include:fixture.selectedApps, exclude:[], running:["systemd","pipewire","firefox"]};
     if (scenario !== "legacy") res.runningApps = scenario === "populated" ? [
       {name:"chromium",displayName:"Chromium",icon:"chromium",desktopId:"chromium.desktop",hasWindow:true},
       {name:"steam",displayName:"Steam",icon:"steam",desktopId:"steam.desktop"},
       {name:"very-long-process-name-for-elision",displayName:"An unusually long application name for clipping review",desktopId:"fixture.desktop",icon:"vpnrouter-fixture-icon-does-not-exist"},
       {name:"systemd",displayName:"Must never be visible"}] : [];
     break
   case "apps.set": fixture.selectedApps = request.params.names; res = {state:"disconnected",revision:"fixture",capabilities:{connect:false}}; break
   case "profiles.list": res = {items:[]}; break
   case "rules.get": res = {text:"",priority:"toggles_first"}; break
   case "settings.get": res = {mtu:1420,ipv6Enabled:false,strictRoute:false,strictDns:false,dnsMode:"vpn_only",bypassRussianTraffic:true,blockAds:false,routeExcludeAddress:[]}; break
   case "diagnostics.check": res = {items:[{name:"HealthCheck",status:"info",message:"Not configured yet: add a subscription or a server"},{name:"HealthCheck",status:"ok",message:"Fixture: runtime check passed"},{name:"HealthCheck",status:"warn",message:"Fixture: warning retained"},{name:"HealthCheck",status:"error",message:"Fixture: error retained"},{name:"HealthCheck",status:"future",message:"Fixture: unknown severity"}]}; break
   default:
     if (!/^(free.list|custom.list)$/.test(request.method)) { console.error("UNEXPECTED FIXTURE REQUEST",request.method); return }
     res = {items:[],total:0}
   }
   Qt.callLater(function() { service.feedFrame({type:"response",id:request.id,isError:false,result:res}) })
 }
 Vpn.Service { id: service; processDisabled: true; fakeBackend: fixture.respond }
 Vpn.Panel { id: consumer; objectName: "consumer"; width: parent.width; height: parent.height; mode: "advanced"; service: service }
 Timer {
   interval: 60; running: true
   onTriggered: {
     service.setLocale(fixture.locale)
     consumer.currentTab = fixture.tab
     consumer.open()
     service.getApps()
     service.listServers()
     service.listSubscriptions()
   }
 }
 Timer {
   interval: 220; running: true
   onTriggered: {
     var form = fixture.find(consumer,function(x) {return x.showAddForm !== undefined})
     if (fixture.scenario === "form") consumer.openSubscriptionForm()
     if (fixture.appQuery) { var apps = fixture.find(consumer,function(x) {return x.runningApps !== undefined && x.searchQuery !== undefined}); apps.searchQuery = fixture.appQuery }
     if (fixture.scenario === "bottom" || fixture.scrollBottom) {
       var viewport = fixture.find(consumer,function(x) {return x.objectName === "vpnContentViewport"})
       viewport.contentY = Math.max(0,viewport.contentHeight-viewport.height)
     }
     if (fixture.missingService) { service.backendMissing = true; service.state = "unavailable"; service.unavailableReasonCode = null }
     if (!fixture.runInteractions) readyTimer.start()
     else { try { test.test_interactions() } catch(e) { console.error("R4_NATIVE_FAIL", String(e)); fixture.previewReady = true } }
   }
 }
 Timer { id: readyTimer; interval: 180; onTriggered: {
   if (fixture.scenario === "populated") {
     var icon = fixture.find(consumer,function(x) {return x.objectName === "vpnAppIcon-chromium"})
     var fallback = fixture.find(consumer,function(x) {return x.objectName === "vpnAppIcon-very-long-process-name-for-elision"})
     if (!icon || icon.status !== Image.Ready || String(icon.source) === Quickshell.iconPath("application-x-executable",true)) { console.error("R4B_ICON_FAIL");return }
     if (!fallback || fallback.status !== Image.Ready || String(fallback.source) !== Quickshell.iconPath("application-x-executable",true)) { console.error("R4B_FALLBACK_FAIL", fallback ? String(fallback.source) : "null", Quickshell.iconPath("application-x-executable",true), fallback ? fallback.status : -1);return }
     console.log("R4B_ICONS", String(icon.source), String(fallback.source))
   }
   var hero = fixture.find(consumer,function(x) {return x.addSubscriptionRequested !== undefined && x.connectRequested !== undefined})
   var heroViewport = fixture.find(hero,function(x) {return x.objectName === "vpnHeroViewport"})
   var page = fixture.find(consumer,function(x) {return x.objectName === "vpnContentViewport"})
   if (Math.abs(hero.height - Math.min(Commons.Style.space(176),heroViewport.contentHeight + Commons.Style.space(24))) > 0.1) { console.error("R4B_HERO_FAIL");return }
   var connect = fixture.find(hero,function(x) {return x.text === service.tr("action.connect") && x.clicked !== undefined})
   if (connect && (connect.enabled || connect.opacity !== 0.4 || connect.borderColor !== Commons.Style.normalBorderColor || connect.activeFocusOnTab)) { console.error("R4B_DISABLED_FAIL");return }
   console.log("R4B_LAYOUT",JSON.stringify({heroHeight:hero.height,heroContent:heroViewport.contentHeight,pageHeight:page.height,disabled:connect ? !connect.enabled : null}))
   fixture.previewReady = true
 } }
 TestCase {
   id: test
   name: "VPNRouterR4Native"
   when: false
   function test_interactions() {
     wait(350)
     var frame = fixture.find(consumer,function(x) {return x.contentWidth !== undefined && x.availableHeight !== undefined})
     var nav = fixture.find(consumer,function(x) {return x.tabSelected !== undefined})
     var hero = fixture.find(consumer,function(x) {return x.addSubscriptionRequested !== undefined && x.connectRequested !== undefined})
     var start = [frame.x,frame.y,frame.width,frame.height,nav.x,nav.y,hero.x,hero.y,hero.width,hero.height]
     var tabs = ["servers","subscriptions","free","apps","profiles","rules","custom","settings","diagnostics","servers"]
     for (var i=0;i<tabs.length;i++) {
       nav.tabSelected(tabs[i]);wait(30)
       compare(JSON.stringify([frame.x,frame.y,frame.width,frame.height,nav.x,nav.y,hero.x,hero.y,hero.width,hero.height]),JSON.stringify(start),"Shared geometry: " + tabs[i])
     }
     if (fixture.scenario === "populated") {
       var disabledConnect = fixture.find(hero,function(x) {return x.text === service.tr("action.connect") && x.clicked !== undefined})
       verify(disabledConnect !== null && !disabledConnect.enabled)
       var beforeDisabledClick = fixture.messages.length
       mouseClick(disabledConnect); wait(30)
       compare(fixture.messages.length,beforeDisabledClick,"Disabled Connect cannot send a request")
       verify(!disabledConnect.activeFocusOnTab,"Disabled Connect is skipped by Tab")
     }
     service.lastError = "Fixture error text that wraps across several lines and should scroll inside the hero instead of shifting the navigation."
     service.busy = true
     wait(30)
     compare(JSON.stringify([frame.x,frame.y,frame.width,frame.height]),JSON.stringify(start.slice(0,4)),"Loading/error frame geometry")
     verify(hero.height <= Commons.Style.space(176),"Long hero content stays capped")
     service.lastError = ""; service.busy = false; wait(30)
     if (fixture.scenario === "populated") {
       nav.tabSelected("apps"); wait(50)
       var apps = fixture.find(consumer,function(x) {return x.runningApps !== undefined && x.searchQuery !== undefined})
       compare(apps.runningApps.length,3,"Daemon filtered")
       var add = fixture.find(apps,function(x) {return x.text === service.tr("action.add") && x.selected === false})
       verify(add !== null)
       add.forceActiveFocus(); wait(40)
       keyClick(Qt.Key_Return); wait(60)
       verify(service.apps.include.indexOf("steam") !== -1,"Exact process selected through keyboard")
       var remove = fixture.find(apps,function(x) {return x.tooltipText === service.tr("apps.removeApp",["chromium"])})
       verify(remove !== null)
       remove.forceActiveFocus(); wait(40)
       keyClick(Qt.Key_Space); wait(60)
       verify(service.apps.include.indexOf("chromium") === -1,"Selected app removed")
       var search = fixture.find(apps,function(x) {return x.placeholderText === service.tr("apps.searchPlaceholder")})
       search.forceActiveFocus(); wait(20)
       keyClick(Qt.Key_S); keyClick(Qt.Key_T); keyClick(Qt.Key_E); keyClick(Qt.Key_A); keyClick(Qt.Key_M); wait(30)
       compare(apps.runningApps.length,1,"Live search narrows suggestions")
       compare(apps.runningApps[0].name,"steam")
     }
     // Real signal route from hero -> panel -> subscriptions -> form, then key traversal.
     if (fixture.scenario === "empty") {
       var cta = fixture.find(hero,function(x) {return x.text === service.tr("firstRun.addSubscription") && x.clicked !== undefined})
       verify(cta !== null)
       mouseClick(cta); wait(40)
     } else { hero.addSubscriptionRequested();wait(40) }
     compare(consumer.currentTab,"subscriptions")
     var form = fixture.find(consumer,function(x) {return x.showAddForm !== undefined})
     verify(form.showAddForm)
     var fields = fixture.all(form,function(x) {return x.isPassword !== undefined},[])
     compare(fields.length,2)
     fields[0].forceActiveFocus();wait(20)
     keyClick(Qt.Key_Tab);wait(20)
     verify(fields[1].activeFocus,"Tab must move from Name to URL")
     // Empty Enter does not submit, even through real Qt input dispatch.
     keyClick(Qt.Key_Return);wait(20)
     verify(form.showAddForm)
     var before = fixture.messages.length
     keyClick(Qt.Key_Escape);wait(20)
     verify(!consumer.opened,"Escape from a focused field closes the actual Panel")
     compare(fixture.messages.length,before)
     fixture.result = {geometry:start,tabs:tabs,tabTraversal:true,emptyEnter:true,escapeClosed:true,appsInteraction:fixture.scenario === "populated",requests:fixture.messages}
     console.log("R4_NATIVE_RESULT",JSON.stringify(fixture.result))
     fixture.previewReady = true
   }
 }
}
