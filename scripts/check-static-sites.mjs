import assert from 'node:assert/strict';
import {readFile, access} from 'node:fs/promises';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
for(const site of ['reading-site','landing-site']) {
  const out=resolve(root,'web',site,'dist');
  const paths=site==='reading-site'?['index.html','guide/index.html','introduction/index.html','404.html']:['index.html'];
  for(const path of paths) {
    const html=await readFile(resolve(out,path),'utf8');
    assert.match(html,/<html lang="en">/);
    assert.doesNotMatch(html,/\bLila\b/);
    for(const [,url] of html.matchAll(/(?:href|src)="(\/[^"#?]*)(?:[?#][^"]*)?"/g)) {
      assert(!url.startsWith('//'),`Unexpected protocol-relative URL: ${url}`);
      await access(resolve(out,'.'+url+(url.endsWith('/')?'index.html':'')));
    }
  }
  await access(resolve(out,'robots.txt'));
  await access(resolve(out,'sitemap.xml'));
}
const landing=await readFile(resolve(root,'web/landing-site/dist/index.html'),'utf8');
assert.match(landing,/href="https:\/\/play\.leela\.day\/journey\/"/);
assert.match(landing,/href="https:\/\/read\.leela\.day\/"/);
const artwork='assets/splash/a_richly_detailed_ornate_fantasy_chinese_taoist_i.png';
assert.deepEqual(await readFile(resolve(root,'web/landing-site/dist',artwork)),await readFile(resolve(root,'app/public',artwork)));
console.log('Static pages, local links, Leela spelling, destination links and shared splash artwork verified.');
