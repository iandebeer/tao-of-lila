import {createHash} from 'node:crypto';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import {resolve, relative, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

// Stamp the whole module graph, not just app.js: imported modules have their
// own browser cache entries. Normalising old stamps makes builds repeatable.
const assetURL = /(['"])((?:\.{1,2}\/|\/yarrow\/)[^'"\s?]+\.(?:js|css|json))(?:\?v=[a-zA-Z0-9_-]+)?\1/g;
const rewrite = (source, version) => source.replace(assetURL,
  (_, quote, path) => `${quote}${path}${version ? `?v=${version}` : ''}${quote}`);

export async function versionAssets(root) {
  const files = [];
  async function walk(directory) {
    for (const entry of await readdir(directory, {withFileTypes: true})) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) await walk(path);
      else if (/\.(html|js|css|json)$/.test(entry.name)) files.push(path);
    }
  }
  await walk(root);
  files.sort();
  const sources = await Promise.all(files.map(async path => [path, rewrite(await readFile(path, 'utf8'), '')]));
  const hash = createHash('sha256');
  for (const [path, source] of sources) hash.update(relative(root, path)).update('\0').update(source).update('\0');
  const version = hash.digest('hex').slice(0, 16);
  for (const [path, source] of sources) {
    if (/\.(html|js)$/.test(path)) await writeFile(path, rewrite(source, version));
  }
  return version;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = resolve(dirname(fileURLToPath(import.meta.url)), '../app/public');
  console.log(`Web asset version: ${await versionAssets(root)}`);
}
