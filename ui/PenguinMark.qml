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
  // Without the tile the penguin fills the whole canvas like neighbouring glyphs.
  readonly property string freePenguinPath: "M 7.3 0.65 C 9 0.65 10.2 1.75 10.4 3.25 L 13.9 4.25 L 10.3 5.25 C 10.8 6.55 11.1 7.95 11 9.55 C 10.9 11.95 9.8 13.65 8.3 14.35 L 9.5 14.55 Q 10.3 14.95 9.7 15.35 H 5.1 Q 4.5 14.95 5.3 14.55 L 6.1 14.35 C 3.5 13.55 2.1 11.75 2.1 9.15 C 2.1 6.95 3.2 5.55 4.4 4.75 C 4.3 4.35 4.2 4.05 4.2 3.75 C 4.2 2.05 5.6 0.65 7.3 0.65 Z M 9.4 5.95 C 10.1 7.15 10.3 8.35 10.2 9.65 C 10.1 11.95 9.1 13.35 7.7 13.75 C 6.2 13.25 5.4 11.65 5.4 9.75 C 5.4 7.65 6.7 6.25 8.2 5.85 Z M 7.55 2.95 A 0.85 0.85 0 1 0 9.25 2.95 A 0.85 0.85 0 1 0 7.55 2.95 Z"
  // On the tile: one body contour, then belly and eye holes.
  readonly property string penguinPath: "M 8.424 2.018 C 9.886 2.018 10.918 2.964 11.09 4.254 L 14.1 5.114 L 11.004 5.974 C 11.434 7.092 11.692 8.296 11.606 9.672 C 11.52 11.736 10.574 13.198 9.284 13.8 L 10.316 13.972 Q 11.004 14.316 10.488 14.66 H 6.532 Q 6.016 14.316 6.704 13.972 L 7.392 13.8 C 5.156 13.112 3.952 11.564 3.952 9.328 C 3.952 7.436 4.898 6.232 5.93 5.544 C 5.844 5.2 5.758 4.942 5.758 4.684 C 5.758 3.222 6.962 2.018 8.424 2.018 Z M 10.23 6.576 C 10.832 7.608 11.004 8.64 10.918 9.758 C 10.832 11.736 9.972 12.94 8.768 13.284 C 7.478 12.854 6.79 11.478 6.79 9.844 C 6.79 8.038 7.908 6.834 9.198 6.49 Z M 8.639 3.996 A 0.731 0.731 0 1 0 10.101 3.996 A 0.731 0.731 0 1 0 8.639 3.996 Z"

  // pulse carries the connecting animation so it never breaks the dimmed binding.
  Item {
    id: pulse
    anchors.fill: parent

    Item {
      id: art
      anchors.fill: parent
      opacity: root.dimmed ? 0.6 : 1

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
            path: root.fill === "full" ? root.tilePath + " " + root.penguinPath : root.fill === "split" ? root.splitPath + " " + root.penguinPath : root.freePenguinPath
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
