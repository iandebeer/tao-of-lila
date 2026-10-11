import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {build} from '../web/yarrow-casting/node_modules/esbuild/lib/main.js';
const bundle=await build({stdin:{contents:"export * from './web/yarrow-casting/src/line'; export * from './web/yarrow-casting/src/persist'; export * from './web/yarrow-casting/src/journey-state';",resolveDir:process.cwd()},bundle:true,format:'esm',write:false});
const {generateLine,createStalks,snapshot,restoreJourneyVisual}=await import(`data:text/javascript;base64,${Buffer.from(bundle.outputFiles[0].text).toString('base64')}`);
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

// Server migrations may add engine metadata without rewriting stored visuals.
const authoritative={...trace[0],samplingRule:'LeelaBalanced',samplingSeed:42};
const legacyVisual=snapshot(trace[0],'bound',createStalks(trace[0].seed),trace[0].seed);
const restored=restoreJourneyVisual(authoritative,legacyVisual);
assert.deepEqual(restored.engine,authoritative,'restore current engine metadata before saving line 1');
assert.deepEqual(restored.stalks,legacyVisual.stalks,'preserve saved choreography');
assert.equal(restoreJourneyVisual(authoritative,null).engine,authoritative,'start from the current casting, not cached initial data');
for(const engine of trace){
  const recovered=restoreJourneyVisual(engine,null);
  let current=engine;
  const resumed=await generateLine(recovered,async previous=>{
    assert.deepEqual(previous,current);
    current=trace[trace.findIndex(s=>s.stateId===previous.stateId)+1];
    return current;
  },async visual=>assert.deepEqual(visual.engine,current,'every submitted visual matches the authoritative casting'));
  assert.ok(['draw-line','hexagram-complete'].includes(resumed.phase));
}
console.log('ok - restored metadata and missing visual snapshots resume from every server step');

// Exercise the mounted journey with strict server snapshot validation. Stub only
// drawing and animation so this also covers the host's recovery/persist wiring.
const mountedBundle=await build({entryPoints:['web/yarrow-casting/src/journey.ts'],bundle:true,format:'esm',write:false,plugins:[{
  name:'headless-drawing',setup(build){
    build.onLoad({filter:/\/render\.ts$/},()=>({contents:`export const mountScene=()=>({leather:{setAttribute(){}}}); export const applyLeather=()=>{}; export const applyPoses=()=>{}; export const renderHexagram=()=>{};`,loader:'js'}));
    build.onLoad({filter:/\/animator\.ts$/},()=>({contents:`export const animatePoses=async(_from,to)=>to;`,loader:'js'}));
  }
}]});
const {mountJourneyCeremony}=await import(`data:text/javascript;base64,${Buffer.from(mountedBundle.outputFiles[0].text).toString('base64')}`);
for(const recovery of ['old-metadata','stale-visual','missing-visual']){
  const states=trace.map(s=>({...s,samplingRule:'LeelaBalanced',samplingSeed:42}));
  let current=states[recovery==='old-metadata'?0:1],lastSaved;
  const controller=mountJourneyCeremony({svg:{},engine:current,
    saved:recovery==='missing-visual'?null:legacyVisual,
    advance:async previous=>{
      if(current.stateId>previous.stateId)return current;
      current=states[states.findIndex(s=>s.stateId===previous.stateId)+1];return current;
    },persist:async visual=>{
      assert.deepEqual(visual.engine,current,`${recovery}: visual snapshot must match saved casting`);
      lastSaved=visual;
    },describe(){}
  });
  for(let line=1;line<=6;line++){
    await controller.next();
    assert.equal(lastSaved.engine.completedLines.length,line,`${recovery}: line ${line}`);
  }
  assert.deepEqual(lastSaved.engine.result,states.at(-1).result);
  controller.dispose();
}
console.log('ok - mounted journey accepts all six lines with old metadata, stale visuals or missing visuals');
