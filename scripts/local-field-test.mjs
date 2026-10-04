import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {localStateField} from '../app/public/journey/local-field.js';
const state=n=>({stateId:n,stateName:`State ${n}`,stateDescription:'A canonical meaning',stateSeed:'Context'});
for(const current of [1,34,69,70,71,72]){
  const game={gameCurrentState:state(current),gameAccessibleStates:Array.from({length:Math.min(6,72-current)},(_,i)=>state(current+i+1))};
  const before=JSON.stringify(game),html=localStateField(game);
  const visible=[...html.matchAll(/data-view-state="(\d+)"/g)].map(m=>Number(m[1]));
  assert.deepEqual(visible,[current,...game.gameAccessibleStates.map(s=>s.stateId)]);
  assert.equal(JSON.stringify(game),before,'rendering possible states must not move a Persona');
  assert.doesNotMatch(html,/Not supplied|No destination supplied/);
  if(current===72)assert.match(html,/no forward destinations/);
}
const game={gameCurrentState:state(34),gameAccessibleStates:[state(35),state(36),{...state(37),consequence:'ladder',finalStateId:66},state(38),state(39),state(40)]};
const before=JSON.stringify(game),html=localStateField(game);
assert.match(html,/↑ Arrow \/ ladder → State 66/);
assert.match(html,/Preview only/);assert.match(html,/data-transition="ladder" data-destination="66"/);assert.doesNotMatch(html,/data-view-state="66"/,'transition destinations are described, not additional local tiles');
assert.equal(JSON.stringify(game),before);
assert.match(localStateField({gameCurrentState:state(54),gameAccessibleStates:[{...state(55),consequence:'snake',finalStateId:3}]}),/↓ Snake → State 3/);
assert.doesNotMatch(localStateField({gameCurrentState:state(34),gameAccessibleStates:[state(37)]}),/Arrow \/ ladder/,'reference-only transitions must not be advertised as live rules');
// A server-supplied subset is displayed directly, not padded or inferred.
assert.deepEqual([...localStateField({gameCurrentState:state(70),gameAccessibleStates:[state(72)]}).matchAll(/data-view-state="(\d+)"/g)].map(m=>Number(m[1])),[70,72]);
assert.match(localStateField({gameCurrentState:state(70),gameAccessibleStates:[state(72)]}),/Possible movement \+2/);
const app=readFileSync('app/public/journey/app.js','utf8');
assert.doesNotMatch(app,/length:\s*72|function board\(/,'the journey UI must not construct a complete board');
assert.match(app,/localStateField\(data.game\)/);
console.log('ok - local-only states, end-of-board counts, selectable cards, transition previews and unchanged position');
