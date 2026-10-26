pragma Singleton
import QtQuick
import qs.Commons as Commons

// Only the original asset choice belongs to VPNRouter. The host owns all styling.
QtObject {
  function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  readonly property color background: Commons.Color.popups.background
  readonly property real luminance: 0.2126 * linear(background.r) + 0.7152 * linear(background.g) + 0.0722 * linear(background.b)
  readonly property bool dark: luminance < 0.5
  readonly property url mascot: Qt.resolvedUrl(dark ? "../assets/penguin_mascot_white.png" : "../assets/penguin_mascot.png")
}
