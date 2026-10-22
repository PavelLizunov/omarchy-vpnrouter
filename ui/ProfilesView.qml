import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(10)

    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: "󰑤 " + root.tr("profiles.refresh")
        variant: "primary"
        onClicked: if (root.service) root.service.refreshProfiles()
      }
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.profiles || root.service.profiles.length === 0
      width: parent.width
      height: Style.space(120)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: 1

      Column {
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰒓"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("profiles.empty")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Profiles list
    Repeater {
      model: root.service ? root.service.profiles : []

      Rectangle {
        width: column.width
        height: profileRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius
        color: modelData.selected ? Style.selectedFill : (profMouse.containsMouse ? Style.hoverFill : Style.normalFill)
        border.color: modelData.selected ? Commons.Color.accent : Style.normalBorderColor
        border.width: modelData.selected ? 1 : Style.normalBorderWidth

        Row {
          id: profileRow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

          // Selection Radio
          Rectangle {
            width: Style.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Commons.Color.accent : Commons.Color.foreground
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Style.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Commons.Color.accent
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - actBtn.width - Style.space(50)
            text: modelData.name || modelData.id
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
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
          anchors.rightMargin: actBtn.width + Style.space(16)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectProfiles([modelData.id])
        }
      }
    }
  }
}
