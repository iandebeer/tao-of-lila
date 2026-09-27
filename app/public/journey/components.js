export const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const label=s=>s?`${esc(s.stateId)} · ${esc(s.stateName)}`:'The beginning of your journey';
export const action=(id,text,secondary=false)=>`<button type="button" data-action="${id}" class="${secondary?'secondary':''}">${text}</button>`;
export const questionDisplay=text=>`<blockquote class="question-display"><span class="eyebrow">Your question</span><p>${esc(text)}</p></blockquote>`;
let assets={};
export async function loadAssets(){try{assets=await fetch('./assets.json').then(r=>r.json());}catch{assets={};}}
export function artwork(kind,id,title){
  const path=assets[kind]?.[id];
  return typeof path==='string' && /^\.?\.?\//.test(path)?`<img class="symbol-art" src="${esc(path)}" alt="${esc(title)}">`:`<span class="art-slot" role="img" aria-label="${esc(title)} artwork placeholder"></span>`;
}
export function hexagram(binary,number,name,changing=[],values=[]){
  const lines=Array.from({length:6},(_,i)=>5-i).map(bit=>`<div class="hex-line ${changing.includes(bit+1)?'changing':''}"><span class="line-number">${bit+1}</span><span class="${(binary>>bit)&1?'yang':'yin'}" aria-hidden="true"></span><span class="line-value">${values.find(v=>v.lineNumber===bit+1)?.lineValue??''}${changing.includes(bit+1)?' •':''}</span></div>`).join('');
  return `<article class="panel hexagram">${artwork('hexagrams',binary,'Hexagram')}<p class="eyebrow">Hexagram ${esc(number??'—')}</p><h2>${esc(name||'Name not supplied')}</h2><div role="img" aria-label="Hexagram lines top to bottom: ${Array.from({length:6},(_,i)=>((binary>>(5-i))&1)?'Yang':'Yin').join(', ')}">${lines}</div><small>Lines are numbered from the bottom. • Changing line</small></article>`;
}
export function reading(response){
  if(!response)return '<p class="muted">No AI interpretation has been saved for this move.</p>';
  const section=(title,value)=>`<section><h3>${title}</h3>${(Array.isArray(value)?value:[value]).map(v=>`<p>${esc(v)}</p>`).join('')}</section>`;
  return section('Context',response.context)+section('Primary hexagram',response.primary_hexagram)+section('Changing lines',response.changing_lines)+section('Transformation',response.transformation)+section('Possible readings',response.possible_readings)+section('Questions to sit with',response.questions_for_contemplation);
}
export function movement(view){
  if(!view)return '<p>No movement has been recorded.</p>';
  return `<div class="movement-path"><article class="panel"><span class="eyebrow">From</span><h2>${label(view.from)}</h2></article><div class="movement-amount">${view.amount===0?'Remain':`+${esc(view.amount)}`}<span aria-hidden="true"> → </span></div><article class="panel"><span class="eyebrow">${view.consequence?'Landing':'Destination'}</span><h2>${label(view.landing)}</h2></article></div>${view.consequence?`<article class="panel consequence">${artwork('consequences',view.consequence,view.consequence)}<p class="eyebrow">${esc(view.consequence)}</p><p>Square ${esc(view.landing.stateId)} → Square ${esc(view.final.stateId)}</p><h2>${label(view.final)}</h2></article>`:''}`;
}

// Display the stored result; do not recompute movement in the browser.
export function movementDerivation(result){
  const positions=result.changingLines.join(' + ')||'0';
  const formula=result.movementRule==='changing-line-positions-mod7-v1'
    ? `(${positions}) mod 7 = ${result.lilaMoveSquares}`
    : `${result.lilaMoveSquares} (recorded under the earlier movement rule)`;
  return `<div class="context"><p>Changing lines: ${esc(result.changingLines.join(', ')||'none')}</p><p>Movement: ${esc(formula)}</p><strong>${result.lilaMoveSquares===0?'Remain here':`Move ${esc(result.lilaMoveSquares)} squares`}</strong></div>`;
}
