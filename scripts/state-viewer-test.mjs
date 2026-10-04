import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {buildCatalog} from './build-state-catalog.mjs';
import {leelaMarkup,hexagramMarkup,trigramMarkup,pairSelection,imageMarkup,safeAsset,hexControl,installStateViewer} from '../app/public/journey/state-viewer.js';
const catalog=buildCatalog();
const read=path=>JSON.parse(readFileSync(path,'utf8'));
for(const path of ['data/state-views.json','app/public/journey/state-views.json'])assert.deepEqual(read(path),catalog,'regenerate viewer snapshots after changing canonical metadata');
assert.deepEqual(catalog.stateViews.map(s=>s.identity.stateId),Array.from({length:72},(_,i)=>i+1));
for(const seed of read('data/leela.json'))assert.deepEqual(catalog.stateViews[seed.stateId-1].identity,seed,'live seed identities must not be replaced');
for(const [origin,destination,kind] of [[55,3,'snake'],[37,66,'ladder']]){
  const view=catalog.stateViews[origin-1];
  assert.equal(view.traditionalReference.transition.destination,destination);
  assert.equal(view.traditionalReference.transition.transitionType,kind);
  assert.ok(catalog.stateViews[destination-1].traditionalReference);
  assert.match(leelaMarkup(catalog,origin),new RegExp(`data-view-state="${destination}"`));
  assert.match(leelaMarkup(catalog,origin),/do not move your Persona/);
}
for(const t of read('assets/bagua.json').trigrams){
  const view=catalog.trigramViews.find(v=>v.trigramBinary===t.binaryValue);
  assert.equal(view.naturalImage,t.english);assert.equal(view.trigramChinese,t.chinese);
  assert.deepEqual(view.linesBottomToTop,t.linesBottomToTop);
  assert.match(trigramMarkup(view,'Upper'),new RegExp(view.animal));
}
for(const h of catalog.hexagramViews){assert.equal(h.lowerBinary,h.binaryValue%8);assert.equal(h.upperBinary,Math.floor(h.binaryValue/8));}
const primary=pairSelection(7,5,[2]),resulting=pairSelection(7,5,[2],'resulting');
assert.match(leelaMarkup(catalog,37,{type:'ladder',destination:66}),/Game transition preview/);
assert.match(leelaMarkup(catalog,37,{type:'ladder',destination:66}),/Exploring this information does not enter either state/);
assert.match(hexagramMarkup(catalog,primary),/11 · Peace/);
assert.match(hexagramMarkup(catalog,resulting),/36 · Darkening Of The Light/);
assert.match(hexagramMarkup(catalog,resulting),/data-role="primary"/);
assert.match(hexagramMarkup(catalog,primary),/data-role="resulting"/);
assert.match(hexagramMarkup(catalog,primary),/is-changing/);
assert.doesNotMatch(hexagramMarkup(catalog,resulting),/is-changing/);
assert.match(hexagramMarkup(catalog,pairSelection(7,7,[])),/identical/);
assert.throws(()=>pairSelection(-1,5),/unavailable/);
assert.throws(()=>leelaMarkup(catalog,73),/catalogue/);
assert.equal(imageMarkup(null,'optional'),'');
assert.equal(safeAsset('javascript:alert(1)'),null);assert.equal(safeAsset('/assets/../private.png'),null);
assert.match(imageMarkup('/assets/iching/animals/horse.png','Horse'),/horse.png/);
assert.doesNotMatch(leelaMarkup(catalog,72),/<img/);
assert.match(leelaMarkup(catalog,72),/not yet been curated/);
assert.match(hexControl(7,'<script>'),/&lt;script&gt;/);

// Exercise real delegated handlers: network failure, retry, image failure,
// late response after closing, pair navigation and focus restoration.
let listener,activeDialog,loadCount=0,restoreCount=0,fetchMode='fail',resolveFetch;
function node(){return {innerHTML:'',handlers:{},addEventListener(type,fn){this.handlers[type]=fn;},focus(){},setAttribute(){}};}
globalThis.document={addEventListener(type,fn){listener=fn;},createElement(){
  const d=node(),content=node(),close=node();d.querySelector=s=>s==='[data-close-view]'?close:content;d.showModal=()=>{};
  d.close=()=>d.handlers.close();d.remove=()=>{activeDialog=null;};activeDialog=d;return d;
},body:{append(){}}};
globalThis.fetch=async()=>{
  loadCount++;
  if(fetchMode==='fail')return {ok:false};
  if(fetchMode==='pending')return new Promise(resolve=>{resolveFetch=resolve;});
  return {ok:true,json:async()=>catalog};
};
installStateViewer({preview:true});
const click=async(dataset)=>{const button={dataset,isConnected:true,hasAttribute:name=>name==='data-view-state'&&dataset.viewState!==undefined,focus(){restoreCount++;}};await listener({target:{closest:()=>button},preventDefault(){}});};
await click({viewState:'55'});assert.match(activeDialog.querySelector('.state-view-content').innerHTML,/unavailable/);
fetchMode='ok';await click({viewState:'55'});assert.equal(loadCount,2);assert.match(activeDialog.querySelector('.state-view-content').innerHTML,/Ahamkara/);
await click({viewState:'3'});assert.equal(loadCount,2);assert.match(activeDialog.querySelector('.state-view-content').innerHTML,/Discipline/);
const img={tagName:'IMG',hidden:false};activeDialog.handlers.error({target:img});assert.equal(img.hidden,true);
await click({viewHex:'5',primary:'7',resulting:'5',changing:'2',role:'resulting'});assert.match(activeDialog.querySelector('.state-view-content').innerHTML,/36 ·/);
activeDialog.close();assert.equal(activeDialog,null);assert.equal(restoreCount,1);
// Tapping card text/artwork/padding resolves its button, without a CSS overlay.
const cardButton={dataset:{viewState:'3'},isConnected:true,hasAttribute:()=>true,focus(){restoreCount++;}};
const card={querySelector:()=>cardButton};
const cardTarget={closest:selector=>selector==='.local-state'?card:null};
await listener({target:cardTarget,preventDefault(){}});
assert.match(activeDialog.querySelector('.state-view-content').innerHTML,/Discipline/);
activeDialog.close();assert.equal(restoreCount,2);
cardButton.disabled=true;
await listener({target:cardTarget,preventDefault(){}});
assert.equal(activeDialog,null,'disabled cards do not open during a pending action');
installStateViewer({preview:true});fetchMode='pending';const pending=click({viewState:'1'});activeDialog.close();resolveFetch({ok:true,json:async()=>catalog});await pending;assert.equal(activeDialog,null);
console.log('ok - canonical retrieval, transitions, eight trigrams, both hexagrams, artwork fallback, retry, close and focus');
