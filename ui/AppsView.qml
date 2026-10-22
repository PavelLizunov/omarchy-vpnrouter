pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../lib/I18n.js" as I18n
import "../lib/Model.js" as Model

Item {
  id: root
  objectName: "vpnAppsView"
  property var service: null
  property var appLibrary: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string searchQuery: ""

  function tr(key, args) {
    var _ = root.i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Brand.space(480)
  implicitHeight: column.implicitHeight
  readonly property string routingMode: service ? service.routingMode : "split"
  readonly property string routingAppsMode: service ? service.routingAppsMode : "include"
  readonly property var configuredApps: !service || !service.apps ? [] : (routingAppsMode === "include" ? service.apps.include : service.apps.exclude) || []
  // Shared reactive host model; no helper, polling or shell IPC command.
  property var windowToplevels: Hyprland.toplevels.values
  property bool otherProcessesExpanded: false
  onSearchQueryChanged: root.otherProcessesExpanded = root.searchQuery.trim().length > 0
  readonly property var suggestions: Model.runningApplications(root.service ? root.service.apps : null, root.searchQuery, root.windowToplevels)
  readonly property var runningApps: root.suggestions.filter(function(app) { return !!app.desktopId || app.hasWindow })
  readonly property var otherProcesses: root.suggestions.filter(function(app) { return !app.desktopId && !app.hasWindow })
  readonly property bool hasSuggestions: !!(service && service.apps && Array.isArray(service.apps.runningApps))

  function appIconSource(name) {
    // Match the dock: the shell index also finds icons added after startup.
    if (root.appLibrary && typeof root.appLibrary.iconSource === "function") return root.appLibrary.iconSource(name)
    return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true)
  }

  function addApp(name) {
    if (!name || !root.service) return
    var trimmed = String(name).trim()
    if (!trimmed) return
    var list = root.configuredApps.slice()
    if (list.indexOf(trimmed) === -1) {
      list.push(trimmed)
      root.service.setApps(root.routingAppsMode, list)
    }
  }

  function removeApp(name) {
    if (root.service) root.service.setApps(root.routingAppsMode, root.configuredApps.filter(function(item) { return item !== name }))
  }

  Column {
    id: column
    width: parent.width
    spacing: Brand.space(10)

    RoutingControls {
      width: parent.width
      service: root.service
      i18nRevision: root.i18nRevision
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.tr("apps.matchHint")
      wrapMode: Text.WordWrap
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.caption
    }

    RowLayout {
      width: parent.width
      TextField {
        id: customAppInput
        Layout.fillWidth: true
        placeholderText: root.tr("apps.customAppPlaceholder")
        onAccepted: { root.addApp(text); clear() }
      }
      Button {
        text: root.tr("apps.addApp")
        variant: "primary"
        enabled: customAppInput.text.trim().length > 0
        onClicked: { root.addApp(customAppInput.text); customAppInput.clear() }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.tr("apps.configuredHeader", [root.configuredApps.length])
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.title
    }
    Text {
      textFormat: Text.PlainText
      visible: !root.configuredApps.length
      width: parent.width
      text: root.tr("apps.empty")
      wrapMode: Text.WordWrap
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.bodySmall
    }
    Repeater {
      model: root.configuredApps
      Rectangle {
        id: configuredRow
        required property string modelData
        width: column.width
        height: Brand.spacing.controlHeight + Brand.space(8)
        radius: Brand.cornerRadius
        color: Brand.normalFill
        border.color: Brand.normalBorderColor
        border.width: Brand.normalBorderWidth
        RowLayout {
          anchors.fill: parent
          anchors.margins: Brand.space(4)
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            Layout.leftMargin: Brand.space(6)
            text: configuredRow.modelData
            elide: Text.ElideRight
            color: Brand.textPrimary
            font.family: Brand.font.family
            font.pixelSize: Brand.font.bodySmall
          }
          IconButton {
            icon: "󰅖"
            tooltipText: root.tr("apps.removeApp", [configuredRow.modelData])
            onClicked: root.removeApp(configuredRow.modelData)
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.tr("apps.runningHeader")
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.title
    }
    TextField {
      width: parent.width
      visible: root.hasSuggestions
      placeholderText: root.tr("apps.searchPlaceholder")
      onTextChanged: root.searchQuery = text
    }
    Text {
      textFormat: Text.PlainText
      visible: !root.runningApps.length && !root.otherProcesses.length
      width: parent.width
      text: root.service && root.service.activeOperation === "apps.list" && !root.service.appsLoaded ? root.tr("list.loading") : !root.hasSuggestions ? root.tr("apps.legacyHint") : root.searchQuery.trim() ? root.tr("apps.noMatches") : root.tr("apps.runningEmpty")
      wrapMode: Text.WordWrap
      color: Brand.textPrimary
      font.family: Brand.font.family
      font.pixelSize: Brand.font.bodySmall
    }
    Component {
      id: applicationRow
      Rectangle {
        id: appDelegate
        required property var modelData
        objectName: "vpnAppRow-" + appDelegate.modelData.name
        width: column.width
        height: appRow.implicitHeight + Brand.space(12)
        radius: Brand.cornerRadius
        color: Brand.normalFill
        border.color: Brand.normalBorderColor
        border.width: Brand.normalBorderWidth
        RowLayout {
          id: appRow
          anchors.fill: parent
          anchors.margins: Brand.space(6)
          spacing: Brand.space(10)
          Image {
            Layout.preferredWidth: Brand.space(28)
            Layout.preferredHeight: Brand.space(28)
            objectName: "vpnAppIcon-" + appDelegate.modelData.name
            source: root.appIconSource(appDelegate.modelData.icon)
            sourceSize: Qt.size(Brand.space(28), Brand.space(28))
            fillMode: Image.PreserveAspectFit
          }
          Column {
            Layout.fillWidth: true
            spacing: Brand.space(2)
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: appDelegate.modelData.displayName
              elide: Text.ElideRight
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.bodySmall
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.tr("apps.matchName", [appDelegate.modelData.name])
              elide: Text.ElideRight
              color: Brand.textPrimary
              font.family: Brand.font.family
              font.pixelSize: Brand.font.caption
            }
          }
          Button {
            id: appButton
            readonly property bool selected: root.configuredApps.indexOf(appDelegate.modelData.name) !== -1
            text: appButton.selected ? root.tr("apps.selected") : root.tr("action.add")
            enabled: !appButton.selected
            onClicked: root.addApp(appDelegate.modelData.name)
          }
        }
      }
    }
    Repeater {
      model: root.runningApps
      delegate: applicationRow
    }
    Button {
      objectName: "vpnOtherProcessesToggle"
      width: parent.width
      visible: root.otherProcesses.length > 0
      icon: root.otherProcessesExpanded ? "󰅀" : "󰅂"
      text: root.tr("apps.otherProcesses", [root.otherProcesses.length])
      onClicked: root.otherProcessesExpanded = !root.otherProcessesExpanded
    }
    Repeater {
      model: root.otherProcessesExpanded ? root.otherProcesses : []
      delegate: applicationRow
    }

  }
}
