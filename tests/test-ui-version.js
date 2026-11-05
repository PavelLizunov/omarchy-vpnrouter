// A published plugin version must identify one installable runtime payload.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const repo = path.join(__dirname, '..');
const git = (...args) => execFileSync('git', args, {cwd: repo, encoding: 'utf8'}).trim();
// The existing CI checkout is shallow; fetch only release tags, without rewriting them.
if (process.env.GITHUB_ACTIONS === 'true') {
  git('fetch', '--quiet', '--depth=1', 'origin', 'refs/tags/v*:refs/tags/v*');
}
const version = JSON.parse(fs.readFileSync(path.join(repo, 'manifest.json'), 'utf8')).version;
assert.match(version, /^\d+\.\d+\.\d+$/, 'Use a three-part plugin release version');
const compare = (a, b) => {
  const left = a.replace(/^v/, '').split('.').map(Number);
  const right = b.replace(/^v/, '').split('.').map(Number);
  for (let i = 0; i < 3; i++) if (left[i] !== right[i]) return left[i] - right[i];
  return 0;
};
const released = git('tag', '--list', 'v*').split('\n').filter(tag => /^v\d+\.\d+\.\d+$/.test(tag));
assert(released.length, 'Release tags are required; fetch origin release tags before running locally');
const latest = released.sort(compare).at(-1);
assert(compare(version, latest) >= 0, `Plugin ${version} is older than released ${latest}`);
const tag = 'v' + version;
if (released.includes(tag)) {
  const changed = git('diff', '--name-only', tag, '--', 'manifest.json', 'BarWidget.qml',
    'Panel.qml', 'Service.qml', 'setup', 'bin', 'lib', 'locales', 'ui', 'assets', 'backend',
    ':(exclude,glob)**/*.md');
  assert.equal(changed, '', `Runtime differs from published ${tag}; advance manifest.json version:\n${changed}`);
}
if (process.env.GITHUB_REF_TYPE === 'tag') {
  assert.equal(process.env.GITHUB_REF_NAME, tag, 'Release tag must match manifest.json version');
}
console.log(`PASS: plugin ${version} has a distinct runtime identity; latest release is ${latest}`);
