import {esc} from './text.js';

export function safeAsset(path){return typeof path==='string' && /^\/assets\/[a-zA-Z0-9_./-]+$/.test(path) && !path.includes('..')?path:null;}
export function imageMarkup(path,alt){const safe=safeAsset(path);return safe?`<img class="state-art" src="${esc(safe)}" alt="${esc(alt)}" loading="lazy">`:'';}
const colour=v=>/^#[0-9a-f]{6}$/i.test(v?.hue||'')?v.hue:'transparent';
const artwork=v=>imageMarkup(v?.imageAsset,'State artwork');
const stateById=(catalog,id)=>catalog.stateViews.find(s=>s.identity.stateId===Number(id));
const hexById=(catalog,id)=>catalog.hexagramViews.find(h=>h.binaryValue===Number(id));
export function pairSelection(primary,resulting,changing=[],role='primary'){
  const valid=b=>Number.isInteger(b)&&b>=0&&b<64;
  if(!valid(primary)||!valid(resulting))throw Error('Hexagram information is unavailable.');
  return {primary,resulting,changing:[...new Set(changing.filter(n=>Number.isInteger(n)&&n>=1&&n<=6))],role:role==='resulting'?'resulting':'primary'};
}
export function hexControl(binary,text,selection={}){
  const p=selection.primary??binary,r=selection.resulting??binary,c=selection.changing||[];
  return `<button type="button" class="state-link" data-view-hex="${esc(binary)}" data-primary="${esc(p)}" data-resulting="${esc(r)}" data-changing="${esc(c.join(','))}" data-role="${esc(selection.role||'primary')}">${esc(text)}</button>`;
}
export const stateControl=(id,text='Explore this state',relation={})=>`<button type="button" class="state-link" aria-haspopup="dialog" data-view-state="${esc(id)}"${['snake','ladder'].includes(relation.type)&&Number.isInteger(relation.destination)?` data-transition="${esc(relation.type)}" data-destination="${esc(relation.destination)}"`:''}>${esc(text)}</button>`;
export function lineFigure(binary,count,changing=[]){return `<div class="state-lines" role="img" aria-label="Lines from bottom to top: ${Array.from({length:count},(_,i)=>binary>>i&1?'Yang':'Yin').join(', ')}">${Array.from({length:count},(_,i)=>count-1-i).map(bit=>`<div class="state-line ${binary>>bit&1?'yang':'yin'} ${changing.includes(bit+1)?'is-changing':''}"><span></span><span></span><small>${bit+1}${changing.includes(bit+1)?' •':''}</small></div>`).join('')}</div>`;}
export function trigramMarkup(t,position){
  if(!t)return '<p>Trigram details are not yet available.</p>';
  return `<section class="trigram-field" style="--state-hue:${colour(t.trigramVisual)}"><p class="eyebrow">${esc(position)}</p><div class="trigram-mark"><span lang="zh">${esc(t.trigramChinese)}</span>${lineFigure(t.trigramBinary,3)}</div><h3>${esc(t.trigramPinyin)} · ${esc(t.naturalImage)}</h3>${artwork(t.trigramVisual)}${imageMarkup(t.animalImageAsset,t.animal)}<dl class="association-labels"><div><dt>Family</dt><dd>${esc(t.family)}</dd></div><div><dt>Animal</dt><dd>${esc(t.animal)}</dd></div>${t.trigramVisual.element?`<div><dt>Element</dt><dd>${esc(t.trigramVisual.element)}</dd></div>`:''}<div><dt>Earlier Heaven</dt><dd>${esc(t.earlierHeavenDirection)}</dd></div><div><dt>Later Heaven</dt><dd>${esc(t.laterHeavenDirection)}</dd></div></dl></section>`;
}
export function leelaMarkup(catalog,id,activeTransition={}){
  const view=stateById(catalog,id);if(!view)throw Error('This tile is not in the state catalogue.');
  const s=view.identity,v=view.visualIdentity,ref=view.traditionalReference,t=ref?.transition;
  const target=t?stateById(catalog,t.destination)?.traditionalReference:null;
  const activeTarget=['snake','ladder'].includes(activeTransition.type)?stateById(catalog,activeTransition.destination):null;
  const activePreview=activeTarget?`<section class="state-transition"><p class="eyebrow">Game transition preview · ${activeTransition.type==='snake'?'↓ Snake':'↑ Arrow / ladder'}</p><p>Landing on ${s.stateId} leads to ${activeTarget.identity.stateId} · ${esc(activeTarget.identity.stateName)} in this game. That destination becomes the resting state when the movement is applied.</p><p>Exploring this information does not enter either state.</p>${stateControl(activeTarget.identity.stateId,'Explore the transition destination')}</section>`:'';
  return `<div class="state-atmosphere" style="--state-hue:${colour(v)}"><p class="eyebrow">Leela · Tile ${s.stateId}</p><h2 id="state-view-title">${esc(s.stateName)}</h2>${activePreview}${artwork(v)}${v.symbol?`<p class="state-symbol">${esc(v.symbol)}</p>`:''}<p class="state-lead">${esc(s.stateDescription)}</p>${v.element?`<p>Element · ${esc(v.element)}</p>`:''}<section><h3>Canonical meaning</h3><p>${esc(view.canonicalInterpretation||'An expanded description has not yet been curated for this tile.')}</p></section>${ref?`<section class="reference-state"><p class="eyebrow">Traditional reference · separate board edition</p><h3>${esc(ref.sanskritName)} · ${esc(ref.englishName)}</h3><p>${esc(ref.coreMeaning)}</p><p>${esc(ref.traditionalInterpretation)}</p>${t?`<div class="state-transition"><p class="eyebrow">${t.transitionType==='snake'?'↓ Snake · descent':'↑ Arrow / ladder · ascent'}</p><p>In this reference board, landing on ${s.stateId} leads immediately to ${t.destination}. The destination is the resting state.</p><h3>${esc(target?.sanskritName)} · ${esc(target?.englishName)}</h3><p>${esc(t.transitionInterpretation)}</p>${stateControl(t.destination,`Explore destination ${t.destination}`)}</div>`:'<p>No transition is recorded in this reference entry.</p>'}<small>These reference relationships do not move your Persona in the current game.</small></section>`:'<p class="muted">No traditional transition has been curated for this tile.</p>'}<section class="viewer-reflection"><h3>A space for reflection</h3><p>How does this state meet the Persona’s situation? Canonical descriptions stay stable; a contextual interpretation can offer another perspective.</p></section></div>`;
}
export function hexagramMarkup(catalog,selection){
  const b=selection.role==='resulting'?selection.resulting:selection.primary,h=hexById(catalog,b);
  if(!h)throw Error('This hexagram is not in the state catalogue.');
  const upper=catalog.trigramViews.find(t=>t.trigramBinary===h.upperBinary),lower=catalog.trigramViews.find(t=>t.trigramBinary===h.lowerBinary);
  return `<div class="hexagram-view"><p class="eyebrow">${selection.role==='resulting'?'Resulting · configuration toward which the casting moves':'Primary · configuration encountered'}</p><h2 id="state-view-title">${h.kingWenNumber} · ${esc(h.translatedName)}</h2><div class="hexagram-field">${trigramMarkup(upper,'Upper trigram')}<section class="hexagram-centre"><span class="hex-glyph" aria-hidden="true">${esc(h.glyph)}</span>${h.chineseName?`<p class="chinese-name" lang="zh">${esc(h.chineseName)}</p>`:''}${lineFigure(b,6,selection.role==='primary'?selection.changing:[])}<p>${selection.role==='primary'?'• marks changing lines.':'The resulting figure is shown after the change.'}</p></section>${trigramMarkup(lower,'Lower trigram')}</div><section><h3>Traditional perspective</h3><p>${esc(h.traditionalSummary||'A concise interpretation has not yet been curated for this hexagram.')}</p><small>Tao of Lila editorial summary, distinct from an AI interpretation. Hues are an editorial palette; associations are symbolic, not predictions.</small></section><nav class="state-pair" aria-label="Casting transformation">${hexControl(selection.primary,'Primary',{...selection,role:'primary'})}<span>→ Changing lines: ${esc(selection.changing.join(', ')||'none')} →</span>${hexControl(selection.resulting,'Resulting',{...selection,role:'resulting'})}</nav>${selection.primary===selection.resulting?'<p>The primary and resulting configurations are identical.</p>':''}<details><summary>Sources and interpretation boundaries</summary><p>${esc(catalog.catalogNote)}</p><ul>${catalog.sources.map(s=>`<li>${esc(s)}</li>`).join('')}</ul></details></div>`;
}

