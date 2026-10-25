.pragma library

function reveal(item, force) {
  if (!item || (!force && !item.activeFocus)) return;
  var viewport = item.parent;
  while (viewport && viewport.objectName !== "vpnContentViewport" && viewport.objectName !== "vpnHeroViewport") viewport = viewport.parent;
  if (!viewport) return;
  var point = item.mapToItem(viewport.contentItem, 0, 0);
  if (point.y < viewport.contentY) viewport.contentY = Math.max(0, point.y);
  else if (point.y + item.height > viewport.contentY + viewport.height)
    viewport.contentY = Math.min(Math.max(0, viewport.contentHeight - viewport.height), point.y + item.height - viewport.height);
}
