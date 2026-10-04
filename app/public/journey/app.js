import {personaFieldsMarkup,bindPersonaFields,readPersonaFields,personaAttributesSummary} from './persona-fields.js';
import {localStateField} from './local-field.js';
import {installStateViewer,stateControl,hexControl} from './state-viewer.js';
import {api} from './api.js';
import {createInterpretationFlow} from './interpretation-flow.js';
import {journey,preview,scenario} from './service.js';
import {scenarios} from './demo.js';
import {esc,label,action,questionDisplay,hexagram,reading,movement,movementDerivation,artwork,loadAssets} from './components.js';
import {mountJourneyCeremony} from './ceremony.js';
const main=document.querySelector('main'), nav=document.querySelector('#navigation'), status=document.querySelector('#status');
const interpretationFlow=createInterpretationFlow(journey);
let personas=[], editingPersona=null;
let data=null, catalog=[], labels={}, draft='', journal='', dirty=false, timer, ceremony, ceremonyComplete=false, busy=false, queue=Promise.resolve();
const link=(route,text,secondary=false)=>`<a class="button ${secondary?'secondary':''}" href="#${route}">${text}</a>`;
const w=()=>data.workflow;
const heading=(eyebrow,title)=>`<div class="page-head"><p class="eyebrow">${eyebrow}</p><h1>${title}</h1></div>`;
const buttons=content=>`<div class="actions">${content}</div>`;
const fieldError='<p id="form-error" class="error" role="alert"></p>';
const context=()=>`<div class="context"><small>FROM ${label(data.previousState)}</small><p>CURRENT · ${label(data.fromState)}</p></div>`;
function personaSelection(){return `<section class="narrow">${heading('The Player guides; the Persona journeys','Choose a Persona')}<p>A Persona is a constructed identity. Its circumstances need not describe you.</p>${personas.map(p=>`<article class="panel"><h2>${esc(p.personaName)}</h2><p>${esc(p.personaDescription)}</p>${personaAttributesSummary(p)}<details><summary>Initial Persona and observed themes</summary><p>${esc(p.personaInitialDescription)}</p><p>${esc(p.personaInitialContext)}</p><ul>${p.personaThemes.map(t=>`<li>${esc(t.themeName)} · support ${esc(t.themeConfidence)} · ${esc(t.themeEvidence.length)} observations</li>`).join('')}</ul><a href="#" data-persona-audit="${p.personaId}">Inspect saved history</a></details>${p.personaArchived?'<small>Archived · history retained</small>':`<div class="actions"><button data-persona="${p.personaId}">Resume</button><button class="secondary" data-edit-persona="${p.personaId}">Edit</button><button class="secondary" data-archive-persona="${p.personaId}">Archive</button></div>`}</article>`).join('')}<h2>${editingPersona?'Edit Persona':'Create a Persona'}</h2><form id="persona-form"><label for="persona-name">Name</label><input id="persona-name" required value="${esc(editingPersona?.personaName||'')}">${personaFieldsMarkup(editingPersona)}<label for="persona-context">Additional information</label><textarea id="persona-context" placeholder="Setting, circumstances, aspirations, responsibilities, or anything else that matters to this Persona…">${esc(editingPersona?.personaContext||'')}</textarea>${editingPersona?.personaDescription?`<details><summary>Existing description</summary><label for="persona-description">Previously saved description</label><textarea id="persona-description">${esc(editingPersona.personaDescription)}</textarea></details>`:''}<label for="persona-avatar">Avatar description</label><input id="persona-avatar" value="${esc(editingPersona?.personaAvatar?.avatarDescription||'')}">${fieldError}<button>${editingPersona?'Save changes':'Create Persona and begin'}</button></form></section>`;}
async function selectPersona(id){await api.request(`/personas/${id}/select`,'POST');journey.clear();data=null;await load();go();}
async function choosePersonas(){await saveDraft();personas=await api.request('/personas');editingPersona=null;go('personas');}
function castingLinks(r){const pair={primary:r.primaryBinaryValue,resulting:r.transformedBinaryValue,changing:r.changingLines};return hexControl(r.primaryBinaryValue,`${r.primaryKingWenNumber} · ${name(r.primaryKingWenNumber)}`,pair)+(r.numberChanging?` → ${hexControl(r.transformedBinaryValue,`${r.transformedKingWenNumber} · ${name(r.transformedKingWenNumber)}`,{...pair,role:'resulting'})}`:'');}
function identity(){const r=w().workflowCasting?.result;return r?castingLinks(r):'';}
function name(number){return catalog.find(h=>h.hexagramNumber===number)?.hexagramName||Object.values(labels).find(h=>h.hexagramNumber===number)?.hexagramName||'Name not supplied';}

