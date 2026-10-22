pragma ComponentBehavior: Bound
import QtQuick
import "../lib/Focus.js" as Focus
import "../lib/I18n.js" as I18n

Column {
  id: root
  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  readonly property string value: service ? service.routingMode : "split"
  readonly property bool exclude: !!service && service.routingAppsMode === "exclude"
  readonly property var names: service && service.apps ? (exclude ? service.apps.exclude : service.apps.include) || [] : []
  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }
  spacing: Brand.space(10)
  Text {
    textFormat: Text.PlainText
    text: root.tr("home.route")
    color: Brand.textSecondary
    font.family: Brand.fontFamily; font.pixelSize: Brand.space(11)
  }
  Choice {
    id: segments
    objectName: "vpnHomeRoutingChoice"
    width: parent.width
    pill: true
    label: root.tr("home.route")
    value: root.value
    options: [{value:"split",label:root.tr("home.apps"),icon:"󰀻"},
              {value:"full",label:root.tr("home.full"),icon:"󰖟"}]
    enabled: !!root.service && root.service.activeOperation !== "routing.set"
    onChanged: function(value) { if(root.service) root.service.setRouting(value, root.service.routingAppsMode) }
  }

  Text {
    objectName: "vpnRoutingSummary"
    width: parent.width
    textFormat: Text.PlainText
    text: root.value === "full" ? root.tr("home.allTraffic") : !root.service || !root.service.appsLoaded ? root.tr("home.appsLoading") : !root.names.length ? root.tr("home.appsEmpty") : root.tr(root.exclude ? "home.appsExclude" : "home.appsInclude", [root.names.join(", ")])
    // The full selected list remains available in Applications.
    maximumLineCount: 2
    elide: Text.ElideRight
    wrapMode: Text.WordWrap
    color: Brand.textMuted
    font.family: Brand.fontFamily; font.pixelSize: Brand.space(11)
    lineHeight: 1.4
  }
}
