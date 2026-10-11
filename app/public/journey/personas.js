import {esc} from './text.js';
import {personaAttributesSummary,personaFieldsMarkup} from './persona-fields.js';

export const availablePersonas=personas=>personas.filter(p=>!p.personaArchived);
export const personaEntryRoute=personas=>availablePersonas(personas).length?'personas':'create-persona';
export function personaAvatar(avatar,name){
  const asset=avatar?.avatarAsset;
  return asset&&/^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(asset)
    ? `<img width="80" height="80" class="persona-avatar" src="${esc(asset)}" alt="Portrait of ${esc(name)}">`
    : `<div class="persona-avatar persona-avatar-placeholder" aria-label="No avatar">${esc((name||'?').trim().slice(0,1))}</div>`;
}
export function personaCards(personas,selected){
  const people=availablePersonas(personas);
  return `<section class="persona-selection"><div class="page-head"><p class="eyebrow">My Personas</p><h1>${people.length===1?'Your Persona':'Choose Your Persona'}</h1></div><p>Choose a perspective to continue its own journey.</p><div class="persona-cards">${people.map(p=>`<article class="panel persona-card ${selected===p.personaId?'selected':''}">${personaAvatar(p.personaAvatar,p.personaName)}<h2>${esc(p.personaName)}</h2>${selected===p.personaId?'<p class="eyebrow">Selected persona</p>':''}${personaAttributesSummary(p)}<div class="actions"><button data-persona="${p.personaId}">Continue Journey</button><button class="secondary" data-edit-persona="${p.personaId}">Edit</button></div><details><summary>Persona details</summary><p>${esc(p.personaDescription)}</p><p>${esc(p.personaContext)}</p><ul>${(p.personaThemes||[]).map(t=>`<li>${esc(t.themeName)} · ${esc(t.themeEvidence.length)} observations</li>`).join('')}</ul><a href="#" data-persona-audit="${p.personaId}">Inspect saved history</a><p><button class="secondary" data-archive-persona="${p.personaId}">Archive Persona</button></p></details></article>`).join('')}</div><div class="actions"><button data-action="create-persona">+ Create New Persona</button></div></section>`;
}
export function personaForm(persona,avatar){
  return `<section class="narrow"><div class="page-head"><p class="eyebrow">A perspective for your journey</p><h1>${persona?'Edit Persona':'Create Persona'}</h1></div><p>A fictional or constructed perspective belonging to you, with its own journey.</p><form id="persona-form"><label for="persona-name">Name</label><input id="persona-name" required maxlength="200" value="${esc(persona?.personaName||'')}">${personaFieldsMarkup(persona)}<label for="persona-description">Tell us more about this persona</label><p class="help">Optional. Add nuance, history, aspirations, or anything the structured fields cannot express.</p><textarea id="persona-description">${esc(persona?.personaDescription||'')}</textarea><section class="avatar-editor" aria-label="Optional avatar"><h2>Avatar <small>(optional)</small></h2><p>Generate a portrait from the persona details above. You can also continue without one.</p><div id="avatar-preview">${avatar?personaAvatar(avatar,persona?.personaName||'your persona'):''}</div><p id="avatar-status" role="status"></p><div class="actions"><button type="button" id="generate-avatar" class="secondary">Generate Avatar</button><button type="button" id="accept-avatar" hidden>Accept</button></div></section><p id="form-error" class="error" role="alert"></p><div class="actions"><button type="submit">${persona?'Save changes':'Create Persona'}</button><button type="button" class="secondary" data-action="personas">Cancel</button></div></form></section>`;
}
