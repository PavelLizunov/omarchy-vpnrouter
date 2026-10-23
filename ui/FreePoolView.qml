import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
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

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    // Header action row
    Row {
      width: parent.width
      spacing: Commons.Style.space(8)

      Button {
        icon: "󰓦"
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
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }

    // Empty state
    Ui.BorderSurface {
      visible: !root.service || !root.service.freeServers || root.service.freeServers.length === 0
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
          text: "󰇧"
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
          text: root.tr("free.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }
      }
    }

    // Free servers list
    Repeater {
      model: root.service ? root.service.freeServers : []

      Ui.BorderSurface {
        width: column.width
        height: rowItem.implicitHeight + Commons.Style.space(14)
        radius: Commons.Style.cornerRadius
        color: Commons.Style.normalFill
        borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

        Row {
          id: rowItem
          anchors.fill: parent
          anchors.margins: Commons.Style.space(8)
          spacing: Commons.Style.space(10)

          Text {
            textFormat: Text.PlainText
            text: "󰇧"
            color: Commons.Color.accent
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - freeActions.width - Commons.Style.space(50)
            spacing: Commons.Style.space(2)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.name || root.tr("free.fallbackName")
              color: Commons.Color.popups.text
              font.family: Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
              elide: Text.ElideRight
            }

            Row {
              spacing: Commons.Style.space(6)

              Rectangle {
                height: Commons.Style.space(16)
                width: protoBadge.implicitWidth + Commons.Style.space(8)
                radius: Commons.Style.cornerRadius
                color: Commons.Style.hoverFill

                Text {
                  textFormat: Text.PlainText
                  id: protoBadge
                  anchors.centerIn: parent
                  text: Model.protocolDisplay(modelData.protocol, ({ t: root.tr }))
                  color: Commons.Color.popups.text
                  font.family: Commons.Style.font.family
                  font.pixelSize: Commons.Style.font.caption
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
            spacing: Commons.Style.space(4)

            IconButton {
              icon: "󰓅"
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
