// One automatic attempt per encounter per page session. Failed attempts wait
// for an explicit retry; successful readings are retrieved from server storage.
export function createInterpretationFlow(journey){
  const attempts=new Set();
  let pending=false,error='';
  const key=state=>`${state.game.gameJourney.journeyPersonaId}:${state.workflow.workflowEventId}`;
  return {
    get pending(){return pending;},
    get error(){return error;},
    needs(state){return state && ['result','interpretation'].includes(state.workflow.workflowStage) && (!state.interpretation || state.workflow.workflowStage==='result') && !attempts.has(key(state)) && !pending;},
    async request(){
      if(pending)return journey.state;
      attempts.add(key(journey.state));pending=true;error='';
      try{
        if(journey.state.workflow.workflowStage==='result')await journey.command('interpretation');
        if(!journey.state.interpretation)await journey.interpret();
        return journey.state;
      }catch(cause){error=cause.message;throw cause;}
      finally{pending=false;}
    }
  };
}
