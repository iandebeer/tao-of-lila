// Package the canonical viewer records for both Haskell and the static demo.
// Existing seed identities remain authoritative; supplementary facts live in metadata.
import {readFileSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
const read=path=>JSON.parse(readFileSync(path,'utf8'));
export function buildCatalog(){
  const {stateMetadata,...metadata}=read('data/state-view-metadata.json');
  const seed=read('data/leela.json');
  return {...metadata,stateViews:stateMetadata.map(({stateId,...extra})=>({identity:seed.find(s=>s.stateId===stateId)||{stateId,stateName:`Lila State ${stateId}`,stateDescription:'Consciousness-state commentary is not yet seeded for this prototype.',stateSeed:'Unseeded state'},...extra}))};
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
  const serialized=JSON.stringify(buildCatalog(),null,2)+'\n';
  for(const path of ['data/state-views.json','app/public/journey/state-views.json']){
    if(process.argv.includes('--check')){
      if(readFileSync(path,'utf8')!==serialized)throw Error(`${path} is stale; run node scripts/build-state-catalog.mjs`);
    }else writeFileSync(path,serialized);
  }
}
