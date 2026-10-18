import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const nodes=new Map();
function element(){return {hidden:false,disabled:false,value:'',textContent:'',children:[],listeners:{},append(...items){this.children.push(...items);},replaceChildren(...items){this.children=items;},addEventListener(event,fn){this.listeners[event]=fn;}};}
const get=id=>{if(!nodes.has(id))nodes.set(id,element());return nodes.get(id);};
get('period').value='daily';
get('login-form').elements={username:{value:'admin'},password:{value:'test-only-password'},setupToken:{value:'test-only-setup'}};
let configured=false,signedIn=false;
const requests=[];
const stats={trackingSince:'2026-10-16T00:00:00Z',summary:{players:1,personas:2,activePersonas:1,archivedPersonas:1,newPersonas:2,logins:3,casts:2,moves:1,dailyActive:1,weeklyActive:1,monthlyActive:1,newPlayers:1,returningPlayers:0},players:[{id:1,username:'<script>attack()</script>',personas:2,last_login:null,today_logins:1,week_logins:2,month_logins:3,total_logins:3,active_days_30:1}],trends:[{period:'2026-10-16',logins:1,active_players:1,casts:2,moves:1}]};
const context=vm.createContext({Intl,Date,Error,JSON,Object,encodeURIComponent,document:{getElementById:get,createElement:element},FormData:class{constructor(form){this.form=form;}*[Symbol.iterator](){for(const [key,field] of Object.entries(this.form.elements))yield [key,field.value];}},fetch:async(url,options)=>{
 requests.push({url,options});let status=200,data;
 if(url==='/api/status')data={needsSetup:!configured,setupEnabled:true};
 else if(url==='/api/setup'||url==='/api/login'){configured=true;signedIn=true;data={ok:true};}
 else if(url==='/api/logout'){signedIn=false;data={ok:true};}
 else if(url.startsWith('/api/stats')){status=signedIn?200:401;data=signedIn?stats:{error:'Please sign in. Your session may have expired.'};}
 else throw Error('Unexpected request');
 return {ok:status===200,status,json:async()=>data};
}});
vm.runInContext(await readFile('app/admin/admin.js','utf8'),context);
const settle=()=>new Promise(resolve=>setImmediate(resolve));
await settle();
assert.equal(get('auth').hidden,false);
assert.equal(get('setup-secret').hidden,false);
get('login-form').listeners.submit({preventDefault(){},target:get('login-form')});await settle();
assert.equal(get('dashboard').hidden,false);
assert.equal(get('login-form').elements.password.value,'');
assert.equal(get('login-form').elements.setupToken.value,'');
assert.equal(get('login-form').elements.setupToken.required,false);
assert.equal(get('setup-secret').hidden,true);
assert.equal(get('players').children[0].children[1].textContent,'<script>attack()</script>');
assert.equal(get('summary').children[1].children[0].textContent,'2');
assert.equal(get('next').disabled,true);
get('period').value='monthly';get('period').listeners.change();await settle();
assert.ok(requests.at(-1).url.includes('period=monthly'));
get('logout').listeners.click();await settle();
assert.equal(get('dashboard').hidden,true);
assert.equal(get('auth').hidden,false);
assert.equal(get('setup-secret').hidden,true);
for(const {options} of requests.filter(r=>r.options.method==='POST'))assert.equal(options.headers['X-Admin-Request'],'1');
console.log('ok - admin setup/login/logout, cleared credentials, safe username rendering, Persona counts and period selection');
