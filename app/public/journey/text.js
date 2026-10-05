export const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

// Text remains escaped; blank lines become paragraphs and single line breaks
// remain visible, including paired Chinese source text and translations.
export function paragraphs(value){
  return String(value??'').replace(/\r\n?/g,'\n').trim().split(/\n[ \t]*\n+/)
    .filter(part=>part.trim()).map(part=>`<p>${esc(part.trim()).replace(/\n/g,'<br>')}</p>`).join('');
}
