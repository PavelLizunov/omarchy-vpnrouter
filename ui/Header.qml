pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
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
  implicitHeight: Commons.Style.space(64)
  color: Commons.Color.popups.background
  RowLayout {
    anchors.fill: parent
    anchors.margins: Commons.Style.space(12)
    spacing: Commons.Style.space(12)
    Ui.BorderSurface {
      Layout.preferredWidth: Commons.Style.space(40)
      Layout.preferredHeight: Commons.Style.space(40)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.normalFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)
      Image {
        anchors.fill: parent
        anchors.margins: Commons.Style.space(3)
        source: Brand.mascot
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
      }
    }
    Column {
      Layout.fillWidth: true
      spacing: Commons.Style.space(4)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.tr("app.brand")
        elide: Text.ElideRight
        color: Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.title
        font.bold: true
      }
      Rectangle {
        width: chipRow.implicitWidth + Commons.Style.space(16)
        height: Commons.Style.space(20)
        radius: height / 2
        color: root.service && root.service.isConnected ? Commons.Style.selectedAccentFill : Commons.Style.normalFill
        Row {
          id: chipRow
          anchors.centerIn: parent
          spacing: Commons.Style.space(5)
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Commons.Style.space(5); height: width; radius: width / 2
            color: root.service && root.service.isConnected ? Commons.Color.accent : Commons.Color.popups.text
          }
          Text {
            textFormat: Text.PlainText
            text: root.tr("header.vpn")
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
          }
        }
      }
    }
    Button {
      objectName: "vpnLanguage"
      text: root.service && root.service.locale === "auto" ? root.tr("language.auto") : root.service ? root.service.effectiveLocale.toUpperCase() : "EN"
      accessibleLabel: root.tr("language.change")
      tooltipText: accessibleLabel
      implicitWidth: Commons.Style.space(40)
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
  Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Commons.Style.normalBorderColor }
}
