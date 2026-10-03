import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {build} from '../web/yarrow-casting/node_modules/esbuild/lib/main.js';
const bundle=await build({stdin:{contents:"export * from './web/yarrow-casting/src/line'; export * from './web/yarrow-casting/src/persist';",resolveDir:process.cwd()},bundle:true,format:'esm',write:false});
const {generateLine,createStalks,snapshot}=await import(`data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString('base64')}`);
const traces=JSON.parse(readFileSync('app/public/journey/castings.json'));
for(const name of ['ordinary','zero','six','still-changing']){
  const trace=traces[name], saved=[];
  const advance=async previous=>trace[trace.findIndex(s=>s.stateId===previous.stateId)+1];
  let visual=snapshot(trace[0],'bound',createStalks(trace[0].seed),trace[0].seed);
  for(let line=1;line<=6;line++){
    visual=await generateLine(visual,advance,async s=>saved.push(s));
    assert.equal(visual.engine.completedLines.length,line,`${name}: one new line per click`);
    assert.equal(visual.phase,line===6?'hexagram-complete':'draw-line');
  }
  assert.deepEqual(visual.engine.result,trace.at(-1).result);
  // Every persisted intermediate phase can resume to a visible line or completion.
  for(const interrupted of saved){
    const resumed=await generateLine(interrupted,advance,async()=>{});
    assert.ok(['draw-line','hexagram-complete'].includes(resumed.phase));
    assert.ok(resumed.engine.completedLines.length>=interrupted.engine.completedLines.length);
    assert.ok(resumed.engine.completedLines.length<=interrupted.engine.completedLines.length+1);
  }
  console.log(`ok - ${name}: six clicks, engine result preserved, ${saved.length} resume points`);
}
// Failed persistence must allow retry against an already accepted engine step.
const trace=traces.ordinary;
let visual=snapshot(trace[0],'bound',createStalks(trace[0].seed),trace[0].seed), current=trace[0], fail=true;
const advance=async previous=>{if(current.stateId>previous.stateId)return current;current=trace[trace.findIndex(s=>s.stateId===previous.stateId)+1];return current;};
await assert.rejects(generateLine(visual,advance,async s=>{if(s.engine.stateId===4&&fail){fail=false;throw Error('connection lost');}visual=s;}),/connection lost/);
visual=await generateLine(visual,advance,async s=>{visual=s;});
assert.equal(visual.engine.completedLines.length,1);
assert.deepEqual(visual.engine.completedLines,trace.find(s=>s.event==='LineComplete').completedLines);
console.log('ok - retry after engine acceptance without recasting');
