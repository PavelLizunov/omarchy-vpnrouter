import QtQuick
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnServersView"

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string searchQuery: ""
  signal addSubscriptionRequested()
  property bool showImportBox: false
  property bool pending: false
  property string noticeKey: ""
  property bool noticeError: false

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function cancelForm() {
    if (root.pending) return
    importArea.text = ""
    root.noticeKey = ""
    root.showImportBox = false
    importToggleBtn.forceActiveFocus()
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    if (!importArea.text.trim()) { root.noticeError = true; root.noticeKey = "form.required"; return }
    root.pending = true; root.noticeError = false; root.noticeKey = "operation.pending"
    root.service.importServers(importArea.text.trim(), function() {
      root.pending = false; root.noticeKey = "servers.imported"
      importArea.text = ""; root.showImportBox = false
      importToggleBtn.forceActiveFocus()
    }, function(err) {
      root.pending = false; root.noticeError = true
      root.noticeKey = err && err.code === "invalid_argument" ? "servers.invalidImport" : "form.failed"
    })
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
        enabled: !root.pending
        onClicked: {
          if (root.showImportBox) root.cancelForm()
          else { root.noticeKey = ""; root.showImportBox = true; Qt.callLater(function() { importArea.forceActiveFocus() }) }
        }
      }
    }

    Notice {
      id: feedback
      width: parent.width
      text: root.noticeKey ? root.tr(root.noticeKey) : ""
      error: root.noticeError
      dismissLabel: root.tr("action.dismiss")
      onDismissed: root.noticeKey = ""
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

        Editor {
          id: importArea
          objectName: "vpnServerImport"
          width: parent.width
          height: Style.space(90)
          enabled: !root.pending
          label: root.tr("servers.importTitle")
          placeholderText: root.tr("servers.importPlaceholder")
          onSubmitted: root.submit()
        }

        Row {
          spacing: Style.space(8)

          Button {
            text: root.tr("servers.importBtn")
            variant: "primary"
            enabled: !root.pending
            onClicked: root.submit()
          }

          Button {
            text: root.tr("action.cancel")
            variant: "subtle"
            enabled: !root.pending
            onClicked: root.cancelForm()
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
      color: Commons.Color.foreground
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
          objectName: "vpnServerRow-" + modelData.id
          activeFocusOnTab: true
          Keys.onReturnPressed: if (root.service) root.service.selectServer(modelData.id)
          Keys.onEnterPressed: if (root.service) root.service.selectServer(modelData.id)
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
              border.color: Commons.Color.foreground
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
                color: Commons.Color.foreground
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
                  color: Commons.Color.foreground
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
