import QtQuick
import qs.Commons as Commons

Button {
  property string tooltipText: ""
  variant: "subtle"
  accessibleLabel: tooltipText
  implicitWidth: implicitHeight
}
