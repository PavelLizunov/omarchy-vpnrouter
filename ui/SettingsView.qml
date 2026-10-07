import QtQuick
import qs.Commons 1.0
import "../lib/Model.js" as Model
import "../lib/I18n.js" as I18n

Item {
  id: root

  property var service: null
  property int i18nRevision: service ? service.i18nRevision : 0
  property string saveNotice: ""

  function tr(key, args) {
    var _ = i18nRevision
    return I18n.t(key, args)
  }

  // Local draft values
  property int mtuVal: (service && service.settingsData) ? service.settingsData.mtu : 1420
  property bool ipv6Val: (service && service.settingsData) ? service.settingsData.ipv6Enabled : false
  property bool strictRouteVal: (service && service.settingsData) ? service.settingsData.strictRoute : false
  property bool strictDnsVal: (service && service.settingsData) ? service.settingsData.strictDns : false
  property var dnsModeVal: savedDnsMode()

  function savedDnsMode() {
    var data = service ? service.settingsData : null
    if (!data) return "vpn_only"
    if (data.dnsModeOverride !== undefined) return data.dnsModeOverride
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
    var cidrArray = Model.cleanCidrList(rawCidr)
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
    if (!root.isCustomMode) {
      payload.dnsMode = root.dnsModeVal !== undefined ? root.dnsModeVal : null
    }
    return payload
  }

  implicitWidth: parent ? parent.width : Style.space(480)
  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Style.space(12)

    // Save Notice
    Rectangle {
      visible: root.saveNotice !== ""
      width: parent.width
      height: noticeRow.implicitHeight + Style.space(12)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.color: Color.accent
      border.width: 1

      Row {
        id: noticeRow
        anchors.fill: parent
        anchors.margins: Style.space(6)
        spacing: Style.space(8)

        Text {
          text: "󰄬"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          width: parent.width - Style.space(40)
          text: root.saveNotice
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }

        IconButton {
          icon: "󰅖"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.saveNotice = ""
        }
      }
    }

    // Network & Engine Settings Card
    Rectangle {
      width: parent.width
      height: settingsGrid.implicitHeight + Style.space(24)
      radius: Style.cornerRadius
      color: Style.normalFill
      border.color: Style.normalBorderColor
      border.width: Style.normalBorderWidth

      Column {
        id: settingsGrid
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(10)

        Text {
          text: root.tr("settings.title")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
        }

        // MTU field
        Row {
          spacing: Style.space(12)

          Text {
            width: Style.space(160)
            text: root.tr("settings.mtu")
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.verticalCenter: parent.verticalCenter
          }

          TextField {
            id: mtuInput
            width: Style.space(100)
            text: String(root.mtuVal)
            placeholderText: "1420"
            onTextChanged: root.mtuVal = Model.validateMtu(text)
          }
        }

        // Toggles
        Toggle {
          label: root.tr("settings.ipv6")
          checked: root.ipv6Val
          onToggled: function(val) { root.ipv6Val = val }
        }

        Toggle {
          label: root.tr("settings.strictRoute")
          checked: root.strictRouteVal
          onToggled: function(val) { root.strictRouteVal = val }
        }

        Toggle {
          label: root.tr("settings.strictDns")
          checked: root.strictDnsVal
          onToggled: function(val) { root.strictDnsVal = val }
        }

        Toggle {
          label: root.tr("settings.bypassRu")
          checked: root.bypassRuVal
          onToggled: function(val) { root.bypassRuVal = val }
        }

        Toggle {
          label: root.tr("settings.blockAds")
          checked: root.blockAdsVal
          onToggled: function(val) { root.blockAdsVal = val }
        }

        Toggle {
          label: root.tr("settings.dnsLeak")
          description: !root.hasDnsLockdownCap ? root.tr("settings.dnsLeakUnsupported") : ""
          enabled: root.hasDnsLockdownCap
          checked: root.dnsLeakVal
          onToggled: function(val) {
            if (root.hasDnsLockdownCap) {
              root.dnsLeakVal = val
            }
          }
        }

        // DNS Mode
        Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            spacing: Style.space(12)

            Text {
              width: Style.space(160)
              text: root.tr("settings.dnsMode")
              color: root.isCustomMode ? Color.muted : Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }

            Row {
              spacing: Style.space(6)
              opacity: root.isCustomMode ? 0.5 : 1.0

              Repeater {
                model: ["vpn_only", "smart", "direct"]

                Rectangle {
                  width: dnsText.implicitWidth + Style.space(16)
                  height: Style.spacing.controlHeight
                  radius: Style.cornerRadius
                  color: (!root.isCustomMode && root.dnsModeVal === modelData) ? Style.selectedFill : (dnsMouse.containsMouse && !root.isCustomMode ? Style.hoverFill : Style.normalFill)
                  border.color: (!root.isCustomMode && root.dnsModeVal === modelData) ? Color.accent : Style.normalBorderColor
                  border.width: 1

                  Text {
                    id: dnsText
                    anchors.centerIn: parent
                    text: {
                      if (modelData === "vpn_only") return root.tr("settings.dnsMode.vpnOnly")
                      if (modelData === "smart") return root.tr("settings.dnsMode.smart")
                      if (modelData === "direct") return root.tr("settings.dnsMode.direct")
                      return modelData.toUpperCase()
                    }
                    color: (!root.isCustomMode && root.dnsModeVal === modelData) ? Color.accent : (root.isCustomMode ? Color.muted : Color.foreground)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: dnsMouse
                    anchors.fill: parent
                    hoverEnabled: !root.isCustomMode
                    cursorShape: root.isCustomMode ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                      if (!root.isCustomMode) {
                        root.dnsModeVal = modelData
                      }
                    }
                  }
                }
              }

              Button {
                visible: !root.isCustomMode && root.dnsModeVal !== null
                variant: "subtle"
                text: root.tr("settings.dnsMode.resetDefault")
                onClicked: root.dnsModeVal = null
              }
            }
          }

          // Read-only custom DNS note or forced StrictDns / Full tunnel explanation
          Rectangle {
            visible: root.isCustomMode || root.strictDnsVal || (root.service && root.service.routingMode === "full")
            width: parent.width
            height: explanationRow.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
            border.width: 1

            Row {
              id: explanationRow
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(8)

              Text {
                text: "󰌵"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                width: parent.width - Style.space(28)
                text: root.dnsExplanationText
                color: Color.foreground
                wrapMode: Text.Wrap
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // Descriptive caption for the selected mode when not forced
          Text {
            visible: !root.isCustomMode && !root.strictDnsVal && !(root.service && root.service.routingMode === "full") && root.dnsExplanationText.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            text: root.dnsExplanationText
          }
        }

        // Excluded CIDR subnets
        Column {
          width: parent.width
          spacing: Style.space(4)

          Text {
            text: root.tr("settings.excludeCidr")
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Rectangle {
            width: parent.width
            height: Style.space(70)
            radius: Style.cornerRadius
            color: Style.normalFill
            border.color: cidrEdit.activeFocus ? Style.focusBorderColor : Style.normalBorderColor
            border.width: cidrEdit.activeFocus ? Style.focusBorderWidth : 1

            TextEdit {
              id: cidrEdit
              anchors.fill: parent
              anchors.margins: Style.space(6)
              wrapMode: TextEdit.Wrap
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Color.foreground
              selectionColor: Color.accent
              selectedTextColor: Color.background
              text: root.cidrsVal

              Text {
                visible: cidrEdit.text.length === 0
                text: root.tr("settings.excludeCidrPlaceholder")
                color: Color.muted
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // Save Button
        Button {
          text: root.tr("settings.save")
          variant: "primary"
          onClicked: {
            if (root.service) {
              var payload = root.buildSettingsPayload()
              root.service.setSettings(payload, function() {
                root.saveNotice = root.tr("settings.saved")
              })
            }
          }
        }
      }
    }
  }
}
