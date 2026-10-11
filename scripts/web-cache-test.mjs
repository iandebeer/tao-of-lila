import assert from 'node:assert/strict';
import {mkdtemp, mkdir, readFile, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import vm from 'node:vm';
import {versionAssets} from './version-web-assets.mjs';

const root = await mkdtemp(join(tmpdir(), 'tao-web-cache-'));
try {
  await mkdir(join(root, 'journey'));
  const put = (name, source) => writeFile(join(root, 'journey', name), source);
  const get = name => readFile(join(root, 'journey', name), 'utf8');
  await put('index.html', '<link href="./style.css"><script src="./app.js"></script>');
  await put('app.js', "import {value} from './child.js'; fetch('./catalog.json'); fetch('/journey-session');");
  await put('child.js', 'export const value = 1;');
  await put('style.css', 'body {color: black}');
  await put('catalog.json', '{}');
  const first = await versionAssets(root);
  assert.ok((await get('index.html')).includes(`./app.js?v=${first}`));
  assert.ok((await get('index.html')).includes(`./style.css?v=${first}`));
  assert.ok((await get('app.js')).includes(`./child.js?v=${first}`));
  assert.ok((await get('app.js')).includes(`./catalog.json?v=${first}`));
  assert.ok((await get('app.js')).includes("fetch('/journey-session')"));
  assert.equal(await versionAssets(root), first, 'rebuilding unchanged sources is stable');
  await put('child.js', 'export const value = 2;');
  const second = await versionAssets(root);
  assert.notEqual(second, first, 'a nested module change invalidates the release');
  assert.ok((await get('index.html')).includes(`./app.js?v=${second}`));
  assert.ok(!(await get('app.js')).includes(first), 'old version stamps are replaced');
} finally { await rm(root, {recursive:true, force:true}); }

// Run the actual restoration handler with each kind of work that must survive.
const source = await readFile('app/public/journey/app.js', 'utf8');
const start = source.indexOf("addEventListener('pageshow',");
const handler = source.slice(start, source.indexOf('\n});', start) + 4);
assert.ok(start >= 0);
for (const [persisted, dirty, busy, form, expected] of [
  [false,false,false,false,0], [true,false,false,false,1],
  [true,true,false,false,0], [true,false,true,false,0], [true,false,false,true,0],
]) {
  let reloads = 0;
  vm.runInNewContext(handler, {dirty,busy,
    document:{querySelector:()=>form ? {} : null},
    location:{reload(){reloads++;}},
    addEventListener(type, callback){assert.equal(type,'pageshow');callback({persisted});},
  });
  assert.equal(reloads, expected);
}
console.log('ok - release URLs cover nested modules and data, builds are stable, Safari restoration preserves edits');
