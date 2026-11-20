import {api} from './api.js?v=300d94877a81596b';
import {action,esc,hexagram,reading} from './components.js?v=300d94877a81596b';
import {mountJourneyCeremony} from './ceremony.js?v=300d94877a81596b';

// Deliberately memory-only: no persona, question, workflow, or browser storage.
export function createPrivateCasting({transport=api,mount=mountJourneyCeremony}={}){
  let engine=null, response=null, error='', pending=false, generation=0;
  return {
    get active(){return engine!==null;},
    clear(){generation++;engine=null;response=null;error='';pending=false;},
    async begin(){
      this.clear();const current=generation;
      const initial=await transport.request('/casting/initial');
      if(current===generation)engine=initial;
    },
    markup(name=()=>''){
      if(!engine)return '<p>Return to My Personas to begin a private casting.</p>';
      const intro='<div class="page-head"><p class="eyebrow">Private casting</p><h1>Hold your question quietly.</h1></div><p>Keep your question in mind as you cast. This reading is not saved to a persona or journey. Leaving this page clears it.</p>';
      const exit=action('private-exit','Return to My Personas',true);
      if(!engine.result)return `<section>${intro}<div class="ceremony-stage"><svg id="private-scene" viewBox="0 0 1200 620" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Private yarrow stalk casting ceremony"></svg><div class="ceremony-dock"><p id="private-status"></p><p id="private-caption" aria-live="polite"></p><p id="form-error" class="error" role="alert"></p><div class="actions">${action('private-next','Next')}${exit}</div></div></div></section>`;
      const r=engine.result, pair={primary:r.primaryBinaryValue,resulting:r.transformedBinaryValue,changing:r.changingLines};
      return `<section>${intro}<div class="hexagrams"><div><p class="eyebrow">Primary hexagram</p>${hexagram(r.primaryBinaryValue,r.primaryKingWenNumber,name(r.primaryKingWenNumber)||'Primary hexagram',r.changingLines,engine.completedLines,pair)}</div><div><p class="eyebrow">${r.numberChanging?'Resulting hexagram':'Unchanging hexagram'}</p>${hexagram(r.transformedBinaryValue,r.transformedKingWenNumber,name(r.transformedKingWenNumber)||(r.numberChanging?'Resulting hexagram':'Unchanging hexagram'),[],[],{...pair,role:'resulting'})}</div></div><p>Changing lines: ${esc(r.changingLines.join(', ')||'none — the hexagram is unchanging')}.</p>${response?`<div class="reading-panel" tabindex="0" role="region" aria-label="Private I Ching interpretation">${reading(response.modelContemplation)}</div>`:pending?'<div class="interpretation-wait" role="status" aria-live="polite">Preparing your I Ching interpretation…</div>':`<p class="error" role="alert">${esc(error)}</p><div class="actions">${action('private-interpret','Retry interpretation')}</div>`}<p id="form-error" class="error" role="alert"></p><div class="actions">${action('private-new','New private casting')}${exit}</div></section>`;
    },
    bind(root){
      if(!engine||engine.result)return null;
      return mount({svg:root.querySelector('#private-scene'),engine,saved:null,
        advance:async previous=>{engine=await transport.request('/casting/line','POST',previous);return engine;},
        describe:(caption,status,label)=>{
          root.querySelector('#private-caption').textContent=caption;
          root.querySelector('#private-status').textContent=status;
          root.querySelector('[data-action="private-next"]').textContent=label;
        }
      });
    },
    get complete(){return Boolean(engine?.result);},
    async interpret(redraw){
      if(!engine?.result||pending||response)return;
      const current=generation, casting=engine;pending=true;error='';redraw();
      try{
        const result=await transport.request('/private-casting/interpret','POST',casting);
        if(current===generation)response=result;
      }catch(failure){
        if(current===generation)error=failure.message;
        if(failure.status===401)throw failure;
      }finally{if(current===generation){pending=false;redraw();}}
    }
  };
}
