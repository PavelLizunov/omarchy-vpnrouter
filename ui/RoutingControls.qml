pragma ComponentBehavior: Bound
import QtQuick
import "../lib/Focus.js" as Focus
import "../lib/I18n.js" as I18n

Column {
  id: root
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  readonly property string routingMode: service ? service.routingMode : "split"
  readonly property string routingAppsMode: service ? service.routingAppsMode : "include"
  spacing: Brand.space(8)

  function tr(key, args) {
    var _ = root.i18nRevision
    return root.service ? root.service.tr(key, args) : I18n.t(key, args)
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: root.tr("apps.routingMode")
    color: Brand.textPrimary
    font.family: Brand.font.family
    font.pixelSize: Brand.font.title
  }
  Choice {
      width: parent.width
    id: routingChoice
    objectName: "vpnRoutingChoice"
    label: root.tr("apps.routingMode")
    value: root.routingMode
    options: [{value: "split", label: root.tr("apps.routingMode.split")},
              {value: "full", label: root.tr("apps.routingMode.full")}]
    enabled: !!root.service && root.service.activeOperation !== "routing.set"
    onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(routingChoice) })
    onChanged: function(value) {
      if (root.service && value !== root.routingMode) root.service.setRouting(value, root.routingAppsMode)
    }
  }
  Text {
    visible: root.routingMode === "split"
    width: parent.width
    textFormat: Text.PlainText
    text: root.tr("apps.appsMode")
    color: Brand.textPrimary
    font.family: Brand.font.family
    font.pixelSize: Brand.font.bodySmall
  }
  Choice {
      width: parent.width
    id: appRuleChoice
    objectName: "vpnAppRuleChoice"
    label: root.tr("apps.appsMode")
    visible: root.routingMode === "split"
    value: root.routingAppsMode
    options: [{value: "include", label: root.tr("apps.appsMode.include")},
              {value: "exclude", label: root.tr("apps.appsMode.exclude")}]
    enabled: !!root.service && root.service.activeOperation !== "routing.set"
    onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(appRuleChoice) })
    onChanged: function(value) {
      if (root.service && value !== root.routingAppsMode) root.service.setRouting("split", value)
    }
  }
}
