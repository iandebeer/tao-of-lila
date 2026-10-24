import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createParagraphRenderer} from '../app/public/journey/text.js';
import {reading} from '../app/public/journey/components.js';
import {personaCards} from '../app/public/journey/personas.js';
import {hexagramSources,leelaMarkup} from '../app/public/journey/state-viewer.js';
const count=(html,text)=>html.split(text).length-1;
const response={context:'A quiet moment.\n\nA distinct insight.',primary_hexagram:' A quiet   moment. \n\nWater can flow around this difficulty.',changing_lines:['A distinct insight.','A different line.'],transformation:'A different line.',possible_readings:['Water can flow around this difficulty.','A new possibility.'],questions_for_contemplation:['What can be left open?','What can be left open?','What deserves attention?']};
const original=JSON.stringify(response);
const html=reading(response);
for(const phrase of ['A quiet moment.','A distinct insight.','Water can flow around this difficulty.','A different line.','What can be left open?'])assert.equal(count(html,phrase),1,phrase);
assert.doesNotMatch(html,/<li>\s*<\/li>/);
assert.doesNotMatch(html,/<h3>Transformation<\/h3>/,'suppress empty sections');
assert.equal(JSON.stringify(response),original,'saved wording remains untouched');
assert.doesNotMatch(reading(response,['A quiet moment.']),/A quiet moment/,'already rendered question/profile paragraphs are omitted');
const prose=createParagraphRenderer();
assert.match(prose('They said “pause”.'),/They said/);
assert.equal(prose('they said "pause".'),'','typography and case do not cause duplicates');
assert.match(prose('<script>alert(1)</script>'),/&lt;script&gt;/,'escape untrusted prose');
assert.match(prose('道可道\nThe way that can be spoken.'),/道可道<br>The way/,'preserve bilingual text');
assert.match(reading(response),/A quiet moment/,'new render has its own scope');
const people=personaCards([{personaId:1,personaName:'Traveller',personaDescription:'Patient observer.\n\nLives by a river.',personaContext:'Patient observer.',personaThemes:[]}],1);
assert.equal(count(people,'Patient observer.'),1,'profile/context share duplicate suppression');
const library=JSON.parse(readFileSync('data/references/library.json'));
const text=library.referenceHexagrams[0].referenceText;
const source=hexagramSources(text,{role:'primary',changing:[1,3]});
for(let i=0;i<6;i++){
 assert.equal(count(source,text.textLineChinese[i]),1,`Chinese line ${i+1} once`);
 // Escaping apostrophes changes the HTML, so check original through decoded text.
 const decoded=source.replaceAll('&#39;',"'").replaceAll('&quot;','"').replaceAll('&amp;','&');
 assert.equal(count(decoded,text.textLeggeLines[i].translationText),1,`English line ${i+1} once`);
}
const catalog=JSON.parse(readFileSync('data/state-views.json'));
const lead='A shared description.';
const tile=structuredClone(catalog);tile.stateViews[0].identity.stateDescription=lead;tile.stateViews[0].canonicalInterpretation=lead;
assert.equal(count(leelaMarkup(tile,1),lead),1,'tile lead is not repeated as commentary');
const walk=path=>readdirSync(path,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(`${path}/${e.name}`):/\.(html|js)$/.test(e.name)?[`${path}/${e.name}`]:[]);
for(const file of [...walk('app/public'),...walk('app/admin')])assert.doesNotMatch(readFileSync(file,'utf8'),/\bAI\b|OpenAI|artificial intelligence/i,`UI wording in ${file}`);
console.log('ok - unique reading paragraphs/questions, persona descriptions, source lines, bilingual text, escaping and UI wording');
