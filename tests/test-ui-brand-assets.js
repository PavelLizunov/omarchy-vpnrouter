// Owner invariant: the original mascot bytes must never change.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const hashes = {
  '../assets/penguin_mascot.png': '577c8c992d70ea74dacbb9a82b5d5bb41a87371353d58c3340ceb79d72a1a853',
  '../assets/penguin_mascot_white.png': '1cf062bafa6053faddf18fd3178c3dd2e8b3826907c7e7983e9c1f33e181de1f',
  'fixtures/penguin_mascot_tile.png': 'b621e44c553cf8e327ef571ce42ed135fbe64fd321049d8311acc0e5cca63655'
};
for (const [name, expected] of Object.entries(hashes)) {
  const bytes = fs.readFileSync(path.join(__dirname, name));
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), expected, name);
}
console.log('PASS: all three original mascot assets retain their exact SHA-256');

assert.deepEqual(fs.readdirSync(path.join(__dirname, '../assets')).filter(name => name.endsWith('.png')).sort(),
  ['penguin_mascot.png', 'penguin_mascot_white.png'], 'Only the two runtime mascots belong to assets/');
