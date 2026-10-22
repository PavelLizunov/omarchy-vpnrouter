import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons 1.0
import qs.Commons 1.0 as Commons
import "../lib/I18n.js" as I18n
import "../lib/Model.js" as Model

Item {
  id: root
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string searchQuery: ""

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight
  readonly property string routingMode: service ? service.routingMode : "split"
  readonly property string routingAppsMode: service ? service.routingAppsMode : "include"
  readonly property var configuredApps: !service || !service.apps ? [] : (routingAppsMode === "include" ? service.apps.include : service.apps.exclude) || []
  readonly property var runningApps: Model.runningApplications(service ? service.apps : null, searchQuery)
  readonly property bool hasSuggestions: !!(service && service.apps && Array.isArray(service.apps.runningApps))

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
    spacing: Style.space(10)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.tr("apps.matchHint")
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
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
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }
    Text {
      textFormat: Text.PlainText
      visible: !root.configuredApps.length
      width: parent.width
      text: root.tr("apps.empty")
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    Repeater {
      model: root.configuredApps
      Rectangle {
        width: column.width
        height: Style.spacing.controlHeight + Style.space(8)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth
        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            Layout.leftMargin: Style.space(6)
            text: modelData
            elide: Text.ElideRight
            color: Commons.Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          IconButton {
            icon: "󰅖"
            tooltipText: root.tr("apps.removeApp", [modelData])
            onClicked: root.removeApp(modelData)
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.tr("apps.runningHeader")
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }
    TextField {
      width: parent.width
      visible: root.hasSuggestions
      placeholderText: root.tr("apps.searchPlaceholder")
      onTextChanged: root.searchQuery = text
    }
    Text {
      textFormat: Text.PlainText
      visible: !root.runningApps.length
      width: parent.width
      text: root.service && root.service.activeOperation === "apps.list" && !root.service.appsLoaded ? root.tr("list.loading") : !root.hasSuggestions ? root.tr("apps.legacyHint") : root.searchQuery.trim() ? root.tr("apps.noMatches") : root.tr("apps.runningEmpty")
      wrapMode: Text.WordWrap
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    Repeater {
      model: root.runningApps
      Rectangle {
        width: column.width
        height: appRow.implicitHeight + Style.space(12)
        radius: Style.cornerRadius
        color: Style.normalFill
        border.color: Style.normalBorderColor
        border.width: Style.normalBorderWidth
        RowLayout {
          id: appRow
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(10)
          Image {
            Layout.preferredWidth: Style.space(28)
            Layout.preferredHeight: Style.space(28)
            source: Quickshell.iconPath(modelData.icon, true) || Quickshell.iconPath("application-x-executable", true)
            sourceSize: Qt.size(Style.space(28), Style.space(28))
            fillMode: Image.PreserveAspectFit
          }
          Column {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: modelData.displayName
              elide: Text.ElideRight
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.tr("apps.matchName", [modelData.name])
              elide: Text.ElideRight
              color: Commons.Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }
          Button {
            readonly property bool selected: root.configuredApps.indexOf(modelData.name) !== -1
            text: selected ? root.tr("apps.selected") : root.tr("action.add")
            enabled: !selected
            onClicked: root.addApp(modelData.name)
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.tr("apps.routingMode")
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }
    Toggle {
      width: parent.width
      label: root.tr("apps.routingMode.full")
      description: root.routingMode === "split" ? root.tr("apps.routingMode.split") : ""
      checked: root.routingMode === "full"
      onToggled: function(value) { if (root.service) root.service.setRouting(value ? "full" : "split", root.routingAppsMode) }
    }
    Toggle {
      width: parent.width
      label: root.tr("apps.appsMode.exclude")
      description: root.routingAppsMode === "include" ? root.tr("apps.appsMode.include") : ""
      checked: root.routingAppsMode === "exclude"
      onToggled: function(value) { if (root.service) root.service.setRouting(root.routingMode, value ? "exclude" : "include") }
    }
  }
}
