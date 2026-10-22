import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string searchQuery: ""
  signal addSubscriptionRequested()
  property bool showImportBox: false

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function submit() {
    var text = importArea.text.trim()
    if (!root.service || !text) return
    root.service.importServers(text)
    importArea.text = ""
    root.showImportBox = false
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property var filteredServers: Model.groupedServers(service ? service.servers : [], searchQuery)

  Column {
    id: column
    width: parent.width
    spacing: Style.space(10)

    // Top action bar
    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: searchField
        width: parent.width - importToggleBtn.width - Style.space(8)
        placeholderText: root.tr("servers.searchPlaceholder")
        onTextChanged: root.searchQuery = text
      }

      Button {
        id: importToggleBtn
        text: root.showImportBox ? root.tr("action.cancel") : "+ " + root.tr("action.import")
        variant: root.showImportBox ? "subtle" : "normal"
        onClicked: root.showImportBox = !root.showImportBox
      }
    }

    // Collapsible Import Form
    Rectangle {
      visible: root.showImportBox
      width: parent.width
      height: importCol.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Style.hoverFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: importCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("servers.importTitle")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        Rectangle {
          width: parent.width
          height: Style.space(70)
          radius: Style.cornerRadius
          color: Style.normalFill
          border.color: importArea.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
          border.width: importArea.activeFocus ? Style.focusBorderWidth : 1

          TextEdit {
            id: importArea
            activeFocusOnTab: true
            textFormat: TextEdit.PlainText
            Keys.onPressed: function(event) {
              if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) { root.submit(); event.accepted = true }
            }
            anchors.fill: parent
            anchors.margins: Style.space(6)
            wrapMode: TextEdit.Wrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Commons.Color.foreground
            selectionColor: Commons.Color.accent
            selectedTextColor: Commons.Color.background

            Text {
              textFormat: Text.PlainText
              width: parent.width
              wrapMode: Text.WordWrap
              visible: importArea.text.length === 0
              text: root.tr("servers.importPlaceholder")
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: root.tr("servers.importBtn")
            variant: "primary"
            enabled: importArea.text.trim().length > 0
            onClicked: root.submit()
          }

          Button {
            text: root.tr("action.cancel")
            variant: "subtle"
            onClicked: {
              importArea.text = ""
              root.showImportBox = false
            }
          }
        }
      }
    }

    Text {
      width: parent.width
      visible: text.length > 0
      text: {
        var _ = root.i18nRevision
        return root.service ? Model.verificationText(root.service.serverVerification, root.service.servers, ({ t: root.tr })) : ""
      }
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: root.service && root.service.serverVerification && root.service.serverVerification.ok === true ? Commons.Color.accent : Commons.Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    // Empty state
    Rectangle {
      visible: root.filteredServers.length === 0
      width: parent.width
      height: emptyColumn.implicitHeight + Style.space(32)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: 1

      Column {
        id: emptyColumn
        width: parent.width - Style.space(24)
        anchors.centerIn: parent
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰒋"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.service && root.service.activeOperation === "servers.list" && !root.service.serversLoaded ? root.tr("list.loading") : root.searchQuery.trim() ? root.tr("servers.noMatches") : root.tr("servers.empty")
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.service && root.service.serversLoaded && root.service.servers.length === 0
          text: root.tr("firstRun.addSubscription")
          variant: "primary"
          onClicked: root.addSubscriptionRequested()
        }
      }
    }

    // Server rows list
    Repeater {
      model: root.filteredServers

      Column {
        width: column.width
        spacing: Style.space(6)
        Text {
          textFormat: Text.PlainText
          visible: index === 0 || Model.serverSourceKey(root.filteredServers[index - 1]) !== Model.serverSourceKey(modelData)
          width: parent.width
          text: Model.serverSourceLabel(modelData, root.service ? root.service.subscriptions : [], ({ t: root.tr }))
          wrapMode: Text.WordWrap
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }
        Rectangle {
          id: serverRowRect
          activeFocusOnTab: true
          Keys.onReturnPressed: if (root.service) root.service.selectServer(modelData.id)
          Keys.onSpacePressed: if (root.service) root.service.selectServer(modelData.id)
          Accessible.role: Accessible.RadioButton
          Accessible.name: modelData.name || root.tr("servers.unnamed")
          Accessible.checked: modelData.selected === true
          width: column.width
          height: rowContent.implicitHeight + Style.space(14)
          radius: Style.cornerRadius
          color: modelData.selected ? Style.selectedFill : (rowMouse.containsMouse ? Style.hoverFill : Style.normalFill)
          border.color: activeFocus ? Style.focusBorderColor : modelData.selected ? Commons.Color.accent : Style.normalBorderColor
          border.width: modelData.selected ? 1 : Style.normalBorderWidth

          // Row selection MouseArea in its own background/selection domain (z: 0)
          // Bounded to cover the row up to rowActions so it never overlaps the action buttons
          MouseArea {
            id: rowMouse
            z: 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: rowActions.width + Style.space(16)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.service) root.service.selectServer(modelData.id)
            }
          }

          Row {
            id: rowContent
            z: 1
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(10)

            // Selection Radio / Check indicator
            Rectangle {
              width: Style.space(18)
              height: width
              radius: width / 2
              anchors.verticalCenter: parent.verticalCenter
              color: "transparent"
              border.color: modelData.selected ? Commons.Color.accent : Commons.Color.foreground
              border.width: 2

              Rectangle {
                visible: modelData.selected === true
                width: Style.space(8)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: Commons.Color.accent
              }
            }

            // Name & Protocol
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - rowActions.width - Style.space(60)
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData.name || root.tr("servers.unnamed")
                color: modelData.selected ? Commons.Color.accent : Commons.Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Row {
                spacing: Style.space(6)

                Rectangle {
                  height: Style.space(16)
                  width: protoLabel.implicitWidth + Style.space(8)
                  radius: Style.cornerRadius
                  color: Style.hoverFill

                  Text {
                    textFormat: Text.PlainText
                    id: protoLabel
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
                  color: {
                    var tier = Model.latencyTier(modelData.latencyMs)
                    if (tier === "good") return Commons.Color.accent
                    if (tier === "medium") return Commons.Color.foreground
                    if (tier === "poor") return Commons.Color.urgent
                    return Commons.Color.foreground
                  }
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            // Action buttons domain (z: 2)
            Row {
              id: rowActions
              z: 2
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              IconButton {
                icon: "󰓠"
                tooltipText: root.tr("action.test")
                onClicked: if (root.service) root.service.testServer(modelData.id)
              }

              IconButton {
                icon: "󰄬"
                tooltipText: root.tr("action.verify")
                onClicked: if (root.service) root.service.verifyServer(modelData.id)
              }

              IconButton {
                icon: "󰆴"
                variant: "danger"
                visible: modelData.removable === true
                tooltipText: root.tr("action.remove")
                onClicked: if (root.service) root.service.removeServer(modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
