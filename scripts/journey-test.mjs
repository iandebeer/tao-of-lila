import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {movementDerivation} from '../app/public/journey/components.js';
import {createDemo,scenarios} from '../app/public/journey/demo.js';
const seed=JSON.parse(readFileSync('app/public/journey/preview.json'));
const traces=JSON.parse(readFileSync('app/public/journey/castings.json'));
for(const scenario of scenarios){
  const service=createDemo(seed,traces,scenario);
  if(scenario!=='resume'){
    service.command('question');
    assert.throws(()=>service.command('begin'),/question/);
    service.command('draft','What arises here?');service.command('begin');
  }
  assert.throws(()=>service.command('draft','Rewrite the cast'),/Journey changed/);
  let advances=0;
  while(!service.get().workflow.workflowCasting.result){service.command('next');assert.ok(++advances<150);}
  const saved=service.get();
  const result=saved.workflow.workflowCasting.result;
  assert.equal(result.lilaMoveSquares,result.changingLines.reduce((sum,p)=>sum+p,0)%7);
  assert.equal(result.numberChanging,result.changingLines.length);
  if(scenario==='still-changing') {assert.deepEqual(result.changingLines,[2,5]);assert.equal(result.lilaMoveSquares,0);assert.notEqual(result.primaryBinaryValue,result.transformedBinaryValue);assert.match(movementDerivation(result),/\(2 \+ 5\) mod 7 = 0/);assert.match(movementDerivation(result),/Remain here/);}service.restore(saved);
  assert.deepEqual(service.get(),saved,'resume retains the exact casting');
  service.command('result');
  assert.equal(service.get().history.length,1);
  assert.throws(()=>service.command('result'),/Journey changed/);
  service.command('interpretation');service.interpret();service.command('reflection');
  service.command('journal','My own words, distinct from AI.');
  assert.equal(service.get().interpretation.context,'A development example, not a generated interpretation.');
  const revision=service.get().workflow.workflowRevision;
  assert.throws(()=>service.command('movement','',null,revision-1),/Journey changed/);
  service.command('movement','My own words, distinct from AI.');
  const target=service.get().movement.final.stateId;
  service.command('acknowledge');
  assert.equal(service.get().game.gameJourney.journeyCurrentStateId,target);
  assert.equal(service.get().workflow.workflowStage,'progress');
  assert.throws(()=>service.command('acknowledge'),/Journey changed/);
  assert.equal(service.get().terminal,scenario==='nirvana');
  assert.equal(service.get().history[0].journal,'My own words, distinct from AI.');
  console.log(`ok - ${scenario}: full journey, recovery, immutable question, stale commands, journal, acknowledgment`);
}
