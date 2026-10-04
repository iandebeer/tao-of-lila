import {esc,label,artwork} from './components.js';
import {stateControl} from './state-viewer.js';

// Only the engine's reachable states belong here. The 72-state catalogue is
// for lookup, never a source from which the client invents possible moves.
export function localStateField(game){
  const current=game.gameCurrentState;
  const possibilities=(game.gameAccessibleStates||[]).filter(Boolean);
  const transitionPreview=s=>{
    // Active topology supplied by the game projection, not the separately
    // labelled traditional reference edition in the information catalogue.
    if(!['snake','ladder'].includes(s.consequence)||!Number.isInteger(s.finalStateId))return '';
    return `<p class="transition-preview">${s.consequence==='snake'?'↓ Snake':'↑ Arrow / ladder'} → State ${esc(s.finalStateId)}<small>Preview only · applies if this destination is reached.</small></p>`;
  };
  return `<div class="local-field" aria-label="Present state and reachable possibilities"><article class="current local-state">${artwork('states',current.stateId,'Current consciousness state')}<span class="eyebrow">Current · State ${esc(current.stateId)}</span><h2>${esc(current.stateName)}</h2><p>${esc(current.stateDescription)}</p><p class="muted serif">${esc(current.stateSeed)}</p>${stateControl(current.stateId,`Explore current state ${current.stateId}`)}</article><div class="arrow" aria-hidden="true">↓</div><p class="eyebrow">Field of possibility</p><p class="help">Explore a possible state without entering it. Your Persona stays here until movement is determined and acknowledged.</p>${possibilities.length?`<ol class="possibilities">${possibilities.map(s=>`<li class="possibility local-state"><span class="step">+${s.stateId-current.stateId}</span><div><small>Possible movement +${s.stateId-current.stateId}</small><h3>${label(s)}</h3>${artwork('states',s.stateId,s.stateName)}<p>${esc(s.stateDescription)}</p>${transitionPreview(s)}${stateControl(s.stateId,`Explore possible state ${s.stateId}`,{type:s.consequence,destination:s.finalStateId})}</div></li>`).join('')}</ol>`:'<p class="no-destinations">There are no forward destinations from this state.</p>'}</div>`;
}
