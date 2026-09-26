import QtQuick
import qs.Commons 1.0
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string searchQuery: ""
  property bool showImportBox: false

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property var filteredServers: Model.filterServers(service ? service.servers : [], searchQuery)

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
          text: root.tr("servers.importTitle")
          color: Color.foreground
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
            anchors.fill: parent
            anchors.margins: Style.space(6)
            wrapMode: TextEdit.Wrap
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: Color.foreground
            selectionColor: Color.accent
            selectedTextColor: Color.background

            Text {
              visible: importArea.text.length === 0
              text: root.tr("servers.importPlaceholder")
              color: Color.muted
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
            onClicked: {
              if (root.service) {
                var txt = importArea.text
                importArea.text = ""
                root.showImportBox = false
                root.service.importServers(txt)
              }
            }
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

    // Empty state
    Rectangle {
      visible: root.filteredServers.length === 0
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
          anchors.horizontalCenter: parent.horizontalCenter
          text: "󰒋"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.display
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.tr("servers.empty")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }

    // Server rows list
    Repeater {
      model: root.filteredServers

      Rectangle {
        id: serverRowRect
        width: column.width
        height: rowContent.implicitHeight + Style.space(14)
        radius: Style.cornerRadius
        color: modelData.selected ? Style.selectedFill : (rowMouse.containsMouse ? Style.hoverFill : Style.normalFill)
        border.color: modelData.selected ? Color.accent : Style.normalBorderColor
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
            border.color: modelData.selected ? Color.accent : Color.muted
            border.width: 2

            Rectangle {
              visible: modelData.selected
              width: Style.space(8)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: Color.accent
            }
          }

          // Name & Protocol
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - rowActions.width - Style.space(60)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: modelData.name || "Unnamed Server"
              color: modelData.selected ? Color.accent : Color.foreground
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
                  id: protoLabel
                  anchors.centerIn: parent
                  text: Model.protocolDisplay(modelData.protocol)
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                text: Model.formatLatency(modelData.latencyMs)
                color: {
                  var tier = Model.latencyTier(modelData.latencyMs)
                  if (tier === "good") return Color.accent
                  if (tier === "medium") return Color.foreground
                  if (tier === "poor") return Color.urgent
                  return Color.muted
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
              tooltipText: root.tr("action.remove")
              onClicked: if (root.service) root.service.removeServer(modelData.id)
            }
          }
        }
      }
    }
  }
}