function splash() { return `<section class="hero"><div class="hero-copy"><p class="eyebrow">A journey of consciousness</p><h1>The Tao<br>of Leela</h1><p class="serif" style="font-size:1.45rem">Every question opens a path.</p><p class="muted">Pause where you are. Listen to the pattern of change. Discover what your next step might reveal.</p><div class="actions">${link('login','Log In')}${link('signup','Sign Up',true)}</div><p><small>A contemplative meeting of Leela and the I Ching.</small></p></div><div class="local-invitation" aria-label="The journey unfolds locally"><p>Present state</p><span aria-hidden="true">↓</span><p>Field of possibility</p><span aria-hidden="true">↓</span><p>Transformation</p><span aria-hidden="true">↓</span><p>New present state</p></div></section>`; }
function auth(signup) { return `<section class="narrow"><p class="eyebrow">${signup ? 'Begin your journey' : 'Return to your journey'}</p><h1>${signup ? 'Make a little space.' : 'Welcome back.'}</h1><p class="muted">${signup ? 'Create an account to keep your questions and your journey together.' : 'Your journey will be waiting where you left it.'}</p><form id="auth" class="panel"><label for="username">User ID</label><input id="username" name="username" autocomplete="username" minlength="3" required><small class="help">Use your registered user ID (at least 3 characters).</small><label for="password">Password</label><input id="password" name="password" type="password" autocomplete="${signup ? 'new-password' : 'current-password'}" ${signup ? 'minlength="10"' : ''} required>${signup ? '<small class="help">Choose at least 10 characters.</small>' : ''}<button type="button" id="password-visibility" class="secondary" aria-controls="password" aria-pressed="false">Show password</button><p id="form-error" class="error" role="alert"></p><div class="actions"><button>${signup ? 'Sign Up' : 'Log In'}</button></div></form><p><a href="#${signup ? 'login' : 'signup'}">${signup ? 'Already have an account? Log In' : 'New here? Sign Up'}</a></p></section>`; }function progress(){
  return `<section class="journey">${heading(esc(personas.find(p=>p.personaId===data.game.gameJourney.journeyPersonaId)?.personaName||'Your Leela progress'),'Here, in this moment.')}${localStateField(data.game)}<p><small>Movement is the sum of changing-line positions modulo 7. A zero result means remain here, even when lines change.${data.topologyAvailable?'':' Active ladder and snake rules are not yet available in this game edition.'}</small></p>${buttons(action('question',w().workflowQuestion?'Refine your question':'Bring a question'))}</section>`;
}
function question(){return `<section class="narrow">${heading('An intention for this encounter','What is asking<br>for your attention?')}${context()}<form id="question-form">${preview?'':buttons(action('suggest','Use a question from the last interpretation',true))}<label for="question">The Persona’s question · edit or replace freely</label><textarea id="question" required placeholder="What might I understand more clearly?">${esc(draft)}</textarea><small id="save-state" class="help">${dirty?'Unsaved changes':'Changes are saved as you write.'}</small>${fieldError}${buttons('<button type="submit">Begin Casting</button>')}</form></section>`;}
function casting(){return `<section>${heading('The yarrow stalks','Let the change unfold.')}${questionDisplay(w().workflowQuestion)}<div class="ceremony-stage"><svg id="scene" viewBox="0 0 1200 620" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Yarrow stalk casting ceremony"></svg><div class="ceremony-dock"><p id="casting-status"></p><p id="caption" aria-live="polite"></p>${fieldError}${buttons(action('next','Next')+action('pause','Pause / Exit',true)+(preview?action('skip','Preview: complete casting',true):''))}</div></div></section>`;}
function interpretation(){const r=w().workflowCasting.result;return `<section>${heading('AI interpretation','Another way of seeing.')}${questionDisplay(w().workflowQuestion)}<div class="hexagrams">${hexagram(r.primaryBinaryValue,r.primaryKingWenNumber,name(r.primaryKingWenNumber),r.changingLines,w().workflowCasting.completedLines,{primary:r.primaryBinaryValue,resulting:r.transformedBinaryValue,changing:r.changingLines})}${r.numberChanging?hexagram(r.transformedBinaryValue,r.transformedKingWenNumber,name(r.transformedKingWenNumber),[],[],{primary:r.primaryBinaryValue,resulting:r.transformedBinaryValue,changing:r.changingLines,role:'resulting'}):''}</div>${data.interpretation?`<div class="reading-panel" tabindex="0" role="region" aria-label="AI interpretation">${reading(data.interpretation)}</div>${buttons(action('reflection','Continue to your reflection'))}`:interpretationFlow.error&&!interpretationFlow.pending?`<p class="error" role="alert">${esc(interpretationFlow.error)}</p><p>Your casting is saved. Retry the AI interpretation to continue to your own reflection.</p>${buttons(action('generate','Retry AI interpretation'))}`:'<p role="status" aria-live="polite">Preparing the AI interpretation of your casting…</p>'}${fieldError}<details><summary>Movement from this casting</summary>${movementDerivation(r)}</details><details><summary>Trigrams and symbolic context</summary><div class="symbol-context">${['lowerTrigramResult','upperTrigramResult','nuclearLowerTrigramResult','nuclearUpperTrigramResult'].map(key=>`<p>${artwork('trigrams',r[key].trigramBinaryValue,r[key].trigramName)}${esc(key.replace('TrigramResult','').replace('nuclear','Nuclear '))}: ${esc(r[key].trigramSymbol)} ${esc(r[key].trigramName)}</p>`).join('')}</div></details></section>`;}

