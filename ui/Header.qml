import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string mode: "simple" // "simple" | "advanced"
  readonly property string currentLocale: {
    var _ = i18nRevision
    return I18n.getEffectiveLocale()
  }

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  signal modeChangeRequested(string nextMode)
  signal localeToggled()
  signal closeRequested()

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: Style.space(44)

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(10)

    Text {
      text: "󰖂"
      color: root.service && root.service.isConnected ? Color.accent : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        text: root.tr("app.name")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
      }

      Text {
        text: root.tr("app.subtitle")
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    StatusBadge {
      anchors.verticalCenter: parent.verticalCenter
      service: root.service
      i18nRevision: root.i18nRevision
      state: root.service ? root.service.state : "unavailable"
    }
  }

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    // Language toggle (EN / RU)
    Rectangle {
      width: Style.space(32)
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius
      color: langMouse.containsMouse ? Style.hoverFill : Style.normalFill
      border.color: langMouse.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Text {
        anchors.centerIn: parent
        text: root.currentLocale.toUpperCase()
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: langMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.localeToggled()
      }
    }

    // Mode Toggle (Simple / Advanced)
    Rectangle {
      width: modeRow.implicitWidth + Style.space(16)
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius
      color: modeMouse.containsMouse ? Style.hoverFill : Style.normalFill
      border.color: modeMouse.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Row {
        id: modeRow
        anchors.centerIn: parent
        spacing: Style.space(5)

        Text {
          text: root.mode === "simple" ? "󰒘" : "󰒓"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.iconSmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.mode === "simple" ? root.tr("mode.simple") : root.tr("mode.advanced")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      MouseArea {
        id: modeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          var next = root.mode === "simple" ? "advanced" : "simple"
          root.modeChangeRequested(next)
        }
      }
    }

    // Close button
    IconButton {
      icon: "󰅖"
      tooltipText: root.tr("action.close")
      onClicked: root.closeRequested()
    }
  }
}
