// OFFSCREEN ONLY: real consumers and Service/locales; every request is inert.
import QtQuick
import QtTest
import QtQuick.Controls as Controls
import qs.Commons as Commons
import ".." as Vpn
import "../ui" as VpnUi
Rectangle {
  id: fixture
  width: 540; height: 640
  color: Commons.Color.background
  property string locale: "en"
  property string tab: "apps"
  property string suite: ""
  property string capture: ""
  property string theme: "catppuccin-latte"
  property string stateName: "disconnected"
  property int captureDelay: 400
  property int settleDelay: 180
  property bool reducedMotion: false
  property string motionOutputPrefix: ""
  property bool scrollBottom: false
  property var controlOverlay: Controls.Overlay.overlay
  property bool previewReady: false
  property var messages: []
  property string failNext: ""
  property string holdMethod: ""
  property var held: null
  property var lastParams: ({})
  property string route: "split"
  property string appRule: "include"
  property var includes: ["chromium"]
  property var excludes: ["thunderbird"]
  property string selectedServer: "manual"
  property string selectedProfile: "one"
  property string selectedCustom: "one"
  property string rulesText: "DOMAIN,example.invalid,proxy"
  property string priority: "toggles_first"
  property var savedSettings: ({mtu:1420,ipv6Enabled:false,strictRoute:false,strictDns:false,dnsMode:"vpn_only",bypassRussianTraffic:true,blockAds:false,dnsLeakLockdown:false,routeExcludeAddress:["192.168.0.0/16"]})
  property var subscriptions: [{id:"one",name:"Example subscription (fixture)",serverCount:2,enabled:true}]
  property var servers: [{id:"manual",name:"Frankfurt 1",protocol:"vless",source:"manual",removable:true,latencyMs:42},
                         {id:"sub",name:"Subscription server (fixture)",protocol:"shadowsocks",source:"subscription",subscriptionId:"one",removable:false}]
  property var configs: [{id:"one",name:"Configuration A (fixture)"},{id:"two",name:"Configuration B (fixture)"}]
  property var profiles: [{id:"one",name:"Profile A (fixture)"},{id:"two",name:"Profile B (fixture)"}]
  property var free: [{id:"free",name:"Free server (fixture)",protocol:"vless",latencyMs:null}]
  property var appRecords: [
    {name:"chatgpt",displayName:"ChatGPT",icon:"chatgpt",desktopId:"chatgpt.desktop"},
    {name:"chromium",displayName:"Chromium",icon:"chromium",desktopId:"chromium.desktop"},
    {name:"steam",displayName:"Steam",icon:"steam",desktopId:"steam.desktop"},
    {name:"com.discordapp.Discord",displayName:"Discord",icon:"com.discordapp.Discord",desktopId:"com.discordapp.Discord.desktop"},
    {name:"dropbox",displayName:"Dropbox",icon:"dropbox",desktopId:"dropbox.desktop"},
    {name:"nvim",displayName:"Neovim",icon:"nvim",desktopId:"nvim.desktop"},
    {name:"thunderbird",displayName:"Thunderbird",icon:"org.mozilla.Thunderbird",desktopId:"org.mozilla.Thunderbird.desktop"},
    {name:"bash"},{name:"cat"},{name:"at-spi-bus-launcher"},{name:"codex"},{name:"bwrap"}]
  function find(item, predicate) {
    if (predicate(item)) return item
    var children = item.children || []
    for (var i=0;i<children.length;i++) { var found=find(children[i],predicate); if(found) return found }
    return null
  }
  function all(item, predicate, list) {
    if (predicate(item)) list.push(item)
    var children=item.children || []
    for(var i=0;i<children.length;i++) all(children[i],predicate,list)
    return list
  }
  function snapshot() { return {state:fixture.stateName,revision:"fixture",activeServer:(fixture.servers.find(function(x){return x.id===fixture.selectedServer}) || {name:fixture.selectedServer}).name,routingMode:fixture.route,routingAppsMode:fixture.appRule,configMode:"generated",capabilities:{connect:true}} }
  function complete(request, forcedError) {
    var method=request.method, p=request.params, result=fixture.snapshot(), error=null
    if (forcedError) error={code:"invalid_argument",message:"Fixture rejected input"}
    if (!error) switch(method) {
      case "snapshot": break
      case "servers.list": result={items:fixture.servers.map(function(x) {return Object.assign({},x,{selected:x.id===fixture.selectedServer})}),total:fixture.servers.length};break
      case "servers.select": fixture.selectedServer=p.id;result=fixture.snapshot();break
      case "servers.import": fixture.servers=fixture.servers.concat([{id:"imported",name:"Imported server (fixture)",protocol:"vless",source:"manual",removable:true}]);break
      case "servers.remove": fixture.servers=fixture.servers.filter(function(x){return x.id!==p.id});break
      case "servers.test": result={id:p.id,reachable:true,latencyMs:42};break
      case "servers.verify": result={id:p.id,ok:true,latencyMs:42};break
      case "subscriptions.list": result={items:fixture.subscriptions,total:fixture.subscriptions.length};break
      case "subscriptions.add": fixture.subscriptions=fixture.subscriptions.concat([{id:"added",name:p.name,enabled:true,serverCount:0}]);break
      case "subscriptions.enable": fixture.subscriptions=fixture.subscriptions.map(function(x){return x.id===p.id?Object.assign({},x,{enabled:p.enabled}):x});break
      case "subscriptions.remove": fixture.subscriptions=fixture.subscriptions.filter(function(x){return x.id!==p.id});break
      case "subscriptions.refresh": break
      case "apps.list": result={include:fixture.includes,exclude:fixture.excludes,runningApps:fixture.appRecords};break
      case "apps.set": if(p.mode==="include") fixture.includes=p.names;else fixture.excludes=p.names;break
      case "routing.set": fixture.route=p.routingMode;fixture.appRule=p.routingAppsMode;result=fixture.snapshot();break
      case "profiles.list": result={items:fixture.profiles.map(function(x){return Object.assign({},x,{selected:x.id===fixture.selectedProfile})})};break
      case "profiles.select": fixture.selectedProfile=p.ids[0];break
      case "profiles.refresh": break
      case "rules.get": result={text:fixture.rulesText,priority:fixture.priority};break
      case "rules.set": fixture.rulesText=p.text;fixture.priority=p.priority;break
      case "rules.import": fixture.rulesText="DOMAIN,imported.invalid,proxy";break
      case "rules.export": result={text:p.format==="csv"?"domain,example.invalid,proxy":'{"rules":[]}'};break
      case "settings.get": result=fixture.savedSettings;break
      case "settings.set": fixture.savedSettings=Object.assign({},fixture.savedSettings,p.values);break
      case "custom.list": result={items:fixture.configs.map(function(x){return Object.assign({},x,{selected:x.id===fixture.selectedCustom})})};break
      case "custom.import": fixture.configs=fixture.configs.concat([{id:"imported",name:p.name}]);break
      case "custom.select": fixture.selectedCustom=p.id;break
      case "custom.remove": fixture.configs=fixture.configs.filter(function(x){return x.id!==p.id});break
      case "free.list": result={items:fixture.free,total:fixture.free.length};break
      case "free.refresh": break
      case "free.test": result={id:p.id,reachable:true,latencyMs:42};break
      case "free.verify": result={id:p.id,ok:true,latencyMs:42};break
      case "free.apply": fixture.selectedServer=p.id;break
      case "diagnostics.check": result={items:[{name:"Configuration (fixture)",status:"info",message:"Not configured yet: add a subscription or a server"},{name:"Runtime (fixture)",status:"ok",message:"Fixture: check passed"}]};break
      case "diagnostics.export": result={path:"/tmp/vpnrouter-fixture/very-long-directory-for-export-feedback/diagnostics-2026-10-23-fixture.zip"};break
      default: throw new Error("Unexpected mock request: "+method)
    }
    backend.feedFrame({type:"response",id:request.id,isError:!!error,result:result,error:error})
  }
  function respond(line) {
    var request=JSON.parse(line)
    fixture.messages.push(request.method)
    fixture.lastParams=request.params
    if (fixture.holdMethod===request.method) { fixture.held=request;return }
    var fail=fixture.failNext===request.method
    if(fail) fixture.failNext=""
    Qt.callLater(function(){fixture.complete(request,fail)})
  }
  function release(error) { var request=fixture.held;fixture.held=null;fixture.holdMethod="";fixture.complete(request,error) }
  Vpn.Service { id: backend; processDisabled:true;fakeBackend:fixture.respond }
  Vpn.BarWidget { id: barStateProbe; service: backend; settings: ({locale: fixture.locale}); visible: false }
  Vpn.Panel { id: consumer;objectName:"consumer";width:parent.width;height:parent.height;mode:"advanced";service:backend }
  Timer {
    interval:80;running:true
    onTriggered: {
      Commons.Style.reduceMotion=fixture.reducedMotion
      consumer.mode="advanced"
      backend.setLocale(fixture.locale);consumer.currentTab=fixture.tab;consumer.open();backend.getApps()
      if (fixture.stateName === "unavailable") {backend.backendMissing=true;backend.capabilities={connect:false}}
      if (fixture.stateName === "error") backend.lastError=backend.tr("error.timeout")
      if (fixture.stateName === "connecting") {backend.activeOperation="connect";backend.busy=true}
      var apps=fixture.find(consumer,function(x){return x.objectName==="vpnAppsView"});apps.windowToplevels=[]
    }
  }
  Timer {
    interval:fixture.captureDelay;running:true
    onTriggered: {
      try {
        // Exercise the actual host TOML loaders; never inject a hand-written palette.
        checks.tryVerify(function() { return Commons.Color.colorsFile.loaded }, 2000, "Host palette startup loaded")
        checks.tryVerify(function() { return Commons.Color.shellFile.loaded }, 2000, "Host shell tokens loaded")
        checks.wait(30)
        if(fixture.suite) checks.run()
        checks.prepareCapture()
        checks.wait(fixture.settleDelay)
        if (fixture.stateName === "error") {backend.lastError=backend.tr("error.timeout");checks.wait(20)}
        checks.equal(String(VpnUi.Brand.background), String(Commons.Color.popups.background), "Mascot uses popup luminance")
        console.log("R6_READY",JSON.stringify({suite:fixture.suite,capture:fixture.capture,requests:fixture.messages,geometry:checks.geometry(),theme:fixture.theme,dark:VpnUi.Brand.dark,font:Commons.Style.font.family,background:String(Commons.Color.background),accent:String(Commons.Color.accent),urgent:String(Commons.Color.urgent),muted:String(Commons.Color.muted),popup:String(Commons.Color.popups.background),tokens:Commons.Color.shellValues,arc:fixture.find(consumer,function(x){return x.objectName==="vpnConnectingArc"}).rotation}))
      } catch(e) { console.error("R6_FAIL",fixture.suite,String(e),e.stack) }
      fixture.previewReady=true
    }
  }
  TestCase {
    id: checks
    name:"VPNRouterR6Forms"
    when:false
    function expect(condition,message) {if(!condition) throw new Error(message || "Expectation failed")}
    function equal(actual,expected,message) {if(actual!==expected) throw new Error((message || "Mismatch")+": expected "+JSON.stringify(expected)+", observed "+JSON.stringify(actual))}
    function byName(name) { var x=fixture.find(consumer,function(x){return x.objectName===name && x.visible});expect(x!==null,name);return x }
    function page(name) {return byName("vpn"+name+"View")}
    function button(parent,key) {
      var text=backend.tr(key)
      var x=fixture.find(parent,function(x){return x.visible && x.enabled && x.clicked!==undefined && typeof x.text==="string" && (x.text===text || x.text.endsWith(" "+text))})
      expect(x!==null,"Button "+key);return x
    }
    function field(parent,placeholder) {var x=fixture.find(parent,function(x){return x.placeholderText===backend.tr(placeholder) && x.isPassword!==undefined});expect(x!==null,placeholder);return x}
    function go(tab) {consumer.openSection(tab);byName("vpnContentViewport").contentY=0;wait(35)}
    function focusInput(item) {if(typeof item.focusInput==="function") item.focusInput();else item.forceActiveFocus()}
    function activate(item,key) {focusInput(item);wait(5);keyClick(key || Qt.Key_Return);wait(45)}
    function click(item) {item.forceActiveFocus();wait(5);mouseClick(item);wait(45)}
    function fill(item,text) {item.text=text;focusInput(item);wait(5)}
    function count(method) {return fixture.messages.filter(function(m){return m===method}).length}
    function geometry() {
      var frame=fixture.find(consumer,function(x){return x.contentWidth!==undefined && x.availableHeight!==undefined})
      var nav=fixture.find(consumer,function(x){return x.objectName==="vpnSectionHeader"})
      return [frame.x,frame.y,frame.width,frame.height,nav.x,nav.y]
    }
    function visibleNotice(key) {
      var text=backend.tr(key)
      var notice=fixture.find(consumer,function(x){return x.visible && x.objectName==="vpnNoticeText" && x.text===text})
      expect(notice!==null,"Visible notice "+key)
      var view=byName("vpnContentViewport"),point=notice.mapToItem(view,0,0)
      expect(point.y>=-1 && point.y+notice.height<=view.height+1,"Feedback is inside visible viewport: "+key+" y="+point.y)
    }
    function subscriptions() {
      go("subscriptions");var p=page("Subscriptions")
      click(button(p,"subscriptions.addTitle"));expect(p.showAddForm)
      var name=field(p,"subscriptions.namePlaceholder"),url=field(p,"subscriptions.urlPlaceholder")
      url.focusInput();keyClick(Qt.Key_Tab);wait(5);keyClick(Qt.Key_Tab);wait(5);expect(name.activeFocus,"Tab URL → eye → optional name")
      var before=count("subscriptions.add");activate(name);equal(count("subscriptions.add"),before);visibleNotice("form.required")
      fill(name,"Fixture subscription");fill(url,"not-a-url");activate(name);equal(count("subscriptions.add"),before);visibleNotice("subscriptions.invalidUrl");expect(p.showAddForm)
      equal(url.echoMode,TextInput.Password);url.forceActiveFocus();keyClick(Qt.Key_Tab);wait(5);keyClick(Qt.Key_Space);wait(5);equal(url.echoMode,TextInput.Normal,"Eye keyboard reveals")
      keyClick(Qt.Key_Return);wait(5);equal(url.echoMode,TextInput.Password)
      click(button(p,"action.cancel"));expect(!p.showAddForm);equal(url.text,"");equal(name.text,"");expect(!url.showPassword)
      click(button(p,"subscriptions.addTitle"));fill(name,"Fixture subscription");fill(url,"https://example.invalid/sub")
      fixture.holdMethod="subscriptions.add";activate(name);expect(p.pending);expect(p.showAddForm);equal(url.text,"https://example.invalid/sub");visibleNotice("operation.pending")
      activate(name);equal(count("subscriptions.add"),before+1,"Pending cannot duplicate")
      fixture.release(true);wait(35);expect(!p.pending);expect(p.showAddForm);visibleNotice("subscriptions.addFailed");equal(url.text,"https://example.invalid/sub")
      activate(name);expect(!p.showAddForm);equal(url.text,"");equal(name.text,"");visibleNotice("subscriptions.added")
      console.log("R6_PASS subscriptions empty invalid-url masking cancel pending failure-retention retry-success")
    }
    function serversImport() {
      go("servers");var p=page("Servers");click(button(p,"action.import"));expect(p.showImportBox)
      var area=byName("vpnServerImport"),before=count("servers.import")
      area.forceActiveFocus();keyClick(Qt.Key_Return,Qt.ControlModifier);wait(25);equal(count("servers.import"),before);visibleNotice("form.required")
      fill(area,"invalid server");fixture.failNext="servers.import";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(45)
      expect(p.showImportBox);equal(area.text,"invalid server");visibleNotice("servers.invalidImport")
      fill(area,"vless://fixture@example.invalid:443#Fixture");fixture.holdMethod="servers.import";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20);expect(p.pending);visibleNotice("operation.pending")
      fixture.release(false);wait(45);expect(!p.showImportBox);equal(area.text,"");visibleNotice("servers.imported")
      click(button(p,"action.import"));fill(area,"discard me");click(button(p,"action.cancel"));expect(!p.showImportBox);equal(area.text,"")
      console.log("R6_PASS servers empty rejected-text retained pending imported cancel")
    }
    function customImport() {
      go("custom");var p=page("CustomConfig");click(button(p,"custom.addTitle"));expect(p.showImportForm)
      var name=field(p,"custom.nameLabel"),area=byName("vpnCustomJson"),before=count("custom.import")
      area.forceActiveFocus();keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20);visibleNotice("form.required");equal(count("custom.import"),before)
      fill(name,"Fixture config");fill(area,"{");keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20);visibleNotice("custom.invalidJson");equal(count("custom.import"),before)
      fill(area,"[]");keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20);visibleNotice("custom.invalidJson");equal(count("custom.import"),before)
      fill(area,'{"outbounds":[]}');fixture.failNext="custom.import";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(45);visibleNotice("custom.invalidConfig");expect(p.showImportForm);equal(area.text,'{"outbounds":[]}')
      fixture.holdMethod="custom.import";area.forceActiveFocus();keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20);expect(p.pending)
      fixture.release(false);wait(45);expect(!p.showImportForm);equal(area.text,"");equal(name.text,"");visibleNotice("custom.imported")
      click(button(p,"custom.addTitle"));fill(name,"Discard");fill(area,"{}");click(button(p,"action.cancel"));equal(area.text,"");equal(name.text,"")
      console.log("R6_PASS custom required malformed-json array backend-rejection pending retry-success cancel")
    }
    function rules() {
      go("rules");var p=page("Rules"),area=byName("vpnRulesEditor")
      fill(area,"invalid rule");fixture.failNext="rules.set";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(45);visibleNotice("rules.invalid");equal(area.text,"invalid rule")
      fill(area,"DOMAIN,edited.invalid,proxy");var priority=byName("vpnRulesPriority");priority.forceActiveFocus();keyClick(Qt.Key_Right);keyClick(Qt.Key_Space);wait(5);equal(p.selectedPriority,"custom_first")
      activate(button(p,"rules.saveBtn"));wait(35);equal(fixture.rulesText,"DOMAIN,edited.invalid,proxy");visibleNotice("rules.saved")
      fill(area,"");activate(button(p,"rules.importBtn"));visibleNotice("form.required")
      fill(area,"bad-json");fixture.failNext="rules.import";activate(button(p,"rules.importBtn"));visibleNotice("rules.invalid");equal(area.text,"bad-json")
      fill(area,'{"rules":[]}');activate(button(p,"rules.importBtn"));wait(25);visibleNotice("rules.importedSuccess");equal(area.text,"DOMAIN,imported.invalid,proxy")
      fill(area,"UNSAVED DRAFT");var format=byName("vpnRulesFormat");format.forceActiveFocus();keyClick(Qt.Key_Right);keyClick(Qt.Key_Return);equal(p.importExportFormat,"csv")
      fixture.holdMethod="rules.export";activate(button(p,"rules.exportBtn"));expect(p.pending);fixture.release(false);wait(25)
      equal(area.text,"UNSAVED DRAFT","Export preserves draft");equal(byName("vpnRulesExport").text,"domain,example.invalid,proxy");equal(p.statusNotice,"rules.exportReady")
      fixture.failNext="rules.export";activate(button(p,"rules.exportBtn"));expect(p.noticeError);equal(p.exportedText,"")
      activate(button(p,"rules.exportBtn"));expect(p.exportedText!=="");equal(p.noticeArgs[0],"CSV")
      console.log("R6_PASS rules edit invalid priority save import-empty import-error import-success format export-preserves-draft no-fake-file retry")
    }
    function settings() {
      go("settings");var p=page("Settings"),mtu=fixture.find(p,function(x){return x.placeholderText==="1420"}),cidr=byName("vpnSettingsCidrs")
      fill(mtu,"");keyClick(Qt.Key_1);keyClick(Qt.Key_4);keyClick(Qt.Key_0);keyClick(Qt.Key_0);equal(mtu.text,"1400","MTU typing is not clamped per keystroke")
      fill(mtu,"abc");activate(mtu);visibleNotice("settings.invalidMtu");equal(fixture.savedSettings.mtu,1420)
      fill(mtu,"1400");fill(cidr,"bad subnet");fixture.failNext="settings.set";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(45);visibleNotice("settings.invalid");equal(cidr.text,"bad subnet");equal(fixture.lastParams.values.routeExcludeAddress[0],"bad subnet","No silently discarded CIDR")
      var toggles=fixture.all(p,function(x){return x.toggled!==undefined && x.label!==undefined},[])
      var editable=toggles.filter(function(x){return x.enabled})
      for(var i=0;i<editable.length;i++) activate(editable[i],Qt.Key_Space)
      expect(toggles.filter(function(x){return !x.enabled}).length>=2)
      activate(button(p,"settings.revert"));equal(mtu.text,"1420");equal(cidr.text,"192.168.0.0/16");expect(!p.ipv6Val && !p.strictDnsVal)
      expect(editable[0].checked===false,"Toggle binding survives edit/revert")
      visibleNotice("settings.reverted")
      fill(mtu,"1400");fill(cidr,"10.0.0.0/8\n2001:db8::/32");activate(editable[0],Qt.Key_Space)
      fixture.holdMethod="settings.set";activate(button(p,"settings.save"));expect(p.pending);fixture.release(false);wait(45)
      equal(fixture.savedSettings.mtu,1400);expect(fixture.savedSettings.ipv6Enabled);equal(fixture.savedSettings.routeExcludeAddress.length,2);equal(cidr.text,"10.0.0.0/8\n2001:db8::/32");visibleNotice("settings.saved")
      activate(editable[0],Qt.Key_Space);expect(!p.ipv6Val);activate(button(p,"settings.revert"));expect(p.ipv6Val && editable[0].checked,"Revert uses newly saved values")
      console.log("R6_PASS settings real-typing invalid-mtu cidr-no-loss backend-rejection all-editable-toggles revert bindings pending saved ipv6-cidr")
    }
    function routing() {
      go("apps")
      var choice=byName("vpnRoutingChoice");activate(choice)
      keyClick(Qt.Key_Right);keyClick(Qt.Key_Return);wait(35);equal(backend.routingMode,"full")
      keyClick(Qt.Key_Left);keyClick(Qt.Key_Space);wait(35);equal(backend.routingMode,"split")
      choice=byName("vpnAppRuleChoice");choice.forceActiveFocus();keyClick(Qt.Key_Right);keyClick(Qt.Key_Return);wait(35);equal(backend.routingAppsMode,"exclude")
      keyClick(Qt.Key_Left);keyClick(Qt.Key_Space);wait(35);equal(backend.routingAppsMode,"include")
      consumer.setDisplayMode("simple");wait(40)
      choice=byName("vpnHomeRoutingChoice");choice.forceActiveFocus();keyClick(Qt.Key_Right);keyClick(Qt.Key_Return);wait(35);equal(backend.routingMode,"full")
      expect(fixture.find(byName("vpnHomeRoutingChoice"),function(x){return x.objectName==="vpnChoice-full"}).selected,"Full pill selected")
      equal(byName("vpnRoutingSummary").text,backend.tr("home.allTraffic"))
      keyClick(Qt.Key_Left);keyClick(Qt.Key_Space);wait(35);equal(backend.routingMode,"split")
      click(fixture.find(byName("vpnHomeRoutingChoice"),function(x){return x.objectName==="vpnChoice-full"}));equal(backend.routingMode,"full");click(fixture.find(byName("vpnHomeRoutingChoice"),function(x){return x.objectName==="vpnChoice-split"}));equal(backend.routingMode,"split")
      var before=fixture.messages.length
      fixture.holdMethod="routing.set";click(fixture.find(byName("vpnHomeRoutingChoice"),function(x){return x.objectName==="vpnChoice-full"}));expect(!choice.enabled,"Pending disables group")
      fixture.release(true);wait(35);equal(backend.routingMode,"split","Rejected change retains confirmed value")
      fixture.holdMethod="routing.set";click(fixture.find(byName("vpnHomeRoutingChoice"),function(x){return x.objectName==="vpnChoice-full"}));fixture.release(false);wait(35);equal(backend.routingMode,"full")
      consumer.openSection("apps");wait(35)
      console.log("R6_PASS routing apps-home arrows-return-space-pointer pending-failure-success")
    }

    function actions() {
      go("profiles");var p=page("Profiles");activate(button(p,"profiles.refresh"));var selects=fixture.all(p,function(x){return x.clicked!==undefined && x.accessibleLabel!==undefined && x.text===backend.tr("profiles.select") && x.enabled},[]);equal(selects.length,1);activate(selects[0],Qt.Key_Space);wait(20);equal(fixture.selectedProfile,"two");expect(backend.profiles[1].selected)
      go("diagnostics");p=page("Diagnostics");activate(button(p,"diagnostics.checkBtn"));equal(backend.diagnosticsItems.length,2)
      fixture.holdMethod="diagnostics.export";activate(button(p,"diagnostics.exportBtn"));equal(backend.diagnosticsExportPath,"");fixture.release(false);wait(20);expect(backend.diagnosticsExportPath.endsWith("fixture.zip"));expect(fixture.find(p,function(x){return x.objectName==="vpnNoticeText" && x.text.indexOf(backend.diagnosticsExportPath)!==-1})!==null)
      fixture.failNext="diagnostics.export";activate(button(p,"diagnostics.exportBtn"));equal(backend.diagnosticsExportPath,"");activate(button(p,"diagnostics.exportBtn"));expect(backend.diagnosticsExportPath!=="");activate(fixture.find(p,function(x){return x.tooltipText===backend.tr("action.dismiss")}));equal(backend.diagnosticsExportPath,"")
      go("subscriptions");p=page("Subscriptions");var toggle=fixture.find(p,function(x){return x.toggled!==undefined});activate(toggle,Qt.Key_Space);wait(20);equal(backend.subscriptions[0].enabled,false);equal(fixture.find(p,function(x){return x.toggled!==undefined}).checked,false)
      activate(button(p,"subscriptions.refreshAll"));var refresh=fixture.find(p,function(x){return x.tooltipText===backend.tr("action.refresh")});activate(refresh);var remove=fixture.find(p,function(x){return x.tooltipText===backend.tr("action.remove")});activate(remove);wait(20);equal(backend.subscriptions.length,0)
      go("servers");p=page("Servers");var select=byName("vpnServerRow-sub");activate(select,Qt.Key_Space);wait(20);equal(fixture.selectedServer,"sub")
      activate(fixture.find(p,function(x){return x.tooltipText===backend.tr("action.test")}));activate(fixture.find(p,function(x){return x.tooltipText===backend.tr("action.verify")}));expect(backend.serverVerification.ok)
      remove=fixture.find(p,function(x){return x.tooltipText===backend.tr("action.remove") && x.visible});activate(remove);wait(20);equal(backend.servers.length,1)
      go("custom");p=page("CustomConfig");activate(button(p,"custom.activate"));wait(20);equal(fixture.selectedCustom,"two");remove=fixture.find(p,function(x){return x.tooltipText===backend.tr("action.remove")});activate(remove);wait(20);equal(backend.customConfigs.length,1)
      go("free");p=page("FreePool");activate(button(p,"free.refresh"));activate(fixture.find(p,function(x){return x.tooltipText===backend.tr("action.test")}));equal(backend.freeServers[0].latencyMs,42);activate(fixture.find(p,function(x){return x.tooltipText===backend.tr("action.verify")}));expect(backend.freeVerification.ok);activate(button(p,"free.apply"));equal(fixture.selectedServer,"free")
      console.log("R6_PASS actions profiles-reload-select diagnostics-check-export-path-retry-dismiss subscription-enable-refresh-delete server-select-ping-verify-delete custom-activate-delete free-mock-refresh-ping-verify-apply")
    }
    function keyboard() {
      go("rules");var p=page("Rules"),area=byName("vpnRulesEditor")
      fill(area,"line");keyClick(Qt.Key_End);keyClick(Qt.Key_Return);keyClick(Qt.Key_X)
      equal(area.text,"line\nx","Enter inserts a newline in a multiline editor")
      keyClick(Qt.Key_Tab);wait(10);expect(button(p,"rules.saveBtn").activeFocus,"Tab leaves multiline editor for Apply")
      keyClick(Qt.Key_Backtab);wait(10);expect(area.activeFocus,"Shift+Tab returns to editor")
      var lines=[];for(var i=0;i<60;i++)lines.push("DOMAIN,example"+i+".invalid,proxy")
      fill(area,lines.join("\n"));keyClick(Qt.Key_End,Qt.ControlModifier);wait(15)
      var inner=fixture.find(area,function(x){return x.objectName==="vpnEditorViewport"})
      expect(inner.contentY>0,"Caret scrolls inside long editor")
      var outer=byName("vpnContentViewport"),point=area.mapToItem(outer,0,0)
      expect(point.y>=-1 && point.y+area.height<=outer.height+1,"Focused editor is revealed in page viewport")
      area.forceActiveFocus();keyClick(Qt.Key_Escape);wait(10);expect(!consumer.opened,"Escape from multiline editor")
      consumer.open();wait(25)
      go("subscriptions");click(button(page("Subscriptions"),"subscriptions.addTitle"));var url=field(page("Subscriptions"),"subscriptions.urlPlaceholder")
      url.forceActiveFocus();keyClick(Qt.Key_Escape);wait(10);expect(!consumer.opened,"Escape from secret field")
      consumer.open();wait(25);click(button(page("Subscriptions"),"action.cancel"))
      console.log("R6_PASS keyboard multiline-enter tab-backtab long-caret-inner-scroll focus-reveal escape-editor escape-secret")
    }
    function editingLayout(parent,emptyKey) {
      var cancels=fixture.all(parent,function(x){return x.visible && x.clicked!==undefined && x.accessibleLabel!==undefined && x.text===backend.tr("action.cancel")},[])
      equal(cancels.length,1,"An open form has one visible Cancel action")
      expect(fixture.find(parent,function(x){return x.visible && x.text===backend.tr(emptyKey)})===null,"An open form does not compete with its empty-state card")
    }
    function pointerForms() {
      fixture.subscriptions=[]
      go("subscriptions");var p=page("Subscriptions")
      click(button(p,"subscriptions.addTitle"));editingLayout(p,"subscriptions.empty");click(button(p,"action.add"));visibleNotice("form.required")
      fill(field(p,"subscriptions.namePlaceholder"),"Pointer fixture");fill(field(p,"subscriptions.urlPlaceholder"),"https://example.invalid/sub")
      click(button(p,"action.add"));expect(!p.showAddForm);visibleNotice("subscriptions.added")
      click(button(p,"subscriptions.addTitle"));click(button(p,"action.cancel"));expect(!p.showAddForm);expect(button(p,"subscriptions.addTitle").activeFocus,"Cancel returns focus to Add Subscription")
      fixture.servers=[]
      go("servers");p=page("Servers");click(button(p,"action.import"));editingLayout(p,"servers.empty");fill(byName("vpnServerImport"),"invalid")
      fixture.failNext="servers.import";click(button(p,"servers.importBtn"));visibleNotice("servers.invalidImport")
      fill(byName("vpnServerImport"),"vless://fixture@example.invalid:443");click(button(p,"servers.importBtn"));expect(!p.showImportBox)
      click(button(p,"action.import"));click(button(p,"action.cancel"));expect(!p.showImportBox);expect(button(p,"action.import").activeFocus,"Cancel returns focus to Import Server")
      fixture.configs=[]
      go("custom");p=page("CustomConfig");click(button(p,"custom.addTitle"));editingLayout(p,"custom.empty");fill(field(p,"custom.nameLabel"),"Pointer config");fill(byName("vpnCustomJson"),"{}")
      click(button(p,"action.import"));expect(!p.showImportForm);click(button(p,"custom.addTitle"));click(button(p,"action.cancel"));expect(!p.showImportForm);expect(button(p,"custom.addTitle").activeFocus,"Cancel returns focus to Import Configuration")
      go("rules");p=page("Rules");click(button(p,"rules.saveBtn"));visibleNotice("rules.saved");fill(byName("vpnRulesEditor"),'{"rules":[]}');click(button(p,"rules.importBtn"));visibleNotice("rules.importedSuccess");click(button(p,"rules.exportBtn"));equal(p.statusNotice,"rules.exportReady")
      go("settings");p=page("Settings");click(button(p,"settings.save"));visibleNotice("settings.saved");click(button(p,"settings.revert"));visibleNotice("settings.reverted")
      go("apps");var group=byName("vpnRoutingChoice"),options=fixture.all(group,function(x){return x.clicked!==undefined && x.selected!==undefined},[])
      click(options[1]);equal(backend.routingMode,"full");click(options[0]);equal(backend.routingMode,"split")
      group=byName("vpnAppRuleChoice");options=fixture.all(group,function(x){return x.clicked!==undefined && x.selected!==undefined},[]);click(options[1]);equal(backend.routingAppsMode,"exclude");click(options[0]);equal(backend.routingAppsMode,"include")
      console.log("R6_PASS pointerForms submit-single-cancel no-competing-empty-card focus-return every-form native-routing-options")
    }
    function run() {
      var initial=JSON.stringify(geometry())
      if(fixture.suite==="night2") night2()
      else if(fixture.suite==="subscriptions") subscriptions()
      else if(fixture.suite==="servers") serversImport()
      else if(fixture.suite==="custom") customImport()
      else if(fixture.suite==="rules") rules()
      else if(fixture.suite==="settings") settings()
      else if(fixture.suite==="routing") routing()
      else if(fixture.suite==="actions") actions()
      else if(fixture.suite==="keyboard") keyboard()
      else if(fixture.suite==="pointerForms") pointerForms()
      else if(fixture.suite==="summary") { summary() }
      else if(fixture.suite==="brand") { brand() }
      else if(fixture.suite==="states") { states() }
      else if(fixture.suite==="layoutFit") { layoutFit() }
      else if(fixture.suite==="focusCues") { focusCues() }
      else if(fixture.suite==="homeReturn") { homeReturn() }
      else if(fixture.suite==="geometry") {
        var tabs=["servers","subscriptions","apps","rules","settings","diagnostics","free","profiles","custom"]
        for(var i=0;i<tabs.length;i++) {
          consumer.setDisplayMode("simple");wait(35)
          var item=byName("vpnTab-"+tabs[i])
          if(i%2===0) click(item);else activate(item,Qt.Key_Enter)
          equal(consumer.currentTab,tabs[i],"Real list navigation")
          equal(consumer.mode,"advanced")
          equal(JSON.stringify(geometry()),initial,"Fixed card and back navigation on every section")
          expect(byName("vpnBack").activeFocus,"Entry focuses back control")
          click(byName("vpnBack"));equal(consumer.mode,"simple")
          expect(item.activeFocus,"Back restores originating row focus")
        }
        go("subscriptions");click(button(page("Subscriptions"),"subscriptions.addTitle"));click(button(page("Subscriptions"),"action.cancel"));go("apps")
        console.log("R6_PASS geometry all-tabs-editor-return")
      }
      equal(JSON.stringify(geometry()),initial,"Advanced frame and navigation stay fixed")
      var focus=fixture.find(consumer,function(x){return x.visible && x.isPassword!==undefined})
      if(focus) focus.forceActiveFocus();keyClick(Qt.Key_Escape);wait(10);expect(!consumer.opened,"Escape closes panel from form focus")
      consumer.open();wait(40)
      console.log("R6_RESULT",fixture.suite,"PASS",JSON.stringify(geometry()))
    }
    function homeReturn() {
      go("custom")
      var target=fixture.find(consumer,function(x){return x.objectName==="vpnTab-custom"}),viewport=byName("vpnContentViewport"),focusExtent=null
      function recordExtent() {
        if(target.activeFocus && focusExtent===null) focusExtent={height:viewport.contentHeight,bottom:target.mapToItem(viewport.contentItem,0,0).y+target.height}
      }
      target.activeFocusChanged.connect(recordExtent)
      consumer.setDisplayMode("simple");wait(40)
      target.activeFocusChanged.disconnect(recordExtent)
      expect(focusExtent!==null && focusExtent.height>=focusExtent.bottom,"Restored row fits the content extent when focus arrives")
      target.forceActiveFocus();wait(40)
      var point=target.mapToItem(viewport,0,0)
      expect(point.y>=-1 && point.y+target.height<=viewport.height+1,"The final home row is initially revealed")
      consumer.setDisplayMode("simple");wait(40)
      expect(target.activeFocus,"Repeated home entry retains the selected row")
      point=target.mapToItem(viewport,0,0)
      expect(point.y>=-1 && point.y+target.height<=viewport.height+1,"Repeated home entry reveals an already-focused row")
      consumer.openSection("servers");wait(35);consumer.setDisplayMode("simple");wait(40)
      target=byName("vpnTab-servers");point=target.mapToItem(viewport,0,0)
      expect(target.activeFocus && point.y>=-1 && point.y+target.height<=viewport.height+1,"Changing section restores its visible home row")
      console.log("R6_PASS homeReturn repeated-home reveal-already-focused changed-section")
    }
    function visibleTooltip(label) {
      return fixture.controlOverlay && fixture.find(fixture.controlOverlay,function(x){return x.visible && x.text===label})
    }
    function hoverTooltip(item,label,leave) {
      var nativeButton=fixture.find(item,function(x){return x.iconText!==undefined && x.tooltipText!==undefined})
      expect(nativeButton!==null,"Hint uses the native Button")
      equal(nativeButton.tooltipText,label,"Localized hint reaches the native Button")
      mouseMove(item,item.width/2,item.height/2)
      for(var n=0;n<60 && !visibleTooltip(label);n++) wait(25)
      expect(visibleTooltip(label),"Actual native tooltip opens on hover: "+label)
      if(leave!==false) {
        mouseMove(fixture,1,1)
        for(var n=0;n<30 && visibleTooltip(label);n++) wait(25)
        expect(!visibleTooltip(label),"Native tooltip closes after pointer leaves")
      }
    }
    function focusCues() {
      function cue(owner) {
        var mark=fixture.find(owner,function(x){return x.objectName==="vpnFocusCue" && x.parent===owner})
        expect(mark!==null,"Focus cue exists")
        return mark
      }
      go("subscriptions");var p=page("Subscriptions")
      click(button(p,"subscriptions.addTitle"))
      var name=field(p,"subscriptions.namePlaceholder"),url=field(p,"subscriptions.urlPlaceholder")
      url.focusInput();wait(15)
      expect(cue(url).visible,"URL field identifies focus")
      equal(String(cue(url).color),String(Commons.Color.accent),"Focus cue inherits theme accent")
      equal(cue(url).width,Commons.Style.space(2),"Focus cue uses theme spacing")
      keyClick(Qt.Key_Tab);wait(15)
      var eye=fixture.find(url,function(x){return x.tooltipText===backend.tr("subscriptions.showUrl")})
      expect(eye!==null && cue(eye).visible,"Secret-eye action identifies keyboard focus")
      hoverTooltip(eye,backend.tr("subscriptions.showUrl"))
      expect(!cue(url).visible,"The eye action does not also mark the whole field")
      keyClick(Qt.Key_Tab);wait(15)
      expect(cue(name).visible,"Tab leaves the secret field for optional Name")
      keyClick(Qt.Key_Tab);wait(15)
      expect(button(p,"action.add").activeFocus,"Tab leaves Name for Add")
      keyClick(Qt.Key_Backtab);wait(15)
      expect(cue(name).visible,"Shift+Tab returns to Name")
      keyClick(Qt.Key_Backtab);wait(15)
      expect(cue(eye).visible,"Shift+Tab returns to the secret-eye action")
      keyClick(Qt.Key_Backtab);wait(15)
      expect(cue(url).visible,"Shift+Tab returns from the eye to the URL input")
      keyClick(Qt.Key_Return);wait(15)
      expect(cue(name).visible,"Enter in URL explicitly focuses optional Name")
      activate(name);visibleNotice("form.required")
      var notice=fixture.find(p,function(x){return x.objectName==="vpnNoticeText" && x.visible})
      expect(notice.activeFocus && cue(notice.parent).visible,"Selectable error feedback identifies its keyboard focus")
      keyClick(Qt.Key_Tab);wait(15)
      expect(!cue(notice.parent).visible,"Feedback focus cue clears when Tab leaves")
      click(button(p,"action.cancel"))
      for(var hint of [["vpnClose","action.close"],["vpnBack","home.back"],["vpnLanguage","language.change"]])
        hoverTooltip(byName(hint[0]),backend.tr(hint[1]))
      var toggle=fixture.find(p,function(x){return x.compact===true && x.toggled!==undefined})
      expect(toggle!==null && toggle.Accessible.name.length>0,"Compact subscription toggle has a name")
      go("apps")
      var choices=fixture.all(page("Apps"),function(x){return typeof x.naturalRowWidth==="function"},[])
      var choice=choices[0];choice.forceActiveFocus();wait(15)
      var marks=fixture.all(choice,function(x){return x.objectName==="vpnFocusCue" && x.visible},[])
      equal(marks.length,1,"Only the current option receives a focus cue")
      keyClick(Qt.Key_Right);wait(15)
      marks=fixture.all(choice,function(x){return x.objectName==="vpnFocusCue" && x.visible},[])
      equal(marks.length,1,"Arrow focus moves without adding a second cue")
      go("settings")
      var descriptions=fixture.all(page("Settings"),function(x){return x.objectName==="vpnToggleDescription" && x.visible},[])
      expect(descriptions.length>=3,"Setting explanations remain visible")
      for(var text of descriptions) {
        equal(String(text.color),String(Commons.Color.popups.text),"Description uses readable theme text")
        expect(text.contentWidth<=text.width+1,"Description wraps within its width")
      }
      var text=descriptions[0],toggle=text.parent.parent,checked=toggle.checked,before=count("settings.set")
      mouseClick(text);wait(15);expect(toggle.checked!==checked,"Description click still toggles the local draft")
      expect(cue(toggle).visible,"Description click focuses the complete native setting")
      mouseClick(text);wait(15);equal(toggle.checked,checked,"Description click can restore the draft")
      equal(count("settings.set"),before,"Description click does not save settings")
      console.log("R6_PASS focusCues native-hover-hints notice-focus theme-accent tab-transfer eye choice named-toggle readable-wrapped-descriptions")
    }
    function layoutFit() {
      var originalWidth=fixture.width
      fixture.width=400
      fixture.free=[];fixture.subscriptions=[];fixture.profiles=[];fixture.configs=[]
      backend.freeServers=[];backend.subscriptions=[];backend.profiles=[];backend.customConfigs=[];backend.diagnosticsItems=[]
      for (var entry of [["free","FreePool","free.empty"],["subscriptions","Subscriptions","subscriptions.empty"],["profiles","Profiles","profiles.empty"],["custom","CustomConfig","custom.empty"]]) {
        go(entry[0])
        var text=fixture.find(page(entry[1]),function(x){return x.text===backend.tr(entry[2])})
        expect(text!==null,"Empty-state text exists: "+entry[0])
        expect(text.width<=page(entry[1]).width-30,"Empty-state width stays inside card: "+entry[0])
        expect(text.contentWidth<=text.width+1,"Empty-state message wraps: "+entry[0])
        expect(text.parent.implicitHeight+30<=text.parent.parent.height+1,"Empty-state card contains text: "+entry[0])
      }
      for (var tab of ["apps","rules"]) {
        go(tab)
        var choices=fixture.all(consumer,function(x){return x.visible && typeof x.naturalRowWidth==="function"},[])
        for(var choice of choices) {
          var buttons=fixture.all(choice,function(x){return String(x.objectName).indexOf("vpnChoice-")===0},[])
          for(var option of buttons) expect(option.width+1>=option.implicitWidth,"Native choice label has room: "+option.text+" width="+option.width+" natural="+option.implicitWidth+" stacked="+choice.stacked+" available="+choice.width+" total="+choice.naturalRowWidth())
          if(choice.stacked) {
            choice.forceActiveFocus();choice.focusedIndex=0;keyClick(Qt.Key_Down);equal(choice.focusedIndex,1,"Stacked choices accept Down")
          }
        }
      }
      fixture.width=originalWidth
      console.log("R6_PASS layoutFit wrapped-empty-states native-choice-width vertical-key-navigation")
    }
    function states() {
      consumer.setDisplayMode("simple");wait(35)
      var hero=byName("vpnHero"),button=byName("vpnConnect"),arc=fixture.find(consumer,function(x){return x.objectName==="vpnConnectingArc"})
      backend.state="disconnected";backend.backendMissing=false;backend.capabilities={connect:false};wait(20)
      expect(!button.enabled,"Connect disabled without capability")
      backend.capabilities={connect:true};wait(20);expect(button.enabled,"Connect enabled only with capability")
      backend.busy=true;backend.activeOperation="servers.list";wait(20)
      expect(!hero.busy && !arc.visible,"Collection reads must not show VPN connection progress")
      expect(!button.enabled,"Backend operation still gates Connect admission")
      backend.busy=false;backend.activeOperation="";wait(20)
      backend.state="connected";wait(20);equal(byName("vpnStateTitle").text,backend.tr("state.connected"));expect(button.enabled,"Disconnect available")
      expect(String(hero.stateColor)===String(Commons.Color.accent),"Success ring")
      backend.state="error";backend.lastError=backend.tr("error.timeout");wait(20);expect(String(hero.stateColor)===String(Commons.Color.urgent),"Error ring");equal(hero.availability,backend.tr("error.timeout"),"Error reason is visible")
      backend.state="unavailable";backend.backendMissing=false;backend.helperPresent=true;backend.starting=false;backend.revision="";backend.snapshotLoaded=false;backend.capabilities={connect:false};backend.lastError=backend.tr("error.timeout");wait(20)
      equal(hero.availability,backend.tr("error.timeout"),"Unavailable state preserves the actual timeout reason")
      expect(!hero.initializing && barStateProbe.visualState==="unavailable","Timeout is not indefinite startup")
      backend.lastError="";wait(20)
      expect(hero.initializing,"Running helper without a snapshot is initializing")
      equal(byName("vpnStateTitle").text,backend.tr("backend.starting"),"Startup has its own title")
      equal(hero.availability,backend.tr("backend.startingDetail"),"Startup describes local status reading")
      expect(!hero.busy && !arc.visible,"Service startup never simulates a VPN handshake")
      var savedServers=backend.servers,savedSubscriptions=backend.subscriptions
      backend.servers=[];backend.subscriptions=[];wait(15);expect(!hero.needsSetup,"Startup does not show a premature empty-configuration prompt")
      backend.servers=savedServers;backend.subscriptions=savedSubscriptions
      equal(barStateProbe.visualState,"starting","The actual bar binding recognizes startup")
      equal(String(barStateProbe.inkColor),String(Commons.Color.muted),"Startup bar is neutral")
      equal(String(hero.stateColor),String(Commons.Color.muted),"Startup hero is neutral")
      backend.capabilities={connect:true};wait(20);expect(!button.enabled,"Startup never enables Connect from stale capability")
      backend.starting=true;backend.helperPresent=false;wait(20);expect(hero.initializing,"Process startup is covered too")
      backend.starting=false;backend.helperPresent=true;backend.revision="";backend.snapshotLoaded=true;backend.unavailableReasonCode="runtime-capabilities";wait(20)
      equal(hero.availability,backend.tr("backend.reason.runtime-capabilities"),"A known unavailable snapshot shows its reason")
      expect(!hero.initializing,"A known unavailable snapshot does not look like startup")
      backend.unavailableReasonCode=null;backend.helperPresent=false;wait(20)
      equal(hero.availability,backend.tr("backend.notRunning"),"Stopped helper retains its distinct message")
      backend.state="unavailable";backend.backendMissing=true;backend.capabilities={connect:false};wait(20);expect(!button.enabled,"Missing backend cannot connect")
      expect(hero.availability.indexOf(backend.tr("backend.installHint"))!==-1,"Honest install hint")
      backend.backendMissing=false;backend.state="connecting";backend.lastError="";backend.busy=true;backend.activeOperation="connect";wait(30)
      expect(!button.enabled,"Connecting cannot duplicate")
      var start=arc.rotation;wait(130);expect(Math.abs(arc.rotation-start)>1,"Connecting arc moves")
      console.log("R7_MOTION",start,arc.rotation,"after130ms")
      if(fixture.motionOutputPrefix) {
        byName("vpnContentViewport").contentY=0
        for(var i=0;i<3;i++) {
          var saved=false
          fixture.grabToImage(function(result) { saved=result.saveToFile(fixture.motionOutputPrefix+i+".png") })
          wait(30);expect(saved,"Offscreen frame saved");wait(150)
        }
      }
      // Startup FileViews schedule one delayed Hyprland token refresh. Let that
      // read finish before testing the user's later reduced-motion preference.
      wait(250)
      tryVerify(function() {return !Commons.Style.refreshTimer.running && !Commons.Style.animationsProc.running},2000,"Host motion startup settled")
      Commons.Style.reduceMotion=true;wait(25);expect(!hero.motionEnabled,"Hero sees host reducedMotion="+Commons.Style.reduceMotion);start=arc.rotation;wait(130);equal(arc.rotation,start,"Reduced motion stops rotation")
      Commons.Style.reduceMotion=false
      backend.activeOperation="";backend.busy=false;backend.state="disconnected";backend.capabilities={connect:true}
      consumer.openSection("apps");wait(30)
      console.log("R6_PASS states disconnected-connected-error-unavailable-connecting disabled-capability rotation-reduced-motion")
    }
    function summary() {
      consumer.setDisplayMode("simple");wait(30)
      var initial=JSON.stringify(geometry()),original=fixture.includes.slice()
      for (var locale of ["en","ru"]) {
        backend.setLocale(locale);wait(15)
        for (var exclude of [false,true]) {
          backend.routingAppsMode=exclude ? "exclude" : "include"
          for (var count of [0,1,2,3,4,5,7,13,14,16,23,24,27]) {
            var names=["chromium","steam"]
            while(names.length<count) names.push("ExactCase"+names.length)
            names=names.slice(0,count)
            backend.apps={include:names,exclude:names,runningApps:fixture.appRecords};backend.appsLoaded=true;wait(5)
            var route=locale==="ru" ? (exclude?"напрямую":"через VPN") : (exclude?"direct":"through VPN")
            var rest=locale==="ru" ? (exclude?"через VPN":"напрямую") : (exclude?"use VPN":"go direct")
            var expected
            if(!count) expected=backend.tr(exclude ? "home.appsEmptyExclude" : "home.appsEmpty")
            else if(locale==="ru") expected=(count===1 ? "Chromium идёт " : count===2 ? "Chromium и Steam идут " : "Chromium, Steam и ещё "+(count-2)+" идут ")+route+". Остальные — "+rest+"."
            else expected=(count===1 ? "Chromium goes " : count===2 ? "Chromium and Steam go " : "Chromium, Steam and "+(count-2)+" more go ")+route+". Other apps "+rest+"."
            equal(byName("vpnRoutingSummary").text,expected,"Rendered summary: "+locale+"/"+exclude+"/"+count)
            equal(JSON.stringify(backend.apps.include),JSON.stringify(names),"Exact process keys preserved")
            equal(JSON.stringify(geometry()),initial,"Summary does not resize the panel")
          }
        }
      }
      backend.routingAppsMode=fixture.appRule;backend.setLocale(fixture.locale)
      backend.apps={include:original,exclude:fixture.excludes,runningApps:fixture.appRecords};wait(15)
      console.log("R6_PASS summary real-Text both-locales include-exclude 0-1-2-many CLDR-boundaries exact-keys stable-geometry")
    }
    function brand() {
      equal(String(VpnUi.Brand.background), String(Commons.Color.popups.background),"Mascot follows host surface")
      consumer.setDisplayMode("simple");wait(30)
      equal(byName("vpnStateTitle").font.family, Commons.Style.font.family,"Content inherits host font")
      click(byName("vpnChangeServer"));equal(consumer.currentTab,"servers");equal(consumer.mode,"advanced")
      click(byName("vpnBack"));equal(consumer.mode,"simple")
      fixture.servers=[];fixture.subscriptions=[];backend.servers=[];backend.subscriptions=[];backend.activeServer="";backend.serversLoaded=true;backend.subscriptionsLoaded=true;backend.apps={include:[],exclude:[],runningApps:[]};backend.appsLoaded=true;wait(25)
      expect(!byName("vpnConnect").enabled,"First run cannot connect")
      click(byName("vpnChangeServer"));expect(page("Subscriptions").showAddForm,"First-run opens real form")
      var language=byName("vpnLanguage"),start=backend.locale
      activate(language,Qt.Key_Space);expect(backend.locale!==start,"Language cycles")
      backend.setLocale(fixture.locale);wait(20)
      var close=byName("vpnClose");activate(close);expect(!consumer.opened,"Close action")
      consumer.open();wait(30);go("apps")
      console.log("R6_PASS brand host-luminance host-font change-server first-run language close")
    }
    function night2() {
      go("servers")
      consumer.settings={mode:"advanced",showLatency:false,locale:fixture.locale}
      barStateProbe.settings={showLatency:false,locale:fixture.locale}
      wait(25)
      var pills=fixture.all(page("Servers"),function(x){return x.known!==undefined && x.latency!==undefined},[])
      expect(pills.length>0,"Real list latency pills exist")
      for(var pill of pills) expect(!pill.visible,"Latency preference hides real list pills")
      backend.state="connected";wait(15)
      expect(barStateProbe.barTooltip.indexOf(backend.tr("latency.ms",[42]))===-1,"Disabled latency is absent from bar tooltip")
      consumer.settings={mode:"simple",showLatency:true,locale:fixture.locale}
      barStateProbe.settings={showLatency:true,locale:fixture.locale}
      backend.configMode="custom";backend.activeServer="Custom configuration (fixture)"
      consumer.setDisplayMode("simple");wait(25)
      equal(byName("vpnHomeServerName").text,backend.activeServer,"Custom mode does not display the stale selected server")
      equal(barStateProbe.activeServerItem,null,"Custom mode does not borrow a stale server ping")
      click(byName("vpnChangeServer"));equal(consumer.currentTab,"custom","Change follows the active config type")
      backend.configMode="generated";backend.state="disconnected";fixture.servers=[];fixture.selectedServer="";backend.servers=[];backend.serversLoaded=true
      consumer.setDisplayMode("simple");wait(20)
      expect(!byName("vpnConnect").enabled,"Empty subscription cannot connect")
      var connects=count("connect");backend.connect();equal(count("connect"),connects,"Quick bar path also rejects an empty configuration");backend.clearLastError()
      fixture.servers=[{id:"manual",name:"Probe fixture",source:"manual",protocol:"vless",latencyMs:0}];backend.servers=fixture.servers
      go("servers");wait(20)
      var row=byName("vpnServerRow-manual"),test=fixture.find(row,function(x){return x.tooltipText===backend.tr("action.test")})
      fixture.holdMethod="servers.test";click(test)
      expect(!test.enabled,"A second click cannot enqueue another probe")
      fixture.release(false);wait(25)
      expect(byName("vpnServersTestResult").text.indexOf(backend.tr("latency.ms",[42]))!==-1,"Successful ping is visible")
      backend.serverTest={id:"manual",reachable:false,latencyMs:null};wait(15)
      expect(byName("vpnServersTestResult").text.indexOf(backend.tr("test.unmeasured",["Probe fixture"]))!==-1,"Null ping is distinguished from never tested")
      backend.serverTest={id:"manual",errorCode:"timeout"};wait(15)
      expect(byName("vpnServersTestResult").text.indexOf(backend.tr("test.timeout",["Probe fixture"]))!==-1,"Timeout is explicit")
      consumer.setDisplayMode("simple");wait(20)
      backend.setLastError("error.timeout", [], "", "servers.verify")
      backend.setLocale("en");wait(15)
      equal(backend.lastErrorText,backend.tr("error.timeout"),"Local error displays in English")
      backend.setLocale("ru");wait(15)
      equal(backend.lastErrorText,backend.tr("error.timeout"),"Stored local error follows locale changes")
      equal(byName("vpnHero").availability,backend.tr("error.timeout"),"Home displays the translated stored error")
      go("servers");wait(20)
      backend.serverTest={id:"manual",reachable:true,latencyMs:null};wait(15)
      equal(byName("vpnServersTestResult").text,backend.tr("test.reachable",["Probe fixture"]),"UDP reachable result is explicit")
      backend.setLocale(fixture.locale);backend.clearLastError()
      console.log("R6_PASS night2 real-latency-controls custom-state-and-navigation empty-subscription probe-pending-results")
    }
    function prepareCapture() {
      if(fixture.capture==="home" || fixture.capture==="home-bottom" || fixture.capture==="first-run") {
        consumer.setDisplayMode("simple");wait(25)
        // Capture entry has no focused navigation item; native return-focus is tested separately.
        consumer.forceActiveFocus();wait(10)
        if(fixture.capture==="first-run") {
          fixture.servers=[];fixture.subscriptions=[];backend.servers=[];backend.subscriptions=[];backend.activeServer="";backend.serversLoaded=true;backend.subscriptionsLoaded=true;backend.apps={include:[],exclude:[],runningApps:[]};backend.appsLoaded=true;wait(25)
        }
        byName("vpnContentViewport").contentY=0
      }

      else if(fixture.capture.indexOf("simple")===0) {consumer.setDisplayMode("simple");wait(25);if(fixture.capture==="simple-full") {fixture.route="full";backend.applySnapshot(fixture.snapshot());wait(20)}}
      else if(fixture.capture==="connected") {backend.state="connected";wait(20)}
      else if(fixture.capture==="full") {fixture.route="full";backend.applySnapshot(fixture.snapshot());wait(20)}
      else if(fixture.capture==="subscription-invalid") {consumer.openSubscriptionForm();wait(20);var p=page("Subscriptions");fill(field(p,"subscriptions.namePlaceholder"),"Fixture subscription");fill(field(p,"subscriptions.urlPlaceholder"),"invalid");activate(field(p,"subscriptions.namePlaceholder"))}
      else if(fixture.capture==="subscription-form") {consumer.openSubscriptionForm();wait(20);var p=page("Subscriptions");fill(field(p,"subscriptions.namePlaceholder"),"Fixture subscription");fill(field(p,"subscriptions.urlPlaceholder"),"https://example.invalid/sub")}
      else if(fixture.capture==="subscription-tooltip") {consumer.openSubscriptionForm();wait(30);var p=page("Subscriptions"),url=field(p,"subscriptions.urlPlaceholder"),eye=fixture.find(url,function(x){return x.tooltipText===backend.tr("subscriptions.showUrl")});hoverTooltip(eye,backend.tr("subscriptions.showUrl"),false)}
      else if(fixture.capture==="subscription-pending") {consumer.openSubscriptionForm();wait(20);var p=page("Subscriptions");fill(field(p,"subscriptions.namePlaceholder"),"Fixture subscription");fill(field(p,"subscriptions.urlPlaceholder"),"https://example.invalid/sub");fixture.holdMethod="subscriptions.add";activate(field(p,"subscriptions.namePlaceholder"));expect(p.pending,"Pending form capture uses the actual held request")}
      else if(fixture.capture==="rules-focus") {go("rules");byName("vpnRulesEditor").forceActiveFocus();wait(20)}
      else if(fixture.capture==="settings-focus") {go("settings");fixture.find(page("Settings"),function(x){return x.toggled!==undefined && typeof x.description==="string" && x.description.length>0 && x.enabled}).forceActiveFocus();wait(20)}
      else if(fixture.capture==="rules-invalid") {go("rules");fill(byName("vpnRulesEditor"),"invalid rule");fixture.failNext="rules.set";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(35)}
      else if(fixture.capture==="server-invalid") {go("servers");click(button(page("Servers"),"action.import"));fill(byName("vpnServerImport"),"invalid server");fixture.failNext="servers.import";keyClick(Qt.Key_Return,Qt.ControlModifier);wait(35)}
      else if(fixture.capture==="custom-invalid") {go("custom");click(button(page("CustomConfig"),"custom.addTitle"));fill(field(page("CustomConfig"),"custom.nameLabel"),"Fixture config");fill(byName("vpnCustomJson"),"{");keyClick(Qt.Key_Return,Qt.ControlModifier);wait(20)}
      else if(fixture.capture==="settings-invalid") {go("settings");fill(fixture.find(page("Settings"),function(x){return x.placeholderText==="1420"}),"abc");keyClick(Qt.Key_Return);wait(20)}
      else if(fixture.capture==="rules-export") {go("rules");activate(button(page("Rules"),"rules.exportBtn"))}
      else if(fixture.capture==="diagnostics-export") {go("diagnostics");activate(button(page("Diagnostics"),"diagnostics.exportBtn"))}
      else if(fixture.capture==="apps-bottom") {go("apps")}
      if(fixture.scrollBottom) {var view=byName("vpnContentViewport");view.contentY=Math.max(0,view.contentHeight-view.height);wait(15)}
    }
  }
}
