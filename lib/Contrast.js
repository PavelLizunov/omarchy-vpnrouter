.pragma library

// WCAG relative luminance, after compositing translucent host surface fills.
function linear(value) {
  return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
}
function over(color, background) {
  var alpha = color.a === undefined ? 1 : color.a;
  return { r: color.r * alpha + background.r * (1 - alpha),
    g: color.g * alpha + background.g * (1 - alpha),
    b: color.b * alpha + background.b * (1 - alpha) };
}
function luminance(color) {
  return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
}
function ratio(foreground, background, underlay) {
  var surface = underlay ? over(background, underlay) : background;
  var first = luminance(over(foreground, surface)), second = luminance(surface);
  return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}
if (typeof module !== "undefined") module.exports = { ratio: ratio };
