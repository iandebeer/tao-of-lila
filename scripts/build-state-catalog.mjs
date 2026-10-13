// Package the canonical viewer records for both Haskell and the static demo.
// One reference edition supplies identities, descriptions and bilingual sources.
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
export function buildCatalog(){
  const {stateMetadata,...metadata}=read('data/state-view-metadata.json');
  const library=read('data/references/library.json');
  const leela=new Map(library.referenceLeela.map(e=>[e.referenceState.stateId,e]));
  const hexes=new Map(library.referenceHexagrams.map(e=>[e.referenceBinary,e.referenceText]));
  return {...metadata,catalogVersion:library.referenceVersion,
    catalogNote:'Traditional 72-square names with original Tao of Lila commentary. Bhagavad Gita chapters provide thematic background, not historical explanations of numbered squares. I Ching passages pair the received Chinese text with James Legge’s public-domain translation. Reference snakes and arrows remain separate from movement rules.',
    sources:['Reference snake and ladder endpoints: https://en.quantumgame.love/guide/leela-board-72-squares.html (board relationships only; commentary is original)', 'Tao of Lila original tile commentary (MIT); data/references/leela-editorial.json',...library.referenceDocuments.map(d=>`${d.documentAuthor} · ${d.documentTitle} · ${d.documentYear || 'ancient text'} · ${d.documentSource}`)],
    stateViews:stateMetadata.map(({stateId,...extra})=>({ ...extra, identity:leela.get(stateId).referenceState,canonicalInterpretation:leela.get(stateId).referenceCommentary })),
    hexagramViews:metadata.hexagramViews.map(h=>({...h,chineseName:hexes.get(h.binaryValue).textChineseName,sourceText:hexes.get(h.binaryValue)}))};
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
  const serialized=JSON.stringify(buildCatalog(),null,2)+'\n';
  for(const path of ['data/state-views.json','app/public/journey/state-views.json']){
    if(process.argv.includes('--check')){
      if(readFileSync(path,'utf8')!==serialized)throw Error(`${path} is stale; run node scripts/build-state-catalog.mjs`);
    }else writeFileSync(path,serialized);
  }
}
