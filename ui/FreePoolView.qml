import QtQuick
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

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(10)

    // Header action row
    Row {
      width: parent.width
      spacing: Brand.space(8)

      Button {
        icon: "󰑤"
        text: root.tr("free.refresh")
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
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.bodySmall
    }

    // Empty state
    Rectangle {
      visible: !root.service || !root.service.freeServers || root.service.freeServers.length === 0
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
          text: "󰓠"
          color: Brand.textPrimary
          font.family: Brand.iconFamily
          font.pixelSize: Brand.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("free.empty")
          color: Brand.textPrimary
          font.family: Brand.font.family
          font.pixelSize: Brand.font.bodySmall
        }
      }
    }

    // Free servers list
    Repeater {
      model: root.service ? root.service.freeServers : []

      Rectangle {
        width: column.width
        height: rowItem.implicitHeight + Brand.space(14)
        radius: Brand.cornerRadius
        color: Brand.normalFill
        border.color: Brand.normalBorderColor
        border.width: Brand.normalBorderWidth

        Row {
          id: rowItem
          anchors.fill: parent
          anchors.margins: Brand.space(8)
          spacing: Brand.space(10)

          Text {
            textFormat: Text.PlainText
            text: "󰓠"
            color: Brand.accentFg
            font.family: Brand.iconFamily
            font.pixelSize: Brand.font.icon
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - freeActions.width - Brand.space(50)
            spacing: Brand.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("free.fallbackName")
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.bodySmall
              elide: Text.ElideRight
            }

            Row {
              spacing: Brand.space(6)

              Rectangle {
                height: Brand.space(16)
                width: protoBadge.implicitWidth + Brand.space(8)
                radius: Brand.cornerRadius
                color: Brand.hoverFill

                Text {
                  textFormat: Text.PlainText
                  id: protoBadge
                  anchors.centerIn: parent
                  text: Model.protocolDisplay(modelData.protocol, ({ t: root.tr }))
                  color: Brand.textPrimary
                  font.family: Brand.font.family
                  font.pixelSize: Brand.font.caption
                }
              }

              LatencyPill {
                latency: modelData.latencyMs
                label: Model.formatLatency(modelData.latencyMs, ({ t: root.tr }))
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Row {
            id: freeActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Brand.space(4)

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
