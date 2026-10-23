import QtQuick
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root
  objectName: "vpnSettingsView"

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string saveNotice: ""
  property bool noticeError: false
  property bool pending: false

  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }

  // Local draft values
  property int mtuVal: (service && service.settingsData) ? service.settingsData.mtu : 1420
  property bool ipv6Val: (service && service.settingsData) ? service.settingsData.ipv6Enabled : false
  property bool strictRouteVal: (service && service.settingsData) ? service.settingsData.strictRoute : false
  property bool strictDnsVal: (service && service.settingsData) ? service.settingsData.strictDns : false
  property var dnsModeVal: savedDnsMode()
  readonly property string dnsModeText: root.tr(root.dnsModeVal === null ? "settings.dnsMode.resetDefault"
    : ({vpn_only: "settings.dnsMode.vpnOnly", smart: "settings.dnsMode.smart", direct: "settings.dnsMode.direct", custom: "settings.dnsMode.custom"})[root.dnsModeVal] || "protocol.unknown")

  function savedDnsMode() {
    var data = service ? service.settingsData : null
    if (!data) return "vpn_only"
    if (data.dnsModeOverride !== undefined && data.dnsModeOverride !== null) return data.dnsModeOverride
    return data.dnsMode !== undefined ? data.dnsMode : "vpn_only"
  }
  property bool bypassRuVal: (service && service.settingsData) ? service.settingsData.bypassRussianTraffic : true
  property bool blockAdsVal: (service && service.settingsData) ? service.settingsData.blockAds : false
  property bool dnsLeakVal: (service && service.settingsData) ? service.settingsData.dnsLeakLockdown : false
  property string cidrsVal: (service && service.settingsData && service.settingsData.routeExcludeAddress)
    ? Model.formatCidrList(service.settingsData.routeExcludeAddress) : ""

  readonly property bool isCustomMode: {
    if (service && service.configMode === "custom") return true
    if (service && service.settingsData && service.settingsData.dnsMode === "custom") return true
    if (dnsModeVal === "custom") return true
    return false
  }

  readonly property bool hasDnsLockdownCap: !!(service && service.capabilities && service.capabilities.dnsLockdown === true)

  readonly property string dnsExplanationText: {
    // Explain the editable draft, not saved backend prose or live DNS state.
    var isFull = !!(service && service.routingMode === "full")
    if (root.isCustomMode) {
      if (root.strictDnsVal) return root.tr("settings.dnsMode.forcedCustomStrictDns")
      if (isFull) return root.tr("settings.dnsMode.forcedCustomFull")
      return root.tr("settings.dnsMode.customConfig")
    }
    if (root.strictDnsVal) return root.tr("settings.dnsMode.forcedStrictDns")
    if (isFull) return root.tr("settings.dnsMode.forcedFull")
    if (root.dnsModeVal === "vpn_only") return root.tr("settings.dnsMode.vpnOnlyDesc")
    if (root.dnsModeVal === "smart") return root.tr("settings.dnsMode.smartDesc")
    if (root.dnsModeVal === "direct") return root.tr("settings.dnsMode.directDesc")
    if (root.dnsModeVal === null) return root.tr("settings.dnsMode.profileDefaultDesc")
    return ""
  }

  function buildSettingsPayload() {
    var rawCidr = (typeof cidrEdit !== "undefined" && cidrEdit) ? cidrEdit.text : root.cidrsVal
    var cidrArray = rawCidr.split(/[\n,]+/).map(function(s) { return s.trim() }).filter(function(s) { return s.length > 0 })
    var payload = {
      mtu: Model.validateMtu(root.mtuVal),
      ipv6Enabled: root.ipv6Val,
      strictRoute: root.strictRouteVal,
      strictDns: root.strictDnsVal,
      bypassRussianTraffic: root.bypassRuVal,
      blockAds: root.blockAdsVal,
      routeExcludeAddress: cidrArray
    }
    // Omit unavailable protection rather than resubmitting an unsupported true
    // value or silently disabling an existing safety preference.
    if (root.hasDnsLockdownCap) payload.dnsLeakLockdown = root.dnsLeakVal
    // dnsMode is profile data on current Core. Sending it makes settings.set fail.
    return payload
  }

  function resetDraft() {
    var data = root.service ? root.service.settingsData : null
    if (!data) return
    root.mtuVal = data.mtu
    mtuInput.text = String(data.mtu)
    root.ipv6Val = data.ipv6Enabled
    root.strictRouteVal = data.strictRoute
    root.strictDnsVal = data.strictDns
    root.bypassRuVal = data.bypassRussianTraffic
    root.blockAdsVal = data.blockAds
    root.dnsLeakVal = data.dnsLeakLockdown
    root.dnsModeVal = root.savedDnsMode()
    root.cidrsVal = Model.formatCidrList(data.routeExcludeAddress)
    cidrEdit.text = root.cidrsVal
  }

  Connections {
    target: root.service
    function onSettingsDataChanged() { root.resetDraft() }
  }

  function submit() {
    if (!root.service || root.pending) return
    feedback.reveal()
    var mtu = Number(mtuInput.text)
    if (!/^\d+$/.test(mtuInput.text) || mtu < 576 || mtu > 9000) {
      root.noticeError = true; root.saveNotice = "settings.invalidMtu"; return
    }
    root.mtuVal = mtu
    root.pending = true; root.noticeError = false; root.saveNotice = "operation.pending"
    root.service.setSettings(root.buildSettingsPayload(), function() {
      root.pending = false; root.saveNotice = "settings.saved"
    }, function(err) {
      root.pending = false; root.noticeError = true
      root.saveNotice = err && err.code === "invalid_argument" ? "settings.invalid" : "form.failed"
    })
  }

  implicitWidth: parent ? parent.width : Commons.Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Commons.Style.space(12)

    Notice {
      id: feedback
      width: parent.width
      text: root.saveNotice ? root.tr(root.saveNotice) : ""
      error: root.noticeError
      dismissLabel: root.tr("action.dismiss")
      onDismissed: root.saveNotice = ""
    }

    // Network & Engine Settings Card
    Ui.BorderSurface {
      width: parent.width
      height: settingsGrid.implicitHeight + Commons.Style.space(24)
      radius: Commons.Style.cornerRadius
      color: Commons.Style.normalFill
      borderSpec: Commons.Border.controlSpec("normal", Commons.Color.popups.text, Commons.Color.accent)

      Column {
        id: settingsGrid
        enabled: !root.pending
        anchors.fill: parent
        anchors.margins: Commons.Style.space(12)
        spacing: Commons.Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: root.tr("settings.title")
          color: Commons.Color.popups.text
          font.family: Commons.Style.font.family
          font.pixelSize: Commons.Style.font.title
        }

        // MTU field
        Row {
          spacing: Commons.Style.space(12)

          Text {
            textFormat: Text.PlainText
            width: Commons.Style.space(160)
            wrapMode: Text.WordWrap
            text: root.tr("settings.mtu")
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            id: mtuInput
            width: Commons.Style.space(100)
            text: String(root.mtuVal)
            placeholderText: "1420"
            onAccepted: root.submit()
          }
        }

        // Toggles
        Toggle {
          width: parent.width
          label: root.tr("settings.ipv6")
          checked: root.ipv6Val
          onToggled: function(val) { root.ipv6Val = val }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.strictRoute")
          checked: root.strictRouteVal
          onToggled: function(val) { root.strictRouteVal = val }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.strictDns")
          checked: root.strictDnsVal
          onToggled: function(val) { root.strictDnsVal = val }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.bypassRu")
          checked: root.bypassRuVal
          onToggled: function(val) { root.bypassRuVal = val }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.blockAds")
          checked: root.blockAdsVal
          onToggled: function(val) { root.blockAdsVal = val }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.dnsLeak")
          description: !root.hasDnsLockdownCap ? root.tr("settings.dnsLeakUnsupported") : ""
          enabled: root.hasDnsLockdownCap
          checked: root.hasDnsLockdownCap && root.dnsLeakVal
          onToggled: function(val) {
            if (root.hasDnsLockdownCap) {
              root.dnsLeakVal = val
            }
          }
        }

        Toggle {
          width: parent.width
          label: root.tr("settings.killSwitch")
          description: root.tr("settings.killSwitchUnsupported")
          enabled: false
          checked: false
        }

        // DNS mode is read from the profile. Current Core rejects writing it here.
        Column {
          width: parent.width
          spacing: Commons.Style.space(6)

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: root.tr("settings.dnsModeValue", [root.dnsModeText])
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // Read-only custom DNS note or forced StrictDns / Full tunnel explanation
          Ui.BorderSurface {
            visible: root.isCustomMode || root.strictDnsVal || (root.service && root.service.routingMode === "full")
            width: parent.width
            height: explanationRow.implicitHeight + Commons.Style.space(12)
            radius: Commons.Style.cornerRadius
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.08)
            borderSpec: Commons.Border.controlSpec("normal", Commons.Color.accent, Commons.Color.accent)

            Row {
              id: explanationRow
              anchors.fill: parent
              anchors.margins: Commons.Style.space(6)
              spacing: Commons.Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: "󰌵"
                color: Commons.Color.accent
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width - Commons.Style.space(28)
                text: root.dnsExplanationText
                color: Commons.Color.popups.text
                wrapMode: Text.Wrap
                font.family: Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // Descriptive caption for the selected mode when not forced
          Text {
            textFormat: Text.PlainText
            visible: !root.isCustomMode && !root.strictDnsVal && !(root.service && root.service.routingMode === "full") && root.dnsExplanationText.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            text: root.dnsExplanationText
          }
        }

        // Excluded CIDR subnets
        Column {
          width: parent.width
          spacing: Commons.Style.space(4)

          Text {
            textFormat: Text.PlainText
            text: root.tr("settings.excludeCidr")
            color: Commons.Color.popups.text
            font.family: Commons.Style.font.family
            font.pixelSize: Commons.Style.font.bodySmall
          }

          Editor {
            id: cidrEdit
            objectName: "vpnSettingsCidrs"
            width: parent.width
            height: Commons.Style.space(90)
            text: root.cidrsVal
            label: root.tr("settings.excludeCidr")
            placeholderText: root.tr("settings.excludeCidrPlaceholder")
            onSubmitted: root.submit()
          }

        }

        Flow {
          width: parent.width
          spacing: Commons.Style.space(8)
          Button {
            text: root.tr("settings.save")
            variant: "primary"
            onClicked: root.submit()
          }
          Button {
            text: root.tr("settings.revert")
            onClicked: { root.resetDraft(); root.saveNotice = "settings.reverted"; root.noticeError = false }
          }
        }
      }
    }
  }
}
