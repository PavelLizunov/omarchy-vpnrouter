import QtQuick
import QtQuick.Controls

// Mock host environment fixture for Omarchy Quattro headless testing
Item {
  id: hostRoot
  width: 1920
  height: 1080

  // Mock Color singleton
  QtObject {
    id: mockColor
    property color foreground: "#cacccc"
    property color background: "#101315"
    property color accent: "#55a5a5"
    property color urgent: "#a55555"
    property color muted: "#707880"
  }

  // Mock Style singleton
  QtObject {
    id: mockStyle
    property int cornerRadius: 4
    property int gapsOut: 5

    property QtObject font: QtObject {
      property string family: "monospace"
      property int caption: 10
      property int bodySmall: 11
      property int body: 12
      property int subtitle: 13
      property int title: 14
      property int heading: 16
      property int display: 24
      property int iconSmall: 11
      property int icon: 14
      property int iconLarge: 18
    }

    property QtObject spacing: QtObject {
      property int controlGap: 8
      property int controlPaddingX: 10
      property int controlPaddingY: 6
      property int controlHeight: 28
      property int popupPadding: 14
    }

    function space(px) { return Math.round(Number(px) || 0) }
    function controlFill(f, h, fg, acc) { return f ? "#222" : (h ? "#181818" : "#121212") }
    function controlBorder(f, h, fg, acc) { return f ? "#55a5a5" : (h ? "#444" : "#282828") }
    function controlBorderWidth(f, h) { return f ? 2 : 1 }
    function resolveStateColor(token, fg, acc, urg, fallback) {
      if (token === "urgent") return urg || mockColor.urgent
      if (token === "accent") return acc || mockColor.accent
      return fg || mockColor.foreground
    }
    property color focusBorderColor: "#55a5a5"
    property int focusBorderWidth: 2
    property int normalBorderWidth: 1
    property int hoverBorderWidth: 1
    property int selectedBorderWidth: 1
    property color normalFill: "#121212"
    property color hoverFill: "#1e1e1e"
    property color selectedFill: "#2a2a2a"
    property color pressedFill: "#333333"
    property color normalBorderColor: "#282828"
    property color hoverBorderColor: "#444444"
    property color selectedBorderColor: "#55a5a5"
  }

  property alias shell: mockShell

  // Mock Shell Api
  QtObject {
    id: mockShell
    property var _services: ({})

    function serviceFor(id) {
      return _services[id] || null
    }

    function registerService(id, svc) {
      _services[id] = svc
    }

    function updateEntryInline(id, settings) {
      return true
    }
  }

  // Mock Bar (host bar object does not carry a .shell property)
  QtObject {
    id: mockBar
    property color foreground: mockColor.foreground
    property color urgent: mockColor.urgent
    property string fontFamily: "monospace"
    property bool vertical: false
  }
}
