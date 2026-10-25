// Production visuals must inherit the installed Omarchy theme.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
function violations(source) {
  return [
    ...source.matchAll(/#[0-9a-f]{3,8}\b/gi),
    ...source.matchAll(/(?:font\.family|fontFamily|iconFamily|\bfamily)\s*[:=]\s*["'][^"']+["']/g)
  ].map(match => match[0]);
}
assert(violations('color: "#abcdef"; font.family: "Desktop Font"').length === 2);
assert(violations('font.family: Commons.Style.font.family; color: Commons.Color.accent').length === 0);
let count = 0;
function scan(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
    if (entry.name.startsWith('.') || ['tests', 'fixtures'].includes(entry.name)) continue;
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) scan(file);
    else if (/\.(qml|js)$/.test(entry.name)) {
      assert.deepEqual(violations(fs.readFileSync(file, 'utf8')), [], path.relative(root, file));
      count++;
    }
  }
}
scan(root);
// The directory module must also work in the live host, which uses qmldir.
const moduleText = fs.readFileSync(path.join(root, 'ui/qmldir'), 'utf8');
for (const file of fs.readdirSync(path.join(root, 'ui')).filter(file => file.endsWith('.qml'))) {
  assert(moduleText.includes(`${path.basename(file, '.qml')} 1.0 ${file}`), `qmldir: ${file}`);
}
console.log(`PASS: ${count} production QML/JS files contain no hex colours or fixed font families; every UI type is exported`);

const contrastModule = {exports: {}};
new Function('module', fs.readFileSync(path.join(root, 'lib/Contrast.js'), 'utf8')
  .replace(/^\.pragma library\s*/m, ''))(contrastModule);
const ratio = contrastModule.exports.ratio;
const black = {r:0,g:0,b:0}, white = {r:1,g:1,b:1};
assert.equal(ratio(black, white), 21);
assert.equal(ratio(white, black), 21);
assert.equal(ratio(white, white), 1);
assert.equal(ratio(black, {...white,a:0}, black), 1, 'Transparent host fills use their underlay');
assert(ratio({...white,a:0.5}, black) > 5 && ratio({...white,a:0.5}, black) < 6);
console.log('PASS: actual contrast helper handles luminance, symmetry and translucent host fills');
