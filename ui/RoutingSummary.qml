pragma ComponentBehavior: Bound
import QtQuick
import "../lib/Model.js" as Model
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
  function summaryText() {
    var _ = i18nRevision
    if (root.value === "full") return root.tr("home.allTraffic")
    if (!root.service || !root.service.appsLoaded) return root.tr("home.appsLoading")
    if (!root.names.length) return root.tr(root.exclude ? "home.appsEmptyExclude" : "home.appsEmpty")
    var apps = Model.runningApplications(root.service.apps)
    var labels = root.names.slice(0, 2).map(function(name) {
      var app = apps.find(function(item) { return item.name === name })
      return app && app.displayName.trim() ? app.displayName : name
    })
    var key = root.exclude ? "home.appsExclude." : "home.appsInclude."
    if (root.names.length <= 2) return root.tr(key + (root.names.length === 1 ? "single" : "pair"), labels)
    var remaining = root.names.length - 2
    var locale = root.service.effectiveLocale || I18n.getEffectiveLocale()
    return root.tr(key + "more." + I18n.cardinalCategory(remaining, locale), [labels[0], labels[1], remaining])
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
    text: root.summaryText()
    // The full selected list remains available in Applications.
    maximumLineCount: 2
    elide: Text.ElideRight
    wrapMode: Text.WordWrap
    color: Brand.textMuted
    font.family: Brand.fontFamily; font.pixelSize: Brand.space(11)
    lineHeight: 1.4
  }
}
