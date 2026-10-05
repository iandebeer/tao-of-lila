import {esc} from './text.js';

// Structured narrative attributes use the existing PersonaAttribute domain
// boundary. No attribute is inferred from a Player, a name, or another field.
export const personaFields=[
  {name:'sex',label:'Sex / gender',options:['Woman','Man','Non-binary','Female','Male','Intersex'],custom:true,help:'Optional. Select a term or describe it in your own words.'},
  {name:'age',label:'Age (years)',type:'number',help:'Optional. Age of the Persona at the time of the journey.'},
  {name:'lifeStage',label:'Life stage',type:'text',help:'For example: young adult, midlife, elder. Use age, life stage, or both.'},
  {name:'raceEthnicity',label:'Cultural / ethnic background',type:'text',help:'Optional. Use terms appropriate to this Persona’s cultural and historical setting.'},
  {name:'historicalPeriod',label:'Time period',options:['Prehistoric','Ancient world','Medieval period (c. 500–1500 CE)','Renaissance (c. 1400–1600, Europe)','Early modern period (c. 1500–1800)','Industrial era (c. 1750–1914)','Modern era (c. 1900–1945)','Contemporary / postmodern era (1945–present)','Future / speculative'],custom:true,help:'Periods overlap and vary by region. You can specify another period or an exact year.'},
  {name:'place',label:'Place / cultural setting',type:'text',help:'For example: Hangzhou, Song China; a contemporary coastal village; a future settlement.'},
  {name:'definingCharacteristic',label:'Defining characteristic',type:'text',help:'A quality, role, or tension that helps define this persona.'}
];
export function currentPersonaAttributes(persona){
  const values=new Map();
  for(const attribute of [...(persona?.personaInitialAttributes||[]),...(persona?.personaEvolvingAttributes||[])])values.set(attribute.attributeName,attribute);
  return [...values.values()];
}
export function personaFieldsMarkup(persona){
  const attributes=currentPersonaAttributes(persona);
  return `<fieldset class="persona-fields"><legend>The Persona’s circumstances</legend><p class="help">Describe as much as you wish; unspecified details stay open. These details describe your constructed Persona, not you.</p><div class="persona-field-grid">${personaFields.map(field=>{
    const value=attributes.find(a=>a.attributeName===field.name)?.attributeValue??'';
    const custom=field.options&&value!==''&&!field.options.includes(value);
    const id=`persona-${field.name}`;
    const input=field.options?`<select id="${id}" aria-describedby="${id}-help"><option value="">Unspecified</option>${field.options.map(option=>`<option value="${esc(option)}" ${value===option?'selected':''}>${esc(option)}</option>`).join('')}<option value="__custom__" ${custom?'selected':''}>Self-describe / specify</option></select><div id="${id}-custom-wrap" ${custom?'':'hidden'}><label for="${id}-custom">${field.name==='sex'?'Self-described sex / gender':'Specific period / year'}</label><input id="${id}-custom" maxlength="200" value="${esc(custom?value:'')}" ${custom?'required':''}></div>`:`<input id="${id}" type="${field.type}" ${field.type==='number'?'min="0" step="1"':'maxlength="200"'} value="${esc(value)}" aria-describedby="${id}-help">`;
    return `<div><label for="${id}">${esc(field.label)}</label>${input}<small id="${id}-help" class="help">${esc(field.help)}</small></div>`;
  }).join('')}</div></fieldset>`;
}
export function bindPersonaFields(document){
  for(const field of personaFields.filter(f=>f.custom)){
    const select=document.querySelector(`#persona-${field.name}`);if(!select)continue;
    select.addEventListener('change',()=>{
      const custom=select.value==='__custom__';
      document.querySelector(`#persona-${field.name}-custom-wrap`).hidden=!custom;
      const input=document.querySelector(`#persona-${field.name}-custom`);input.required=custom;
      if(custom)input.focus();
    });
  }
}
export function readPersonaFields(document,persona){
  const reserved=new Set(personaFields.map(f=>f.name));
  const preserved=currentPersonaAttributes(persona).filter(a=>!reserved.has(a.attributeName));
  return [...preserved,...personaFields.map(field=>{
    let value=document.querySelector(`#persona-${field.name}`).value.trim();
    if(value==='__custom__'){
      value=document.querySelector(`#persona-${field.name}-custom`).value.trim();
      if(!value)throw Error(`Please describe ${field.label.toLowerCase()} or choose Unspecified.`);
    }
    if(field.type==='number'&&value!==''){
      const number=Number(value);
      if(!Number.isSafeInteger(number)||number<0)throw Error('Age must be a non-negative whole number.');
      value=number;
    }
    return {attributeName:field.name,attributeValue:value===''?null:value,attributeOrigin:persona?'PlayerIntervention':'PlayerSpecified',attributeEvidence:[]};
  })];
}
export function personaAttributesSummary(persona){
  const attributes=currentPersonaAttributes(persona);
  const entries=personaFields.flatMap(field=>{
    const value=attributes.find(a=>a.attributeName===field.name)?.attributeValue;
    return value===null||value===undefined||value===''?[]:[`<div><dt>${esc(field.label)}</dt><dd>${esc(value)}</dd></div>`];
  });
  return entries.length?`<dl class="persona-attribute-summary">${entries.join('')}</dl>`:'';
}
