import QtQuick
import qs.Commons 1.0
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  readonly property string routingMode: service ? service.routingMode : "split"
  readonly property string routingAppsMode: service ? service.routingAppsMode : "include"
  readonly property var configuredApps: {
    if (!service || !service.apps) return []
    return routingAppsMode === "include" ? (service.apps.include || []) : (service.apps.exclude || [])
  }
  readonly property var runningApps: (service && service.apps && service.apps.running) ? service.apps.running : []

  function addApp(name) {
    if (!name || !root.service) return
    var trimmed = String(name).trim()
    if (trimmed.length === 0) return
    var list = root.configuredApps.slice()
    if (list.indexOf(trimmed) === -1) {
      list.push(trimmed)
      root.service.setApps(root.routingAppsMode, list)
    }
  }

  function removeApp(name) {
    if (!name || !root.service) return
    var list = root.configuredApps.filter(function(item) { return item !== name })
    root.service.setApps(root.routingAppsMode, list)
  }

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    // Routing Mode Selection Card
    Rectangle {
      width: parent.width
      height: modeCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: modeCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: root.tr("apps.routingMode")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        Row {
          spacing: Style.space(12)

          Toggle {
            label: root.tr("apps.routingMode.split")
            checked: root.routingMode === "split"
            onToggled: function(val) {
              if (root.service) root.service.setRouting(val ? "split" : "full", root.routingAppsMode)
            }
          }

          Toggle {
            label: root.tr("apps.routingMode.full")
            checked: root.routingMode === "full"
            onToggled: function(val) {
              if (root.service) root.service.setRouting(val ? "full" : "split", root.routingAppsMode)
            }
          }
        }
      }
    }

    // Apps Filter Policy Card
    Rectangle {
      width: parent.width
      height: policyCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: policyCol
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(8)

        Text {
          text: root.tr("apps.appsMode")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        Row {
          spacing: Style.space(12)

          Toggle {
            label: root.tr("apps.appsMode.include")
            checked: root.routingAppsMode === "include"
            onToggled: function(val) {
              if (root.service) root.service.setRouting(root.routingMode, val ? "include" : "exclude")
            }
          }

          Toggle {
            label: root.tr("apps.appsMode.exclude")
            checked: root.routingAppsMode === "exclude"
            onToggled: function(val) {
              if (root.service) root.service.setRouting(root.routingMode, val ? "exclude" : "include")
            }
          }
        }
      }
    }

    // Add Custom Process Form
    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: customAppInput
        width: parent.width - addAppBtn.width - Style.space(8)
        placeholderText: root.tr("apps.customAppPlaceholder")
        onAccepted: {
          root.addApp(customAppInput.text)
          customAppInput.clear()
        }
      }

      Button {
        id: addAppBtn
        text: "+ " + root.tr("apps.addApp")
        variant: "primary"
        enabled: customAppInput.text.trim().length > 0
        onClicked: {
          root.addApp(customAppInput.text)
          customAppInput.clear()
        }
      }
    }

    // Running Applications Suggestions
    Rectangle {
      visible: root.runningApps.length > 0
      width: parent.width
      height: runningCol.implicitHeight + Style.space(16)
      radius: Style.cornerRadius
      color: Style.hoverFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: runningCol
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        Text {
          text: root.tr("apps.runningHeader")
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.runningApps

            Rectangle {
              width: chipRow.implicitWidth + Style.space(12)
              height: Style.space(24)
              radius: height / 2
              color: chipMouse.containsMouse ? Style.pressedFill : Style.normalFill
              border.color: Style.normalBorderColor
              border.width: 1

              Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: "+ " + modelData
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addApp(modelData)
              }
            }
          }
        }
      }
    }

    // Configured Applications Header
    Text {
      text: root.tr("apps.configuredHeader", [root.configuredApps.length])
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }

    // Empty configured apps state
    Rectangle {
      visible: root.configuredApps.length === 0
      width: parent.width
      height: Style.space(80)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: 1

      Text {
        anchors.centerIn: parent
        text: root.tr("apps.empty")
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    // Configured Apps List
    Repeater {
      model: root.configuredApps

      Rectangle {
        width: column.width
        height: appRow.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth

        Row {
          id: appRow
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(10)

          Text {
            text: "󰵮"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.iconSmall
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            width: parent.width - deleteAppBtn.width - Style.space(40)
            text: modelData
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          IconButton {
            id: deleteAppBtn
            icon: "󰆴"
            variant: "danger"
            tooltipText: root.tr("action.remove")
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.removeApp(modelData)
          }
        }
      }
    }
  }
}
