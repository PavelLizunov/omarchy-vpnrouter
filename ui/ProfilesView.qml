pragma ComponentBehavior: Bound
import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnProfilesView"
  property var service: null
  readonly property bool loading: !!service && ["profiles.list", "profiles.refresh"].indexOf(service.activeOperation) !== -1
  readonly property bool loadFailed: !!service && !!service.lastError && ["profiles.list", "profiles.refresh"].indexOf(service.lastErrorMethod) !== -1
  readonly property bool pending: !!service && (!!service.activeOperation || service.busy)
  readonly property bool canEdit: !!service && service.routingMode === "split" && service.routingAppsMode === "include"
  readonly property var includedApps: service && service.apps && Array.isArray(service.apps.include) ? service.apps.include : []
  property int i18nRevision: service ? service.i18nRevision : 0

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  function appSelected(name) {
    return root.includedApps.some(function(app) { return app.toLowerCase() === name.toLowerCase() })
  }

  function selectedCount(names) {
    return names.filter(function(name) { return root.appSelected(name) }).length
  }

  function setAppsSelected(names, selected) {
    if (!root.canEdit || !root.service.appsLoaded || root.pending || !names.length) return
    var keys = names.map(function(name) { return name.toLowerCase() })
    var next = root.includedApps.filter(function(name) { return selected || keys.indexOf(name.toLowerCase()) === -1 })
    if (selected) names.forEach(function(name) {
      if (!next.some(function(app) { return app.toLowerCase() === name.toLowerCase() })) next.push(name)
    })
    root.service.setApps("include", next)
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(10)

    Text {
      width: parent.width
      text: root.tr("profiles.hint")
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }

    Text {
      visible: !root.canEdit
      width: parent.width
      text: root.tr(root.service && root.service.routingMode === "full" ? "profiles.fullMode" : "profiles.excludeMode")
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }

    Button {
      icon: "󰓦"
      busy: root.loading
      enabled: !root.pending
      text: root.tr("profiles.refresh")
      onClicked: if (root.service) root.service.refreshProfiles()
    }

    Text {
      visible: !root.service || !root.service.profiles || root.service.profiles.length === 0
      width: parent.width
      text: root.loading ? root.tr("profiles.loading") : !root.service || root.loadFailed ? root.tr("state.unavailable") : root.tr("profiles.empty")
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      color: Commons.Color.popups.text
      font.family: Commons.Style.font.family
      font.pixelSize: Commons.Style.font.bodySmall
    }

    Repeater {
      model: root.service ? root.service.profiles : []
      Ui.BorderSurface {
        id: group
        required property var modelData
        // Repeater wraps nested arrays as QML array-like values.
        readonly property var processes: modelData.processes ? Array.prototype.slice.call(modelData.processes) : []
        readonly property int selectedApps: root.selectedCount(processes)
        width: column.width
        implicitHeight: groupColumn.implicitHeight + Commons.Style.space(16)
        radius: Commons.Style.cornerRadius
        color: Commons.Style.normalFill
        borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

        Column {
          id: groupColumn
          width: parent.width - Commons.Style.space(16)
          x: Commons.Style.space(8)
          y: Commons.Style.space(8)
          spacing: Commons.Style.space(8)

          Toggle {
            width: parent.width
            label: group.modelData.name || group.modelData.id
            description: root.tr("profiles.selection", [group.selectedApps, group.processes.length])
            checked: group.processes.length > 0 && group.selectedApps === group.processes.length
            enabled: root.canEdit && root.service.appsLoaded && !root.pending && group.processes.length > 0
            onToggled: function(selected) { root.setAppsSelected(group.processes, selected) }
          }

          Text {
            visible: !!group.modelData.description
            width: parent.width
            text: group.modelData.description || ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
          }

          Text {
            visible: !group.processes.length
            width: parent.width
            text: root.tr("profiles.backendUpdate")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
          }

          Repeater {
            model: group.processes
            Toggle {
              required property string modelData
              width: groupColumn.width
              label: modelData
              checked: root.appSelected(modelData)
              enabled: root.canEdit && root.service.appsLoaded && !root.pending
              onToggled: function(selected) { root.setAppsSelected([modelData], selected) }
            }
          }
        }
      }
    }
  }
}
