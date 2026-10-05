import {availablePersonas,personaEntryRoute,personaCards,personaForm,personaAvatar} from '../app/public/journey/personas.js';
import {splashMarkup,bindSplashTerms} from '../app/public/journey/splash.js';
// Exercise the UI event handlers with a small DOM and an in-memory API.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createInterpretationFlow} from '../app/public/journey/interpretation-flow.js';
import {personaFieldsMarkup,bindPersonaFields,readPersonaFields,personaAttributesSummary} from '../app/public/journey/persona-fields.js';
const source=readFileSync('app/public/journey/app.js','utf8').replace(/^import .*;\n/gm,'');
for(const [mode,count,avatarMode] of [['signup',0,'skip'],['login',0,'fail'],['login',1,'accept'],['login',2,'unaccepted'],['login',2,'regenerate']]){
  const nodes=new Map(),requests=[],people=Array.from({length:count},(_,i)=>({personaId:i+1,personaName:`Existing ${i+1}`,personaThemes:[]}));
  let selected=null, savedBody=null, generated=0;
  const events={};
  const node=selector=>{
    if(!nodes.has(selector))nodes.set(selector,{innerHTML:'',textContent:'',value:'',handlers:{},classList:{add(){}},focus(){},replaceChildren(){},addEventListener(type,fn){this.handlers[type]=fn;}});
    return nodes.get(selector);
  };
  const document={querySelector:node,querySelectorAll(selector){
    if(selector==='[data-persona]')return people.filter(p=>node('main').innerHTML.includes(`data-persona="${p.personaId}"`)).map(p=>{const button=node(`select-${p.personaId}`);button.dataset={persona:String(p.personaId)};return button;});
    return [];
  },addEventListener(type,handler){events[type]=handler;}};
  let authenticated=false;
  const projection={workflow:{workflowStage:'question',workflowQuestion:'',workflowJournal:''},game:{gameJourney:{journeyPersonaId:1}},previousState:null,fromState:null};
  const api={get authenticated(){return authenticated;},async authenticate(kind){requests.push(kind);authenticated=true;},async request(path,method,body){
    requests.push(`${method||'GET'} ${path}`);
    if(path==='/personas'&&method==='POST'){assert.equal(body.draftAttributes.find(a=>a.attributeName==='age').attributeValue,45);assert.equal(body.draftAttributes.find(a=>a.attributeName==='historicalPeriod').attributeValue,'Renaissance (c. 1400–1600, Europe)');savedBody=body;const p={personaId:people.length+1,personaName:body.draftName,personaThemes:[]};people.push(p);return p;}
    if(path==='/personas/avatar'){generated++;if(avatarMode==='fail')throw Error('Generation unavailable');return {avatarDescription:'Generated portrait',avatarAsset:'data:image/png;base64,'+(generated===1?'AAAA':'BBBB')};}
    if(path==='/personas')return people;
    if(path==='/hexagrams')return [];
    if(/^\/personas\/\d+\/select$/.test(path)){selected=Number(path.split('/')[2]);return people.find(p=>p.personaId===selected);}
    throw Error(`Unexpected request ${path}`);
  }};
  const journey={clear(){},async load(){assert.ok(selected,'persona selected before loading game');return {...projection,game:{gameJourney:{journeyPersonaId:selected}}};}};
  let hash=`#${mode}`;
  const location={get hash(){return hash;},set hash(value){hash=value.startsWith('#')?value:`#${value}`;},search:''};
  const context=vm.createContext({availablePersonas,personaEntryRoute,personaCards,personaForm,personaAvatar,splashMarkup,bindSplashTerms,document,api,journey,createInterpretationFlow,queueMicrotask,personaFieldsMarkup,bindPersonaFields,readPersonaFields,personaAttributesSummary,installStateViewer:()=>{},localStateField:()=>'',stateControl:()=>'',hexControl:()=>'',preview:false,scenario:'',scenarios:[],location,window:{scrollTo(){}},addEventListener(){},loadAssets:async()=>{},fetch:async()=>({json:async()=>({})}),setTimeout,clearTimeout,esc:String,label:()=>'',action:()=>'',questionDisplay:()=>'',hexagram:()=>'',reading:()=>'',movement:()=>'',movementDerivation:()=>'',artwork:()=>''});
  await vm.runInContext(`(async()=>{${source}\n})()`,context);
  node('#auth').handlers.submit({preventDefault(){},target:{username:{value:'test-player'},password:{value:'test-password'}}});
  await new Promise(resolve=>setImmediate(resolve));
  if(count){
    assert.equal(context.location.hash,'#personas');
    assert.doesNotMatch(node('main').innerHTML,/<form/,'existing personas must never automatically open creation');
    assert.match(node('main').innerHTML,/Continue Journey/);
    assert.match(node('main').innerHTML,/Create New Persona/);
    if(count===1){assert.equal(selected,1);assert.match(node('main').innerHTML,/Selected persona/);}
    else {assert.equal(selected,null);assert.match(node('main').innerHTML,/Choose Your Persona/);}
    await node(`select-${count}`).handlers.click();
    assert.equal(selected,count,'Continue Journey selects the requested existing persona');
    assert.equal(context.location.hash,'#question');
    events.click({target:{closest:()=>({dataset:{action:'personas'}})}});
    await new Promise(resolve=>setImmediate(resolve));
    assert.equal(context.location.hash,'#personas','My Personas remains reachable from the journey');
    events.click({target:{closest:()=>({dataset:{action:'create-persona'}})}});
    await new Promise(resolve=>setImmediate(resolve));
  }
  assert.equal(context.location.hash,'#create-persona');
  assert.match(node('main').innerHTML,/Tell us more about this persona/);
  assert.equal(requests[0],mode==='signup'?'register':'login');
  assert.ok(!requests.includes('GET /journey-session'));
  node('#persona-name').value='The Wanderer';
  node('#persona-age').value='45';
  node('#persona-historicalPeriod').value='Renaissance (c. 1400–1600, Europe)';
  node('#persona-place').value='Florence';node('#persona-definingCharacteristic').value='Curious';node('#persona-lifeStage').value='Midlife';
  node('#persona-description').value='A patient observer';
  if(avatarMode!=='skip'){
    await node('#generate-avatar').handlers.click();
    assert.equal(node('#persona-description').value,'A patient observer','generation preserves the form');
    if(avatarMode==='fail')assert.match(node('#avatar-status').textContent,/without an avatar/);
    else {
      assert.match(node('#avatar-preview').innerHTML,/data:image/);
      if(avatarMode==='regenerate'){await node('#generate-avatar').handlers.click();assert.equal(generated,2);}
      if(['accept','regenerate'].includes(avatarMode))node('#accept-avatar').handlers.click();
    }
  }
  node('#persona-form').handlers.submit({preventDefault(){}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(context.location.hash,'#question');
  assert.equal(people.length,count+1);
  assert.equal(selected,count+1);
  assert.equal(savedBody.draftAttributes.find(a=>a.attributeName==='place').attributeValue,'Florence');
  assert.equal(savedBody.draftDescription,'A patient observer');
  if(['skip','fail','unaccepted'].includes(avatarMode))assert.equal(savedBody.draftAvatar,null,'only accepted avatars are saved');
  else assert.match(savedBody.draftAvatar.avatarAsset,avatarMode==='regenerate'?/BBBB$/:/AAAA$/);
  console.log(`ok - ${mode}, ${count} existing personas, avatar ${avatarMode}: routing, explicit creation, context and optional avatar persistence`);
}

assert.equal(personaEntryRoute([{personaId:1,personaArchived:true}]),'create-persona','archived personas do not prevent creating the first active persona');
