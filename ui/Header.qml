import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string mode: "simple" // "simple" | "advanced"
  readonly property string currentLocale: {
    var _ = i18nRevision
    return root.service ? root.service.effectiveLocale : "en"
  }

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  signal modeChangeRequested(string nextMode)
  signal localeToggled()
  signal closeRequested()

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: headerTop.implicitHeight + stateBadge.implicitHeight + Style.space(8)

  Row {
    id: headerTop
    anchors.left: parent.left
    anchors.right: headerActions.left
    anchors.rightMargin: Style.space(8)
    anchors.top: parent.top
    spacing: Style.space(10)

    Text {
      text: "󰖂"
      color: root.service && root.service.isConnected ? Commons.Color.accent : Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      width: parent.width - Style.space(32)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        text: root.tr("app.name")
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.title
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.tr("app.subtitle")
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

  }

  StatusBadge {
    id: stateBadge
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    service: root.service
    i18nRevision: root.i18nRevision
    state: root.service ? root.service.state : "unavailable"
  }

  Row {
    id: headerActions
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Style.space(6)

    // Explicit overrides cycle back to the shell language (AUTO).
    Rectangle {
      id: langButton
      activeFocusOnTab: true
      Keys.onReturnPressed: root.localeToggled()
      Keys.onSpacePressed: root.localeToggled()
      width: Style.space(48)
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius
      color: langMouse.containsMouse ? Style.hoverFill : Style.normalFill
      border.color: (langButton.activeFocus || langMouse.activeFocus) ? Style.focusBorderColor : Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Text {
        anchors.centerIn: parent
        text: root.service && root.service.locale === "auto" ? "AUTO" : root.currentLocale.toUpperCase()
        color: Commons.Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      MouseArea {
        id: langMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { langButton.forceActiveFocus(); root.localeToggled() }
      }
    }

    // Mode Toggle (Simple / Advanced)
    Rectangle {
      id: modeButton
      activeFocusOnTab: true
      Keys.onReturnPressed: root.modeChangeRequested(root.mode === "simple" ? "advanced" : "simple")
      Keys.onSpacePressed: root.modeChangeRequested(root.mode === "simple" ? "advanced" : "simple")
      width: modeRow.implicitWidth + Style.space(16)
      height: Style.spacing.controlHeight
      radius: Style.cornerRadius
      color: modeMouse.containsMouse ? Style.hoverFill : Style.normalFill
      border.color: (modeButton.activeFocus || modeMouse.activeFocus) ? Style.focusBorderColor : Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Row {
        id: modeRow
        anchors.centerIn: parent
        spacing: Style.space(5)

        Text {
          text: root.mode === "simple" ? "󰒘" : "󰒓"
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.iconSmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.mode === "simple" ? root.tr("mode.simple") : root.tr("mode.advanced")
          color: Commons.Color.foreground
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
          modeButton.forceActiveFocus()
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
