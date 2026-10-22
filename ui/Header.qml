pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../lib/I18n.js" as I18n

Rectangle {
  id: root
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  signal localeToggled()
  signal closeRequested()
  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }
  implicitHeight: Brand.space(64)
  color: Brand.surfaceBase
  RowLayout {
    anchors.fill: parent
    anchors.margins: Brand.space(12)
    spacing: Brand.space(12)
    Rectangle {
      Layout.preferredWidth: Brand.space(40)
      Layout.preferredHeight: Brand.space(40)
      radius: Brand.space(10)
      color: "#f5f7fa"
      border.color: Brand.borderDefault
      Image {
        anchors.fill: parent
        anchors.margins: Brand.space(3)
        source: "../assets/penguin_mascot.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }
    Column {
      Layout.fillWidth: true
      spacing: Brand.space(4)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.tr("app.brand")
        elide: Text.ElideRight
        color: Brand.textPrimary
        font.family: Brand.fontFamily
        font.pixelSize: Brand.space(14)
        font.bold: true
      }
      Rectangle {
        width: chipRow.implicitWidth + Brand.space(16)
        height: Brand.space(20)
        radius: height / 2
        color: root.service && root.service.isConnected ? Brand.successBg : Brand.surfaceSunken
        Row {
          id: chipRow
          anchors.centerIn: parent
          spacing: Brand.space(5)
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Brand.space(5); height: width; radius: width / 2
            color: root.service && root.service.isConnected ? Brand.successSolid : Brand.textMuted
          }
          Text {
            textFormat: Text.PlainText
            text: root.tr("header.vpn")
            color: root.service && root.service.isConnected ? Brand.successFg : Brand.textMuted
            font.family: Brand.fontFamily
            font.pixelSize: Brand.space(9)
          }
        }
      }
    }
    Button {
      objectName: "vpnLanguage"
      text: root.service && root.service.locale === "auto" ? root.tr("language.auto") : root.service ? root.service.effectiveLocale.toUpperCase() : "EN"
      accessibleLabel: root.tr("language.change")
      implicitWidth: Brand.space(40)
      variant: "subtle"
      onClicked: root.localeToggled()
    }
    IconButton {
      objectName: "vpnClose"
      icon: "󰅖"
      tooltipText: root.tr("action.close")
      onClicked: root.closeRequested()
    }
  }
  Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Brand.borderSubtle }
}
