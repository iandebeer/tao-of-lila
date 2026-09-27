// Run after journey-fixtures.hs; bundles with the existing esbuild dependency.
import {readFileSync, writeFileSync} from 'node:fs';
import {assignForTransition} from '../web/yarrow-casting/src/assign';
import {continueNeedsAdvance, phaseAfterContinue} from '../web/yarrow-casting/src/ceremony';
import {createStalks, snapshot} from '../web/yarrow-casting/src/persist';
const path='app/public/journey/castings.json';
const traces=JSON.parse(readFileSync(path,'utf8'));
let index=0;
let visual=snapshot(traces.ordinary[0],'bound',createStalks(traces.ordinary[0].seed),traces.ordinary[0].seed);
while(index<24){
  const engine=continueNeedsAdvance(visual.phase)?traces.ordinary[++index]:visual.engine;
  const phase=phaseAfterContinue(visual.phase,engine);
  visual=snapshot(engine,phase,assignForTransition(visual.stalks,visual.phase,phase,engine),visual.visualSeed);
}
traces.resume=visual;
writeFileSync(path,JSON.stringify(traces)+'\n');
