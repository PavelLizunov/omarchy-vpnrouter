import QtQuick
import "../lib/Focus.js" as Focus
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnServersView"

  property var service: null
  property bool showLatency: true
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

  function restoreEntryFocus() {
    Qt.callLater(function() { if (root.visible) importToggleBtn.forceActiveFocus() })
  }

  function cancelForm() {
    if (root.pending) return
    importArea.text = ""
    root.noticeKey = ""
    root.showImportBox = false
    root.restoreEntryFocus()
  }

  function openImportForm() {
    if (root.pending) return
    root.noticeKey = ""
    root.showImportBox = true
    Qt.callLater(function() { importArea.forceActiveFocus() })
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    if (!importArea.text.trim()) { root.noticeError = true; root.noticeKey = "form.required"; return }
    root.pending = true; root.noticeError = false; root.noticeKey = "operation.pending"
    root.service.importServers(importArea.text.trim(), function() {
      root.pending = false; root.noticeKey = "servers.imported"
      importArea.text = ""; root.showImportBox = false
      root.restoreEntryFocus()
    }, function(err) {
      root.pending = false; root.noticeError = true
      root.noticeKey = err && err.code === "invalid_argument" ? "servers.invalidImport" : "form.failed"
    })
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property var filteredServers: Model.groupedServers(service ? service.servers : [], searchQuery)

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    // Top action bar
    Row {
      visible: !root.showImportBox
      width: parent.width
      spacing: Commons.Style.space(8)

      TextField {
        id: searchField
        width: parent.width - importToggleBtn.width - Commons.Style.space(8)
        placeholderText: root.tr("servers.searchPlaceholder")
        onTextChanged: root.searchQuery = text
      }

      Button {
        id: importToggleBtn
        text: "+ " + root.tr("action.import")
        variant: "normal"
        enabled: !root.pending
        onClicked: root.openImportForm()
      }
    }

    Notice {
      objectName: "vpnServersError"
      width: parent.width
      text: root.service ? root.service.lastErrorText : ""
      error: true
      dismissLabel: root.tr("action.dismiss")
      onDismissed: if (root.service) root.service.clearLastError()
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
    Ui.BorderSurface {
      visible: root.showImportBox
      width: parent.width
      height: importCol.implicitHeight + Commons.Style.space(20)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.hoverFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: importCol
        anchors.fill: parent
        anchors.margins: Commons.Style.space(10)
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: root.tr("servers.importTitle")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.title
        }

        Editor {
          id: importArea
          objectName: "vpnServerImport"
          width: parent.width
          height: Commons.Style.space(90)
          enabled: !root.pending
          label: root.tr("servers.importTitle")
          placeholderText: root.tr("servers.importPlaceholder")
          onSubmitted: root.submit()
        }

        Row {
          spacing: Commons.Style.space(8)

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
      objectName: "vpnServersTestResult"
      width: parent.width
      visible: text.length > 0
      text: {
        var _ = root.i18nRevision
        return root.service ? Model.testText(root.service.serverTest, root.service.servers, ({ t: root.tr })) : ""
      }
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
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
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }

    // Empty state
    Ui.BorderSurface {
      visible: !root.showImportBox && root.filteredServers.length === 0
      width: parent.width
      height: emptyColumn.implicitHeight + Commons.Style.space(32)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.normalFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: emptyColumn
        width: parent.width - Commons.Style.space(24)
        anchors.centerIn: parent
        spacing: Commons.Style.space(8)

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰒋"
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
          text: root.service && root.service.activeOperation === "servers.list" && !root.service.serversLoaded ? root.tr("list.loading") : root.searchQuery.trim() ? root.tr("servers.noMatches") : root.tr("servers.empty")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
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
        spacing: Commons.Style.space(6)
        Text {
          textFormat: Text.PlainText
          visible: index === 0 || Model.serverSourceKey(root.filteredServers[index - 1]) !== Model.serverSourceKey(modelData)
          width: parent.width
          text: Model.serverSourceLabel(modelData, root.service ? root.service.subscriptions : [], ({ t: root.tr }))
          wrapMode: Text.WordWrap
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.caption
          font.weight: Font.DemiBold
        }
        Ui.CursorSurface {
          id: serverRowRect
          readonly property string probeOperation: Model.probeOperation(root.service, "servers", modelData.id)
          objectName: "vpnServerRow-" + modelData.id
          activeFocusOnTab: true
          Keys.onReturnPressed: if (root.service) root.service.selectServer(modelData.id)
          Keys.onEnterPressed: if (root.service) root.service.selectServer(modelData.id)
          Keys.onSpacePressed: if (root.service) root.service.selectServer(modelData.id)
          Accessible.role: Accessible.RadioButton
          Accessible.name: modelData.name || root.tr("servers.unnamed")
          Accessible.checked: modelData.selected === true
          width: column.width
          height: rowContent.implicitHeight + Commons.Style.space(14)
          radius: Commons.Style.cornerRadius
          current: modelData.selected === true
          hasCursor: rowMouse.containsMouse || activeFocus
          foreground: Commons.Color.popups.text
          borderSpec: activeFocus ? Commons.Border.controlSpec("focus", foreground, accent)
            : hasCursor ? Commons.Border.controlSpec("hover-cursor", foreground, accent)
            : Commons.Border.controlSpec(current ? "selected" : "normal", foreground, accent)

          // Row selection MouseArea in its own background/selection domain (z: 0)
          // Bounded to cover the row up to rowActions so it never overlaps the action buttons
          MouseArea {
            id: rowMouse
            z: 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: rowActions.width + Commons.Style.space(16)
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
            anchors.margins: Commons.Style.space(8)
            spacing: Commons.Style.space(10)

            // Selection Radio / Check indicator
            Rectangle {
              width: Commons.Style.space(18)
              height: width
              radius: width / 2
              anchors.verticalCenter: parent.verticalCenter
              color: "transparent"
              border.color: Commons.Color.popups.text
              border.width: 2

              Rectangle {
                visible: modelData.selected === true
                width: Commons.Style.space(8)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: Commons.Color.accent
              }
            }

            // Name & Protocol
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - rowActions.width - Commons.Style.space(60)
              spacing: Commons.Style.space(2)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: modelData.name || root.tr("servers.unnamed")
                color: Commons.Color.popups.text
                font.weight: Font.DemiBold
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.bodySmall
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

              Row {
                height: latencyPill.height
                spacing: Commons.Style.space(6)

                Rectangle {
                  height: Commons.Style.space(16)
                  width: protoLabel.implicitWidth + Commons.Style.space(8)
                  radius: height / 2
                  color: Commons.Style.normalFill

                  Text {
                    textFormat: Text.PlainText
                    id: protoLabel
                    anchors.centerIn: parent
                    text: Model.protocolDisplay(modelData.protocol, ({ t: root.tr }))
                    color: Commons.Color.popups.text
                    font.family: Commons.Style.font.family
                    font.pixelSize: Commons.Style.font.caption
                  }
                }

                LatencyPill {
                  id: latencyPill
                  visible: root.showLatency && known
                  latency: modelData.latencyMs
                  label: Model.formatLatency(modelData.latencyMs, ({ t: root.tr }))
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
              Text {
                objectName: "vpnProbeOperation-" + modelData.id
                width: parent.width
                visible: serverRowRect.probeOperation !== ""
                text: root.tr(serverRowRect.probeOperation === "verify" ? "verify.pending" : "test.pending")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
              }
            }

            // Action buttons domain (z: 2)
            Row {
              id: rowActions
              z: 2
              anchors.verticalCenter: parent.verticalCenter
              spacing: Commons.Style.space(4)

              IconButton {
                icon: "󰓅"
                busy: serverRowRect.probeOperation === "test"
                tooltipText: root.tr("action.test")
                enabled: !!root.service && !root.service.activeOperation
                onClicked: if (root.service) root.service.testServer(modelData.id)
              }

              IconButton {
                icon: "󰄬"
                busy: serverRowRect.probeOperation === "verify"
                tooltipText: root.tr("action.verify")
                enabled: !!root.service && !root.service.activeOperation
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
    Button {
      objectName: "vpnLoadMoreServers"
      text: root.tr("list.loadMore")
      visible: !!root.service && root.service.servers.length < root.service.serversTotal
      enabled: !!root.service && !root.service.activeOperation
      onClicked: root.service.listServers(root.service.servers.length, 100)
    }
  }
}
