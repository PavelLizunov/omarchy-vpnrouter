pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Ui as Ui
import qs.Commons as Commons
import "../lib/Focus.js" as Focus
import "../lib/I18n.js" as I18n

Ui.BorderSurface {
  id: root
  property string text: ""
  property bool error: false
  property string dismissLabel: ""
  // The shared panel notice also inherits the service without changing its host.
  property var service: {
    var owner = parent
    while (owner && owner.service === undefined) owner = owner.parent
    return owner ? owner.service : null
  }
  property int i18nRevision: service ? service.i18nRevision : 0
  property bool detailsOnly: false
  property bool expanded: false
  readonly property bool hasDetails: detailsOnly || (error && (text.length > 180 || text.indexOf("\n") !== -1))
  signal dismissed()
  visible: text.length > 0
  function tr(key, args) {
    var _ = i18nRevision
    return root.service && typeof root.service.tr === "function" ? root.service.tr(key, args) : I18n.t(key, args)
  }
  function reveal() {
    Qt.callLater(function() {
      if (!root.text || !root.visible || root.detailsOnly) return
      if (root.error) message.forceActiveFocus()
      Focus.reveal(root, true)
    })
  }
  onTextChanged: { expanded = false; root.reveal() }
  implicitHeight: content.implicitHeight + Commons.Style.space(12)
  color: Commons.Style.normalFill
  radius: Commons.Style.cornerRadius
  borderSpec: Commons.Border.controlSpec(message.activeFocus ? "focus" : "normal", error ? Commons.Color.urgent : Commons.Color.popups.text, Commons.Color.accent)
  Column {
    id: content
    x: Commons.Style.space(8); y: Commons.Style.space(6)
    width: parent.width - Commons.Style.space(16)
    spacing: Commons.Style.space(6)
    Item {
      visible: !root.detailsOnly
      width: parent.width
      height: Math.max(message.implicitHeight, dismiss.implicitHeight)
      TextEdit {
        id: message
        objectName: "vpnNoticeText"
        onActiveFocusChanged: if (activeFocus) Qt.callLater(function() { Focus.reveal(message) })
        width: parent.width - dismiss.width - Commons.Style.space(8)
        height: implicitHeight
        text: root.hasDetails ? root.tr("error.generic") : root.text
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        activeFocusOnTab: true
        wrapMode: TextEdit.Wrap
        color: Commons.Color.popups.text
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.popups.background
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.bodySmall
      }
      FocusCue { focused: message.activeFocus }
      IconButton {
        id: dismiss
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰅖"
        tooltipText: root.dismissLabel
        onClicked: root.dismissed()
      }
    }
    Button {
      id: disclosure
      objectName: "vpnNoticeDisclosure"
      visible: root.hasDetails
      width: parent.width
      icon: root.expanded ? "󰅀" : "󰅂"
      text: root.tr(root.expanded ? "action.hideDetails" : "action.showDetails")
      onClicked: root.expanded = !root.expanded
    }
    Flickable {
      id: detailsViewport
      visible: root.hasDetails && root.expanded
      width: parent.width
      height: Math.min(details.implicitHeight, Commons.Style.space(160))
      clip: true
      contentWidth: width
      contentHeight: details.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
      TextEdit {
        id: details
        objectName: "vpnNoticeDetails"
        width: detailsViewport.width - Commons.Style.space(12)
        height: implicitHeight
        text: root.text
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        selectByKeyboard: true
        activeFocusOnTab: true
        wrapMode: TextEdit.Wrap
        color: Commons.Color.popups.text
        selectionColor: Commons.Color.accent
        selectedTextColor: Commons.Color.popups.background
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.bodySmall
        onCursorRectangleChanged: {
          if (!activeFocus) return
          if (cursorRectangle.y < detailsViewport.contentY) detailsViewport.contentY = cursorRectangle.y
          else if (cursorRectangle.y + cursorRectangle.height > detailsViewport.contentY + detailsViewport.height)
            detailsViewport.contentY = cursorRectangle.y + cursorRectangle.height - detailsViewport.height
        }
      }
      FocusCue { focused: details.activeFocus }
    }
  }
}
