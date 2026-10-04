import {api} from './api.js';
import {createDemo} from './demo.js';
const params=new URLSearchParams(location.search);
export const preview=params.has('demo');
export const scenario=params.get('scenario')||'ordinary';
let fixture, state, initial;
const cacheKey=`tao-journey-preview-mod7-v1-${scenario}`;
export const journey={
  get state(){return state;},
  get initial(){return initial;},
  async load(){
    if(preview){
      if(!fixture){
        const [seed,traces]=await Promise.all([fetch('./preview.json').then(r=>r.json()),fetch('./castings.json').then(r=>r.json())]);
        fixture=createDemo(seed,traces,scenario);initial=fixture.initial;
        try{const saved=sessionStorage.getItem(cacheKey);if(saved)fixture.restore(JSON.parse(saved));}catch{}
      }
      state=fixture.get();
    }else{
      state=await api.request('/journey-session');
      initial=state.workflow.workflowCasting;
    }
    return state;
  },
  async command(action,text=null,visual=null){
    state=preview?fixture.command(action,text,visual):await api.request('/journey-session','POST',{expectedRevision:state.workflow.workflowRevision,commandPersonaId:state.game.gameJourney.journeyPersonaId,commandAction:action,commandText:text,commandVisual:visual});
    if(action==='begin')initial=state.workflow.workflowCasting;
    if(preview)sessionStorage.setItem(cacheKey,JSON.stringify(state));
    return state;
  },
  async interpret(){
    if(preview){state=fixture.interpret();sessionStorage.setItem(cacheKey,JSON.stringify(state));}
    else{await api.request(`/game/contemplation/${state.workflow.workflowEventId}`,'POST');await journey.load();}
    return state;
  },
  async advance(previous){
    const current=state.workflow.workflowCasting;
    // The server may already have accepted Next before a connection was lost.
    if(current.stateId>previous.stateId)return current;
    await journey.command('next');return state.workflow.workflowCasting;
  },
  skip(){state=fixture.skip();return journey.command('result');},
  reset(){sessionStorage.removeItem(cacheKey);location.reload();},
  clear(){state=null;fixture=null;}
};
