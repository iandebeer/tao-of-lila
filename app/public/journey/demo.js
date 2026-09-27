// Fixed examples for presentation acceptance only. No live game uses this adapter.
export const scenarios = ['zero','still-changing','ordinary','six','ladder','snake','long-reading','long-journal','resume','nirvana'];
const copy = value => structuredClone(value);
export function createDemo(seed, traces, scenario = 'ordinary') {
  const name = scenarios.includes(scenario) ? scenario : 'ordinary';
  const trace = traces[name === 'still-changing' ? 'still-changing' : name === 'zero' ? 'zero' : name === 'six' ? 'six' : 'ordinary'];
  const state = id => seed.states.find(s=>s.stateId === id) || {stateId:id,stateName:id===72?'Nirvana (preview)':'Example state',stateDescription:'Deterministic presentation fixture.',stateSeed:''};
  let data = {
    game:copy(seed.game), fromState:state(2), previousState:state(1), interpretation:null, movement:null,history:[],terminal:false,topologyAvailable:true,
    workflow:{workflowRevision:0,workflowStage:'progress',workflowQuestion:'',workflowCasting:null,workflowVisual:null,workflowEventId:null,workflowFrom:2,workflowPrevious:1,workflowJournal:''}
  };
  if(name==='resume') Object.assign(data.workflow,{workflowStage:'casting',workflowQuestion:'How can I meet this moment?',workflowCasting:copy(traces.resume.engine),workflowVisual:copy(traces.resume)});
  if(['ladder','snake'].includes(name)) Object.assign(data.game.gameAccessibleStates[0],{consequence:name,finalStateId:name==='ladder'?12:1});
  const reflection = {
    context:'A development example, not a generated interpretation.',
    primary_hexagram:('Notice the relationship between seeking and listening. Allow the question to remain open long enough for a different response to emerge.\n\n').repeat(name==='long-reading'?45:2),
    changing_lines:['Change can be approached with care rather than urgency.'],transformation:'Carry one small observation into your next step.',possible_readings:['Practice patience.','Observe what asks for attention.'],questions_for_contemplation:['What feels different now?']
  };
  const allowed = {question:['progress','question'],draft:['question'],begin:['question'],next:['casting'],visual:['casting'],result:['casting'],interpretation:['result'],reflection:['interpretation'],journal:['reflection'],movement:['reflection'],acknowledge:['movement']};
  return {
    initial:copy(trace[0]),
    get:()=>copy(data),
    restore(saved) { data=copy(saved); },
    interpret() {data.interpretation=copy(reflection);if(data.history[0])data.history[0].interpretation=copy(reflection);return copy(data);},
    command(action,text,visual,revision=data.workflow.workflowRevision) {
      const w=data.workflow;
      if(revision!==w.workflowRevision || !allowed[action]?.includes(w.workflowStage)) throw new Error('Journey changed. Reload the saved encounter before continuing.');
      switch(action) {
        case 'question':w.workflowStage='question';break;
        case 'draft':w.workflowQuestion=text;break;
        case 'begin':
          if(!w.workflowQuestion.trim())throw new Error('Enter a question before casting');
          Object.assign(w,{workflowStage:'casting',workflowCasting:copy(trace[0]),workflowVisual:null,workflowJournal:''});break;
        case 'next': {
          const index=trace.findIndex(s=>s.stateId===w.workflowCasting.stateId);
          if(index===trace.length-1)throw new Error('Casting is already complete');
          w.workflowCasting=copy(trace[index+1]);break;
        }
        case 'visual':
          if(JSON.stringify(visual.engine)!==JSON.stringify(w.workflowCasting))throw new Error('Visual snapshot does not match the saved casting');
          w.workflowVisual=copy(visual);break;
        case 'result': {
          if(!w.workflowCasting.result)throw new Error('Complete all six lines first');
          w.workflowStage='result';w.workflowEventId=data.history.length+1;
          // Fixed outcome fixtures, not a movement calculator.
          const targets={zero:[2,2],'still-changing':[2,2],six:[2,2],ladder:[3,12],snake:[3,1],nirvana:[3,72]};
          const ordinary=traces.moves[w.workflowFrom-1][w.workflowCasting.result.lilaMoveSquares];
          const [landing,final]=(data.history.length===0 && targets[name])||[ordinary,ordinary];
          data.movement={amount:w.workflowCasting.result.lilaMoveSquares,from:data.fromState,landing:state(landing),final:state(final),consequence:data.history.length===0 && ['ladder','snake'].includes(name)?name:null};
          data.history.unshift({eventId:w.workflowEventId,from:w.workflowFrom,to:final,question:w.workflowQuestion,journal:'',casting:w.workflowCasting.result,rawCasting:w.workflowCasting,createdAt:'2026-09-11T12:00:00Z',interpretation:null});break;
        }
        case 'interpretation':w.workflowStage='interpretation';break;
        case 'reflection':w.workflowStage='reflection';if(name==='long-journal')w.workflowJournal='I notice a little more room between the question and my response.\n\n'.repeat(35);break;
        case 'journal':w.workflowJournal=text;data.history[0].journal=text;break;
        case 'movement':w.workflowJournal=text;data.history[0].journal=text;w.workflowStage='movement';break;
        case 'acknowledge': {
          data.game.gameJourney.journeyPreviousStateId=w.workflowFrom;
          data.game.gameJourney.journeyCurrentStateId=data.movement.final.stateId;
          data.game.gameCurrentState=copy(data.movement.final);
          data.game.gameAccessibleStates=traces.moves[data.movement.final.stateId-1].slice(1).map(state);
          data.previousState=copy(data.fromState);data.fromState=copy(data.movement.final);
          Object.assign(w,{workflowStage:'progress',workflowQuestion:'',workflowCasting:null,workflowVisual:null,workflowEventId:null,workflowJournal:'',workflowFrom:data.fromState.stateId,workflowPrevious:data.previousState.stateId});
          data.terminal=name==='nirvana';data.interpretation=null;break;
        }
      }
      w.workflowRevision++;return copy(data);
    },
    skip() {data.workflow.workflowCasting=copy(trace.at(-1));data.workflow.workflowVisual=null;return copy(data);}
  };
}
