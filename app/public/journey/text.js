export const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// Text remains escaped; blank lines become paragraphs and single line breaks
// remain visible, including paired Chinese source text and translations.
export function paragraphs(value){
  return String(value??'').replace(/\r\n?/g,'\n').trim().split(/\n[ \t]*\n+/)
    .filter(part=>part.trim()).map(part=>`<p>${esc(part.trim()).replace(/\n/g,'<br>')}</p>`).join('');
}

// Scope this renderer to one reading or reference panel. Saved text is untouched.
// Ignore typography and whitespace when comparing; preserve the first wording.
const paragraphParts=value=>String(value??'').replace(/\r\n?/g,'\n').trim().split(/\n[ \t]*\n+/).map(p=>p.trim()).filter(Boolean);
const paragraphKey=value=>value.normalize('NFKC').replace(/[“”]/g,'"').replace(/[‘’]/g,"'").replace(/\s+/g,' ').trim().toLocaleLowerCase('en');
export function createParagraphRenderer(alreadyRendered=[]){
  const seen=new Set(alreadyRendered.flatMap(paragraphParts).map(paragraphKey));
  return value=>paragraphParts(value).filter(part=>{
    const key=paragraphKey(part);if(seen.has(key))return false;
    seen.add(key);return true;
  }).map(part=>`<p>${esc(part).replace(/\n/g,'<br>')}</p>`).join('');
}
