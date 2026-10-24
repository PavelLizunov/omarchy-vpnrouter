import QtQuick
import QtTest
import qs.Commons as Commons
// Staged by render-theme-matrix.py: installed visual source, three inert data bindings.
import "../native-bluetooth" as BluetoothPanel
Rectangle {
 id: fixture
 width: 440; height: 764
 color: Commons.Color.popups.background
 property bool previewReady: false
 QtObject {
  id: fakeBar
  property color foreground: Commons.Color.popups.text
  property color barForeground: foreground
  property color urgent: Commons.Color.urgent
  property bool foregroundAnimationEnabled: false
  function hideTooltip(item) {}
  function showTooltip(item, text) {}
  property color background: Commons.Color.popups.background
  property color accent: Commons.Color.accent
  property string fontFamily: Commons.Style.font.family
  property string position: "top"
  property bool vertical: false
  property int barSize: Commons.Style.bar.sizeHorizontal
 }
 QtObject { id: adapterFixture; property bool enabled: true; property bool discovering: false }
 BluetoothPanel.Panel {
  id: builtin; width: parent.width; height: parent.height; visible: true; bar: fakeBar
  adapter: adapterFixture
  devices: [{name:"Headphones (fixture)",address:"00:00:00:00:00:01",connected:false,paired:true,bonded:true,trusted:true},
            {name:"Mouse (fixture)",address:"00:00:00:00:00:02",connected:false,paired:true,bonded:true,trusted:true}]
 }
 function find(item, predicate) {
  if (predicate(item)) return item
  for (var child of item.children || []) { var x=find(child,predicate);if(x)return x }
  return null
 }
 Timer {
  running: true; interval: 400
  onTriggered: {
   var panel=fixture.find(builtin,function(x){return x.ensureContent!==undefined})
   if (!panel) { console.error("R8_NATIVE_FAIL missing KeyboardPanel");fixture.previewReady=true;return }
   for (var child of builtin.children) if (child.pressed !== undefined) child.visible=false
   panel.ensureContent()
   // Reparent only the offscreen adapter, leaving the built-in logic closed.
   panel.parent=fixture;panel.x=0;panel.y=0
   Qt.callLater(function() {fixture.previewReady=true; console.log("R8_NATIVE_READY",builtin.opened, String(Commons.Color.background))})
  }
 }
}
