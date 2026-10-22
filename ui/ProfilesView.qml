import QtQuick
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

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(10)

    Row {
      width: parent.width
      spacing: Brand.space(8)

      Button {
        icon: "󰑤"
        text: root.tr("profiles.refresh")
        variant: "primary"
        onClicked: if (root.service) root.service.refreshProfiles()
      }
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.profiles || root.service.profiles.length === 0
      width: parent.width
      height: Brand.space(120)
      radius: Brand.cornerRadius
      color: Brand.normalFill
      border.color: Brand.normalBorderColor
      border.width: 1

      Column {
        anchors.centerIn: parent
        spacing: Brand.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰒓"
          color: Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("profiles.empty")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
        }
      }
    }

    // Profiles list
    Repeater {
      model: root.service ? root.service.profiles : []

      Rectangle {
        width: column.width
        height: profileRow.implicitHeight + Brand.space(16)
        radius: Brand.cornerRadius
        color: modelData.selected ? Brand.selectedFill : (profMouse.containsMouse ? Brand.hoverFill : Brand.normalFill)
        border.color: modelData.selected ? Brand.accentFg : Brand.normalBorderColor
        border.width: modelData.selected ? 1 : Brand.normalBorderWidth

        Row {
          id: profileRow
          anchors.fill: parent
          anchors.margins: Brand.space(8)
          spacing: Brand.space(10)

          // Selection Radio
          Rectangle {
            width: Brand.space(18)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: modelData.selected ? Brand.accentFg : Brand.textPrimary
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Brand.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Brand.accentFg
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width - actBtn.width - Brand.space(50)
            text: modelData.name || modelData.id
            color: Brand.textPrimary
            font.family: Brand.font.family
            font.pixelSize: Brand.font.bodySmall
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
          anchors.rightMargin: actBtn.width + Brand.space(16)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.service) root.service.selectProfiles([modelData.id])
        }
      }
    }
  }
}
