// Exercise the UI event handlers with a small DOM and an in-memory API.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {personaFieldsMarkup,bindPersonaFields,readPersonaFields,personaAttributesSummary} from '../app/public/journey/persona-fields.js';
const source=readFileSync('app/public/journey/app.js','utf8').replace(/^import .*;\n/gm,'');
for(const mode of ['signup','login']){
  const nodes=new Map(),requests=[],people=[];
  const node=selector=>{
    if(!nodes.has(selector))nodes.set(selector,{innerHTML:'',textContent:'',value:'',handlers:{},classList:{add(){}},focus(){},replaceChildren(){},addEventListener(type,fn){this.handlers[type]=fn;}});
    return nodes.get(selector);
  };
  const document={querySelector:node,querySelectorAll:()=>[],addEventListener(){}};
  let authenticated=false;
  const projection={workflow:{workflowStage:'question',workflowQuestion:'',workflowJournal:''},game:{gameJourney:{journeyPersonaId:1}},previousState:null,fromState:null};
  const api={get authenticated(){return authenticated;},async authenticate(kind){requests.push(kind);authenticated=true;},async request(path,method,body){
    requests.push(`${method||'GET'} ${path}`);
    if(path==='/personas'&&method==='POST'){assert.equal(body.draftAttributes.find(a=>a.attributeName==='age').attributeValue,45);assert.equal(body.draftAttributes.find(a=>a.attributeName==='historicalPeriod').attributeValue,'Renaissance (c. 1400–1600, Europe)');const p={personaId:1,personaName:body.draftName,personaThemes:[]};people.push(p);return p;}
    if(path==='/personas')return people;
    if(path==='/hexagrams')return [];
    if(path==='/personas/1/select')return people[0];
    throw Error(`Unexpected request ${path}`);
  }};
  const journey={clear(){},async load(){assert.ok(requests.includes('POST /personas/1/select'),'persona selected before loading game');return projection;}};
  let hash=`#${mode}`;
  const location={get hash(){return hash;},set hash(value){hash=value.startsWith('#')?value:`#${value}`;},search:''};
  const context=vm.createContext({document,api,journey,personaFieldsMarkup,bindPersonaFields,readPersonaFields,personaAttributesSummary,installStateViewer:()=>{},localStateField:()=>'',stateControl:()=>'',hexControl:()=>'',preview:false,scenario:'',scenarios:[],location,window:{scrollTo(){}},addEventListener(){},loadAssets:async()=>{},fetch:async()=>({json:async()=>({})}),setTimeout,clearTimeout,esc:String,label:()=>'',action:()=>'',questionDisplay:()=>'',hexagram:()=>'',reading:()=>'',movement:()=>'',movementDerivation:()=>'',artwork:()=>''});
  await vm.runInContext(`(async()=>{${source}\n})()`,context);
  node('#auth').handlers.submit({preventDefault(){},target:{username:{value:'test-player'},password:{value:'test-password'}}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(context.location.hash,'#personas');
  assert.match(node('main').innerHTML,/Create Persona and begin/);
  assert.equal(requests[0],mode==='signup'?'register':'login');
  assert.ok(!requests.includes('GET /journey-session'));
  node('#persona-name').value='The Wanderer';
  node('#persona-age').value='45';
  node('#persona-historicalPeriod').value='Renaissance (c. 1400–1600, Europe)';
  node('#persona-form').handlers.submit({preventDefault(){}});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(context.location.hash,'#question');
  assert.deepEqual(requests.slice(2),['POST /personas','POST /personas/1/select','GET /hexagrams']);
  console.log(`ok - ${mode}: persona form is reachable; creation selects persona before loading journey`);
}
