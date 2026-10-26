import QtQuick
import QtQuick.Shapes

// VPNRouter bar mark: a pixel-art side-view penguin, drawn without
// antialiasing like the neighbouring bar glyphs.
//   off    penguin alone on a 13-cell grid
//   split  16-cell rounded tile, cells below the bottom-left to top-right
//          diagonal filled (split tunnel)
//   full   whole tile filled (all traffic through the tunnel)
// Tile cells under the penguin are inverted, so the silhouette stays whole.
Item {
  id: root
  property real iconSize: 16
  property color color: "white"
  property string fill: "off" // off | split | full
  property bool dimmed: false
  property bool badge: false
  property bool pulsing: false

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: implicitWidth
  height: implicitHeight

  readonly property var art: [
    "....####....",
    "...######...",
    "...####.#...",
    "..#########.",
    "..#######...",
    ".########...",
    ".###....#...",
    "####....#...",
    "####....#...",
    ".###....#...",
    ".###...#....",
    "..######....",
    "..###.###..."
  ]
  readonly property int grid: fill === "off" ? 13 : 16
  readonly property string cellPath: buildPath(fill, badge)

  function inTile(x, y) {
    var cx = x < 2 ? 2 - x : x > 13 ? x - 13 : 0
    var cy = y < 2 ? 2 - y : y > 13 ? y - 13 : 0
    return cx + cy < 3
  }

  function buildPath(fillMode, withBadge) {
    var n = fillMode === "off" ? 13 : 16
    var w = art[0].length, h = art.length
    var ox = Math.floor((n - w) / 2)
    var oy = fillMode === "off" ? 0 : Math.floor((n - h) / 2) + 1
    var on = []
    for (var y = 0; y < n; y++) {
      on.push([])
      for (var x = 0; x < n; x++) {
        var ax = x - ox, ay = y - oy
        var cell = ay >= 0 && ay < h && ax >= 0 && ax < w && art[ay][ax] === "#"
        if (fillMode !== "off" && inTile(x, y) && (fillMode === "full" || x + y >= 16)) cell = !cell
        on[y].push(cell)
      }
    }
    if (withBadge) {
      // A 3x3 dot in the top-right corner with a one-cell gap around it.
      for (var by = 0; by < 4; by++)
        for (var bx = n - 4; bx < n; bx++) on[by][bx] = by < 3 && bx >= n - 3
    }
    // One rectangle per horizontal run keeps the path small.
    var d = ""
    for (var ry = 0; ry < n; ry++) {
      var start = -1
      for (var rx = 0; rx <= n; rx++) {
        var lit = rx < n && on[ry][rx]
        if (lit && start < 0) start = rx
        if (!lit && start >= 0) {
          d += "M" + start + " " + ry + "H" + rx + "V" + (ry + 1) + "H" + start + "Z"
          start = -1
        }
      }
    }
    return d
  }

  // pulse carries the connecting animation so it never breaks the dimmed binding.
  Item {
    id: pulse
    anchors.fill: parent

    Shape {
      anchors.fill: parent
      opacity: root.dimmed ? 0.6 : 1
      antialiasing: false
      preferredRendererType: Shape.GeometryRenderer
      transform: Scale { xScale: root.width / root.grid; yScale: root.height / root.grid }

      ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0
        fillRule: ShapePath.WindingFill
        PathSvg { path: root.cellPath }
      }
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
