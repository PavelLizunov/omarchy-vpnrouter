import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnFreePoolView"

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

    // Header action row
    Row {
      width: parent.width
      spacing: Style.space(8)

      Button {
        text: "󰑤 " + root.tr("free.refresh")
        variant: "primary"
        onClicked: if (root.service) root.service.refreshFree()
      }
    }

    Text {
      width: parent.width
      visible: text.length > 0
      text: {
        var _ = root.i18nRevision
        return root.service ? Model.verificationText(root.service.freeVerification, root.service.freeServers, ({ t: root.tr })) : ""
      }
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.freeServers || root.service.freeServers.length === 0
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
          text: "󰓠"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("free.empty")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Free servers list
    Repeater {
      model: root.service ? root.service.freeServers : []

      Rectangle {
        width: column.width
        height: rowItem.implicitHeight + Style.space(14)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth

        Row {
          id: rowItem
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(10)

          Text {
            textFormat: Text.PlainText
            text: "󰓠"
            color: Commons.Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - freeActions.width - Style.space(50)
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("free.fallbackName")
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Row {
              spacing: Style.space(6)

              Rectangle {
                height: Style.space(16)
                width: protoBadge.implicitWidth + Style.space(8)
                radius: Style.cornerRadius
                color: Style.hoverFill

                Text {
                  textFormat: Text.PlainText
                  id: protoBadge
                  anchors.centerIn: parent
                  text: Model.protocolDisplay(modelData.protocol, ({ t: root.tr }))
                  color: Commons.Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                textFormat: Text.PlainText
                text: Model.formatLatency(modelData.latencyMs, ({ t: root.tr }))
                color: Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Row {
            id: freeActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            IconButton {
              icon: "󰓠"
              tooltipText: root.tr("action.test")
              onClicked: if (root.service) root.service.testFree(modelData.id)
            }

            IconButton {
              icon: "󰄬"
              tooltipText: root.tr("action.verify")
              onClicked: if (root.service) root.service.verifyFree(modelData.id)
            }

            Button {
              text: root.tr("free.apply")
              variant: "normal"
              onClicked: if (root.service) root.service.applyFree(modelData.id)
            }
          }
        }
      }
    }
  }
}
