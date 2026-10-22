pragma Singleton
import QtQuick
import qs.Commons 1.0 as Commons

QtObject {
  id: root
  // Desktop Tokens.axaml. The shell owns the frame; its luminance selects our palette.
  function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  readonly property real shellLuminance: 0.2126 * linear(Commons.Color.background.r) + 0.7152 * linear(Commons.Color.background.g) + 0.0722 * linear(Commons.Color.background.b)
  readonly property bool dark: shellLuminance < 0.5
  readonly property string fontFamily: {
    var families = Qt.fontFamilies()
    for (var name of ["Inter", "Segoe UI", "Noto Sans", "Liberation Sans", "DejaVu Sans"])
      if (families.indexOf(name) !== -1) return name
    return "sans-serif"
  }
  readonly property string iconFamily: Commons.Style.font.family
  readonly property url mascot: Qt.resolvedUrl(dark ? "../assets/penguin_mascot_white.png" : "../assets/penguin_mascot.png")
  function space(n) { return Commons.Style.space(n) }
  readonly property bool reduceMotion: Commons.Style.reduceMotion
  readonly property color surfaceApp: dark ? "#070A14" : "#F5F7FA"
  readonly property color surfaceSunken: dark ? "#0F1320" : "#EBEEF3"
  readonly property color surfaceBase: dark ? "#1C2231" : "#FFFFFF"
  readonly property color surfaceRaised: dark ? "#232A3B" : "#FFFFFF"
  readonly property color surfaceOverlay: dark ? "#2B3347" : "#FFFFFF"
  readonly property color textPrimary: dark ? "#EEF1F6" : "#0F1320"
  readonly property color textSecondary: dark ? "#A6B0C2" : "#475067"
  readonly property color textMuted: dark ? "#8791A6" : "#5B6A7F"
  readonly property color textInverse: dark ? "#0F1320" : "#FFFFFF"
  readonly property color textAccent: dark ? "#67E8F9" : "#0369A1"
  readonly property color borderSubtle: dark ? "#0AFFFFFF" : "#EBEEF3"
  readonly property color borderDefault: dark ? "#14FFFFFF" : "#DCE1E9"
  readonly property color borderStrong: dark ? "#29FFFFFF" : "#C2C9D5"
  readonly property color borderAccent: dark ? "#38BDF8" : "#38BDF8"
  readonly property color accentBgSubtle: dark ? "#1438BDF8" : "#ECFEFF"
  readonly property color accentBgMuted: dark ? "#2938BDF8" : "#CFFAFE"
  readonly property color accentBorder: dark ? "#6638BDF8" : "#67E8F9"
  readonly property color accentFg: dark ? "#67E8F9" : "#0369A1"
  readonly property color accentSolid: dark ? "#38BDF8" : "#0276B4"
  readonly property color accentSolidHover: dark ? "#67E8F9" : "#0369A1"
  readonly property color accentOnSolid: dark ? "#070A14" : "#FFFFFF"
  readonly property color successBg: dark ? "#1F22C55E" : "#DCFCE7"
  readonly property color successBorder: dark ? "#5922C55E" : "#86EFAC"
  readonly property color successFg: dark ? "#4ADE80" : "#166534"
  readonly property color successSolid: dark ? "#22C55E" : "#15803D"
  readonly property color warningBg: dark ? "#1FF59E0B" : "#FEF3C7"
  readonly property color warningBorder: dark ? "#59F59E0B" : "#FCD34D"
  readonly property color warningFg: dark ? "#FCD34D" : "#92400E"
  readonly property color warningSolid: dark ? "#F59E0B" : "#D97706"
  readonly property color dangerBg: dark ? "#1FEF4444" : "#FEE2E2"
  readonly property color dangerBorder: dark ? "#59EF4444" : "#FCA5A5"
  readonly property color dangerFg: dark ? "#FCA5A5" : "#B91C1C"
  readonly property color dangerSolid: dark ? "#EF4444" : "#DC2626"
  readonly property color infoBg: dark ? "#1F0EA5E9" : "#E0F2FE"
  readonly property color infoBorder: dark ? "#590EA5E9" : "#7DD3FC"
  readonly property color infoFg: dark ? "#7DD3FC" : "#075985"
  readonly property color infoSolid: dark ? "#0EA5E9" : "#0284C7"
  readonly property color pillFastBg: dark ? "#1E3A2F" : "#DCFCE7"
  readonly property color pillFastFg: dark ? "#6EE7B7" : "#14532D"
  readonly property color pillMediumBg: dark ? "#2D3B16" : "#ECFCCB"
  readonly property color pillMediumFg: dark ? "#BEF264" : "#365314"
  readonly property color pillSlowBg: dark ? "#3D2E12" : "#FEF3C7"
  readonly property color pillSlowFg: dark ? "#FDE68A" : "#78350F"
  readonly property color pillDangerBg: dark ? "#3B1A1A" : "#FEE2E2"
  readonly property color pillDangerFg: dark ? "#FCA5A5" : "#7F1D1D"
  readonly property color pillNeutralBg: dark ? "#1E2430" : "#F1F5F9"
  readonly property color pillNeutralFg: dark ? "#94A3B8" : "#334155"

  // Shared content roles for the existing forms and rows.
  readonly property real cornerRadius: space(8)
  readonly property real cardRadius: space(14)
  readonly property color normalFill: surfaceBase
  readonly property color hoverFill: accentBgSubtle
  readonly property color pressedFill: accentBgMuted
  readonly property color selectedFill: accentBgMuted
  readonly property color normalBorderColor: borderDefault
  readonly property color hoverBorderColor: borderAccent
  readonly property color focusBorderColor: accentSolid
  readonly property real normalBorderWidth: 1
  readonly property real focusBorderWidth: 2
  readonly property var spacing: ({ controlHeight: space(30), controlPaddingX: space(12) })
  readonly property var font: ({ family: fontFamily, body: space(13), bodySmall: space(12), caption: space(10), title: space(13), heading: space(18), display: space(22), iconSmall: space(16), icon: space(18) })
  function controlFill(focused, hot, foreground, accent) { return surfaceBase }
  function controlBorder(focused, hot, foreground, accent) { return focused ? accentSolid : hot ? borderAccent : (dark ? "#59ffffff" : "#8c96a8") }
  function controlBorderWidth(focused, hot) { return focused ? 2 : 1 }
}