// Native dialog keeps keyboard focus inside the information layer. Opening or
// closing it never changes hashes, saves a draft, or advances the ceremony.
export function installStateViewer({preview=false}={}){
  let catalogPromise,dialog,opener,request=0;
  const load=()=>catalogPromise??=(fetch(preview?'./state-views.json':'/state-views').then(r=>{if(!r.ok)throw Error('State information could not be loaded. Please try again.');return r.json();}).catch(error=>{catalogPromise=null;throw error;}));
  const close=()=>dialog?.close();
  document.addEventListener('click',async event=>{
    // Resolve the card's real button so text, artwork and padding all open
    // the same view, with keyboard focus returning to an accessible control.
    const direct=event.target.closest('[data-view-state],[data-view-hex]');
    const card=event.target.closest('.local-state');
    const button=direct||(!event.target.closest('button,a,input,textarea,select')&&card?.querySelector('[data-view-state]'));
    if(!button||button.disabled)return;
    event.preventDefault();
    if(!dialog){
      opener=button;dialog=document.createElement('dialog');dialog.className='state-viewer';dialog.setAttribute('aria-labelledby','state-view-title');
      dialog.innerHTML='<div class="state-toolbar"><span>THE TAO OF LEELA · STATE VIEW</span><button type="button" data-close-view aria-label="Close state view">Close ×</button></div><div class="state-view-content"></div>';
      document.body.append(dialog);
      dialog.querySelector('[data-close-view]').addEventListener('click',close);
      dialog.addEventListener('close',()=>{request++;dialog.remove();dialog=null;if(opener?.isConnected)opener.focus({preventScroll:true});});
      dialog.addEventListener('click',e=>{if(e.target===dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)close();}});
      dialog.addEventListener('error',e=>{if(e.target.tagName==='IMG')e.target.hidden=true;},true);
      dialog.showModal();
    }
    const token=++request,content=dialog.querySelector('.state-view-content');
    content.innerHTML='<h2 id="state-view-title">Loading state…</h2>';
    try{
      const catalog=await load();if(token!==request||!dialog)return;
      content.innerHTML=button.hasAttribute('data-view-state')?leelaMarkup(catalog,button.dataset.viewState,{type:button.dataset.transition,destination:Number(button.dataset.destination)}):hexagramMarkup(catalog,pairSelection(Number(button.dataset.primary),Number(button.dataset.resulting),button.dataset.changing.split(',').filter(Boolean).map(Number),button.dataset.role));
      dialog.scrollTop=0;
      dialog.querySelector('[data-close-view]').focus({preventScroll:true});
    }catch(error){if(token===request&&dialog)content.innerHTML=`<h2 id="state-view-title">State information unavailable</h2><p role="alert">${esc(error.message)}</p><p>Close this view and select the state again to retry. Your journey has not changed.</p>`;}
  });
}