function reflection(){return `<section class="narrow">${heading('Your reflection','What stays with you?')}<p>Having read the AI interpretation, write your own understanding, feelings, or questions below.</p>${questionDisplay(w().workflowQuestion)}<p class="serif">${identity()}</p><small>Changing lines: ${w().workflowCasting.result.changingLines.join(', ')||'none'}</small><p class="gist">${esc(data.interpretation?.context||'No AI interpretation. This space is for your own reflection.')}</p><form id="journal-form"><label for="journal">Your journal</label><textarea id="journal" placeholder="Begin wherever you are…">${esc(journal)}</textarea><small id="save-state" class="help">${dirty?'Unsaved changes':'Your writing is saved as you pause.'}</small>${fieldError}${buttons('<button type="submit">Save / Continue</button>')}</form></section>`;}
function consequence(){return `<section>${heading('Movement and consequence','Carry the insight forward.')}${questionDisplay(w().workflowQuestion)}${movementDerivation(w().workflowCasting.result)}${movement(data.movement)}<p>Your reflection is saved. Continue to acknowledge this movement and update your journey.</p>${fieldError}${buttons(action('acknowledge','Continue the Journey'))}</section>`;}
function history(){return `<section>${heading(data.terminal?'Journey complete':'Your journal',data.terminal?'A place of arrival.':'The path you have taken.')}${data.terminal?`<article class="current"><h2>${label(data.game.gameCurrentState)}</h2><p>${data.history.length} recorded moves</p></article>`:''}<div class="history">${data.history.length?data.history.map(event=>`<details><summary>${esc(event.createdAt?.slice(0,10))} · ${esc(event.from)} → ${esc(event.to)} · ${esc(event.question)}</summary>${questionDisplay(event.question)}<p>${castingLinks(event.casting)}. Changing lines: ${esc(event.casting.changingLines.join(', ')||'none')}</p><details><summary>Saved interpretation</summary>${reading(event.interpretation)}</details><h3>Your reflection</h3><p class="journal-text">${esc(event.journal||'No journal entry recorded.')}</p></details>`).join(''):'<p>Your first encounter is still ahead.</p>'}</div>${data.terminal?'':buttons(action('resume','Return to the journey',true))}</section>`;}
function paused(){return `<section class="narrow">${heading('A moment of stillness','Your place is kept.')}<p>The last accepted step is saved${preview?' in this browser preview':' on the server'}. Return whenever you are ready.</p>${buttons(action('resume','Resume the journey'))}</section>`;}
function sync(value,resetDrafts=false){data=value;if(resetDrafts){draft=w().workflowQuestion;journal=w().workflowJournal;dirty=false;}}
function stage(){return data.terminal?'completion':w().workflowStage;}
function render(){
  ceremony?.dispose();ceremony=null;ceremonyComplete=false;
  let route=location.hash.slice(1)||'splash';
  if(data && !['splash','login','signup','paused','history','personas'].includes(route))route=stage();
  if(!data && !['splash','login','signup','personas'].includes(route))route='login';
  const screens={personas:personaSelection,splash,login:()=>auth(false),signup:()=>auth(true),progress,question,casting,result:interpretation,interpretation,reflection,movement:consequence,completion:history,history,paused};
  nav.innerHTML=data?`${preview?'':action('personas','Personas',true)}${action('pause','Pause',true)}${action('history','History',true)}${action('logout','Log out',true)}`:api.authenticated?`${action('personas','Personas',true)}${action('logout','Log out',true)}`:'<a href="#login">Log In</a>';
  main.innerHTML=(preview?`<div class="demo-banner">Development preview · ${esc(scenario)} · browser-only example, no account or AI request <label for="scenario">Example</label><select id="scenario">${scenarios.map(s=>`<option ${s===scenario?'selected':''}>${s}</option>`).join('')}</select> ${action('reset','Reset example',true)}</div>`:'')+(screens[route]||splash)();
  document.title=`${route.charAt(0).toUpperCase()+route.slice(1)} · The Tao of Leela`;
  main.focus({preventScroll:true});
  window.scrollTo(0,0);
  document.querySelector('#scenario')?.addEventListener('change',e=>{location.href=`?demo&scenario=${encodeURIComponent(e.target.value)}#progress`;});
  document.querySelector('#password-visibility')?.addEventListener('click',e=>{const input=document.querySelector('#password');const show=input.type==='password';input.type=show?'text':'password';e.currentTarget.textContent=show?'Hide password':'Show password';e.currentTarget.setAttribute('aria-pressed',String(show));});
  document.querySelector('#auth')?.addEventListener('submit',e=>{e.preventDefault();const username=e.target.username.value,password=e.target.password.value;run(async()=>{if(!preview)await api.authenticate(route==='signup'?'register':'login',username,password);if(preview){await load();go();}else await choosePersonas();});});
  bindPersonaFields(document);
  document.querySelector('#persona-form')?.addEventListener('submit',e=>{e.preventDefault();run(async()=>{
    const avatar=document.querySelector('#persona-avatar').value;
    const body={draftName:document.querySelector('#persona-name').value,draftDescription:document.querySelector('#persona-description')?.value??editingPersona?.personaDescription??'',draftContext:document.querySelector('#persona-context').value,draftAttributes:readPersonaFields(document,editingPersona),draftAvatar:avatar?{avatarDescription:avatar,avatarAsset:null}:null,draftRevision:editingPersona?.personaRevision??null};
    const saved=await api.request(editingPersona?`/personas/${editingPersona.personaId}`:'/personas',editingPersona?'PUT':'POST',body);if(editingPersona){await choosePersonas();}else{personas.push(saved);await selectPersona(saved.personaId);}
  });});
  document.querySelectorAll('[data-persona-audit]').forEach(link=>link.addEventListener('click',e=>{e.preventDefault();run(async()=>{const history=await api.request(`/personas/${link.dataset.personaAudit}/history`);const details=document.createElement('pre');details.style.whiteSpace='pre-wrap';details.textContent=JSON.stringify(history,null,2);link.replaceWith(details);});}));
  document.querySelectorAll('[data-persona]').forEach(button=>button.addEventListener('click',()=>run(async()=>{await selectPersona(button.dataset.persona);})));
  document.querySelectorAll('[data-edit-persona]').forEach(button=>button.addEventListener('click',()=>{editingPersona=personas.find(p=>p.personaId===Number(button.dataset.editPersona));render();}));
  document.querySelectorAll('[data-archive-persona]').forEach(button=>button.addEventListener('click',()=>run(async()=>{await api.request(`/personas/${button.dataset.archivePersona}`,'DELETE');data=null;journey.clear();await choosePersonas();})));
  for(const [id,kind] of [['question','draft'],['journal','journal']]){
    document.querySelector(`#${id}`)?.addEventListener('input',e=>{if(kind==='draft')draft=e.target.value;else journal=e.target.value;dirty=true;saveLabel('Unsaved changes');clearTimeout(timer);timer=setTimeout(()=>{void saveDraft().catch(showError);},900);});
  }
  document.querySelector('#question-form')?.addEventListener('submit',e=>{e.preventDefault();run(async()=>{if(!draft.trim())throw new Error('Please enter a question before casting.');await saveDraft();await command('begin');go();});});
  document.querySelector('#journal-form')?.addEventListener('submit',e=>{e.preventDefault();run(async()=>{await saveDraft();await command('movement',journal);go();});});
  queueMicrotask(maybeAutoInterpret);
  if(route==='casting'){
    ceremony=mountJourneyCeremony({svg:document.querySelector('#scene'),engine:w().workflowCasting,saved:w().workflowVisual,initial:journey.initial,
      advance:async previous=>{const engine=await journey.advance(previous);sync(journey.state);return engine;},
      persist:async visual=>{await command('visual',null,visual);},
      describe:(caption,text,label,complete)=>{document.querySelector('#caption').textContent=caption;document.querySelector('#casting-status').textContent=text;document.querySelector('[data-action="next"]').textContent=complete?'See the Hexagram':`Next · ${label}`;ceremonyComplete=complete;}
    });
  }
}
function go(route=stage()){location.hash=route;render();}
async function load(){const [projection,hexagrams]=await Promise.all([journey.load(),preview?fetch('./hexagrams.json').then(r=>r.json()):api.request('/hexagrams')]);catalog=hexagrams;sync(projection,true);}
async function command(action,text=null,visual=null){sync(await journey.command(action,text,visual));}
function saveLabel(text){const node=document.querySelector('#save-state');if(node)node.textContent=text;}
function showError(error){if(error.staleSession)return;const node=document.querySelector('#form-error')||status;node.textContent=error.message;node.classList.add('error');saveLabel('Not saved yet. Your writing is still here; retry before leaving.');}
function saveDraft(){
  clearTimeout(timer);
  const operation=async()=>{
    if(!dirty||!data)return;
    const kind=w().workflowStage==='question'?'draft':'journal';
    if(!['question','reflection'].includes(w().workflowStage))return;
    const text=kind==='draft'?draft:journal;
    saveLabel('Saving…');await command(kind,text);
    dirty=text!==(kind==='draft'?draft:journal);
    saveLabel(dirty?'Unsaved changes':preview?'Saved in this preview':'Saved to your journey');
  };
  queue=queue.catch(()=>{}).then(operation);return queue;
}
async function run(operation){
  if(busy)return;busy=true;
  const controls=[...document.querySelectorAll('button,input,select,textarea')];controls.forEach(n=>n.disabled=true);
  status.textContent='';document.querySelector('#form-error')?.replaceChildren();
  try{await operation();}catch(error){showError(error);if(error.message.includes('Journey changed'))status.innerHTML='Another action was saved. Your draft is still here. <button type="button" data-action="reload">Reload saved journey</button>';}
  finally{busy=false;controls.forEach(n=>n.disabled=false);maybeAutoInterpret();}
}
function maybeAutoInterpret(){
  if(busy||!data)return;
  const route=location.hash.slice(1);
  if(route==='casting'&&stage()==='casting'&&ceremonyComplete){void run(finishCasting);return;}
  if(!['result','interpretation'].includes(route)||!interpretationFlow.needs(data))return;
  void run(requestInterpretation);
}
async function requestInterpretation(){
  const pending=interpretationFlow.request();
  render();
  try{sync(await pending);}
  catch(error){if(error.staleSession)throw error;sync(journey.state);}
  finally{render();}
}
async function finishCasting(){await command('result');go('interpretation');}
async function confirmPause(){
  await saveDraft();
  if(stage()==='casting'){
    const accepted=await new Promise(resolve=>{
      const dialog=document.createElement('dialog');dialog.innerHTML='<h2>Pause this casting?</h2><p>Your saved stalk arrangement and completed lines will be here when you return.</p><form method="dialog"><div class="actions"><button value="cancel">Keep casting</button><button class="secondary" value="pause">Pause and exit</button></div></form>';
      document.body.append(dialog);dialog.addEventListener('close',()=>{resolve(dialog.returnValue==='pause');dialog.remove();},{once:true});dialog.showModal();
    });
    if(!accepted)return;
  }
  go('paused');
}
document.addEventListener('click',e=>{
  const button=e.target.closest('[data-action]');if(!button)return;
  const a=button.dataset.action;
  run(async()=>{
    if(a==='personas'){await choosePersonas();return;}
    if(a==='next'){if(ceremonyComplete){await finishCasting();}else{await ceremony.next();if(ceremonyComplete)await finishCasting();}return;}
    if(a==='pause'){await confirmPause();return;}
    if(a==='resume'){go();return;}
    if(a==='history'){await saveDraft();go('history');return;}
    if(a==='logout'){await saveDraft();if(data&&stage()==='casting'){await confirmPause();if(location.hash!=='#paused')return;}api.logout();journey.clear();data=null;dirty=false;go('splash');return;}
    if(a==='reload'){if(dirty&&!confirm('Reload the saved journey and discard your unsaved edits?'))return;await load();go();return;}
    if(a==='reset'){journey.reset();return;}
    if(a==='skip'){sync(await journey.skip());go('interpretation');return;}
    if(a==='suggest'){await saveDraft();await command('suggest');sync(journey.state,true);render();return;}
    if(a==='generate'){await requestInterpretation();return;}
    if(a==='reflection'&&!data.interpretation)return;
    await saveDraft();await command(a);sync(journey.state,true);go();
  });
});
addEventListener('hashchange',()=>{if(!busy)render();});
document.querySelector('.brand').addEventListener('click',e=>{if(busy)e.preventDefault();});
addEventListener('beforeunload',e=>{if(dirty||busy){e.preventDefault();e.returnValue='';}});
document.addEventListener('visibilitychange',()=>{if(document.hidden&&dirty)void saveDraft().catch(showError);});
installStateViewer({preview});
await loadAssets();
try{labels=await fetch('./hexagram-labels.json').then(r=>r.json());}catch{}
render();
if(!preview&&api.authenticated){try{await choosePersonas();}catch(error){if(!error.staleSession&&!api.authenticated){personas=[];data=null;if(!['#login','#signup'].includes(location.hash))go('login');}showError(error);}}
if(preview){status.textContent='Loading your saved journey…';try{await load();status.textContent='';if(location.hash && location.hash!=='#splash')go();else render();}catch(error){showError(error);}}
