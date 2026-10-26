import QtQuick
import QtQuick.Shapes

// VPNRouter bar mark: a side-view penguin on a rounded tile, drawn on a
// 16-unit grid. Even-odd filling inverts the penguin wherever the tile is
// filled, so the silhouette stays whole in every state.
//   off    penguin alone
//   split  lower-right half of the tile filled (split tunnel)
//   full   whole tile filled (all traffic through the tunnel)
Item {
  id: root
  property real iconSize: 16
  property color color: "white"
  // Bar background; cuts the gap around the badge.
  property color surface: "black"
  property string fill: "off" // off | split | full
  property bool dimmed: false
  property bool badge: false
  property bool pulsing: false
  // Draws the tile contour while the tile is not fully filled.
  property bool outlined: false

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: implicitWidth
  height: implicitHeight

  readonly property string tilePath: "M3.5 0.5H12.5A3 3 0 0 1 15.5 3.5V12.5A3 3 0 0 1 12.5 15.5H3.5A3 3 0 0 1 0.5 12.5V3.5A3 3 0 0 1 3.5 0.5Z"
  // The tile below its bottom-left to top-right diagonal.
  readonly property string splitPath: "M1.379 14.621A3 3 0 0 0 3.5 15.5H12.5A3 3 0 0 0 15.5 12.5V3.5A3 3 0 0 0 14.621 1.379Z"
  // One body contour, then belly and eye holes.
  readonly property string penguinPath: "M 8.452 2.614 C 9.778 2.614 10.714 3.472 10.87 4.642 L 13.6 5.422 L 10.792 6.202 C 11.182 7.216 11.416 8.308 11.338 9.556 C 11.26 11.428 10.402 12.754 9.232 13.3 L 10.168 13.456 Q 10.792 13.768 10.324 14.08 H 6.736 Q 6.268 13.768 6.892 13.456 L 7.516 13.3 C 5.488 12.676 4.396 11.272 4.396 9.244 C 4.396 7.528 5.254 6.436 6.19 5.812 C 6.112 5.5 6.034 5.266 6.034 5.032 C 6.034 3.706 7.126 2.614 8.452 2.614 Z M 10.09 6.748 C 10.636 7.684 10.792 8.62 10.714 9.634 C 10.636 11.428 9.856 12.52 8.764 12.832 C 7.594 12.442 6.97 11.194 6.97 9.712 C 6.97 8.074 7.984 6.982 9.154 6.67 Z M 8.647 4.408 A 0.663 0.663 0 1 0 9.973 4.408 A 0.663 0.663 0 1 0 8.647 4.408 Z"

  // pulse carries the connecting animation so it never breaks the dimmed binding.
  Item {
    id: pulse
    anchors.fill: parent

    Item {
      id: art
      anchors.fill: parent
      opacity: root.dimmed ? 0.45 : 1

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.width / 16; yScale: root.height / 16 }

        ShapePath {
          fillColor: root.color
          strokeColor: "transparent"
          strokeWidth: 0
          fillRule: ShapePath.OddEvenFill
          PathSvg {
            path: (root.fill === "full" ? root.tilePath + " " : root.fill === "split" ? root.splitPath + " " : "") + root.penguinPath
          }
        }

        ShapePath {
          fillColor: "transparent"
          strokeColor: root.outlined && root.fill !== "full" ? root.color : "transparent"
          strokeWidth: 1
          PathSvg { path: root.tilePath }
        }
      }
    }
  }

  Rectangle {
    objectName: "penguinBadge"
    visible: root.badge
    x: root.width * 11 / 16
    y: root.height * -0.2 / 16
    width: root.width * 5.2 / 16
    height: width
    radius: width / 2
    color: root.surface
    Rectangle {
      anchors.centerIn: parent
      width: parent.width * 0.7
      height: width
      radius: width / 2
      color: root.color
    }
  }

  SequentialAnimation {
    running: root.pulsing
    loops: Animation.Infinite
    onRunningChanged: if (!running) pulse.opacity = 1
    NumberAnimation { target: pulse; property: "opacity"; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
    NumberAnimation { target: pulse; property: "opacity"; to: 1; duration: 700; easing.type: Easing.InOutSine }
  }
}
