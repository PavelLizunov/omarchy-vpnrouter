import QtQuick
import "../lib/Focus.js" as Focus
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnProfilesView"

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    Row {
      width: parent.width
      spacing: Commons.Style.space(8)

      Button {
        icon: "󰓦"
        text: root.tr("profiles.refresh")
        variant: "primary"
        onClicked: if (root.service) root.service.refreshProfiles()
      }
    }

    // Empty state
    Ui.BorderSurface {
      visible: !root.service || !root.service.profiles || root.service.profiles.length === 0
      width: parent.width
      height: Math.max(Commons.Style.space(120), emptyContent.implicitHeight + Commons.Style.space(32))
      radius: Commons.Style.cornerRadius
      color: Commons.Style.normalFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: emptyContent
        width: parent.width - Commons.Style.space(32)
        anchors.centerIn: parent
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰘮"
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.tr("profiles.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }
    }

    // Profiles list
    Repeater {
      model: root.service ? root.service.profiles : []

      Ui.CursorSurface {
        width: column.width
        height: profileRow.implicitHeight + Commons.Style.space(16)
        radius: Commons.Style.cornerRadius
        current: modelData.selected === true
        hasCursor: profMouse.containsMouse || activeFocus
        foreground: Commons.Color.popups.text

        Row {
          id: profileRow
          z: 1
          anchors.fill: parent
          anchors.margins: Commons.Style.space(8)
          spacing: Commons.Style.space(10)

          // Selection Radio
          Rectangle {
            width: Commons.Style.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Commons.Color.accent : Commons.Color.popups.text
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Commons.Style.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Commons.Color.accent
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - actBtn.width - Commons.Style.space(50)
            text: modelData.name || modelData.id
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            id: fullName1
            elide: Text.ElideMiddle
            activeFocusOnTab: truncated
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(fullName1) })
            HoverHandler { id: nameHover1 }
            Ui.PanelToolTip {
              width: Math.min(implicitWidth, Commons.Style.space(360))
              visible: fullName1.truncated && (nameHover1.hovered || fullName1.activeFocus)
              text: fullName1.text
              timeout: 0
              contentItem: Text {
                width: Math.min(implicitWidth, Commons.Style.space(340))
                text: fullName1.text
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.tooltip.text
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.bodySmall
                padding: Commons.Style.spacing.controlPaddingX
              }
            }
          }

          Button {
            id: actBtn
            text: root.tr("profiles.select")
            variant: modelData.selected ? "subtle" : "normal"
            enabled: !modelData.selected
            anchors.verticalCenter: parent.verticalCenter
            onClicked: if (root.service) root.service.selectProfiles([modelData.id])
          }
        }

        MouseArea {
          id: profMouse
          anchors.fill: parent
          anchors.rightMargin: actBtn.width + Commons.Style.space(16)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectProfiles([modelData.id])
        }
      }
    }
  }
}
