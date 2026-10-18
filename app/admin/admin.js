const $=id=>document.getElementById(id);
let needsSetup=false,page=0,busy=false;
const count=new Intl.NumberFormat();
async function api(path,body){
  const response=await fetch(`/admin/api/${path}`,{method:body===undefined?'GET':'POST',credentials:'same-origin',cache:'no-store',headers:body===undefined?{}:{'Content-Type':'application/json','X-Admin-Request':'1'},body:body===undefined?undefined:JSON.stringify(body)});
  const data=await response.json();
  if(!response.ok){if(response.status===401&&path.startsWith('stats')){showAuth();}throw Error(data.error||'Request failed. Please try again.');}return data;
}
function showAuth(){$('dashboard').hidden=true;$('logout').hidden=true;$('auth').hidden=false;}
function row(values){const tr=document.createElement('tr');for(const value of values){const td=document.createElement('td');td.textContent=value;tr.append(td);}return tr;}
async function load(){
  const data=await api(`stats?period=${encodeURIComponent($('period').value)}&page=${page}`);
  $('auth').hidden=true;$('dashboard').hidden=false;$('logout').hidden=false;
  $('coverage').textContent=`Login, participation and move tracking began ${new Date(data.trackingSince).toLocaleString('en-GB',{timeZone:'UTC'})} UTC. Earlier logins and moves are not reconstructed. Cast totals include existing saved castings. Player and Persona totals include existing records. New registrations, new Personas and returning players use the selected reporting range. Returning players participated on a later UTC day than a previous visit.`;
  const labels={players:'Registered players',personas:'Total Personas created',activePersonas:'Active Personas',archivedPersonas:'Archived Personas',newPersonas:'New Personas · selected range',logins:'Total tracked logins',casts:'Total saved casts',moves:'Total tracked moves',dailyActive:'Active players · today',weeklyActive:'Active players · 7 days',monthlyActive:'Active players · 30 days',newPlayers:'New players · selected range',returningPlayers:'Returning players · selected range'};
  $('summary').replaceChildren(...Object.entries(labels).map(([key,label])=>{const card=document.createElement('div');card.className='card';const number=document.createElement('strong'),caption=document.createElement('span');number.textContent=count.format(data.summary[key]);caption.textContent=label;card.append(number,caption);return card;}));
  $('trends').replaceChildren(...data.trends.map(t=>row([t.period,t.logins,t.active_players,t.casts,t.moves])));
  $('players').replaceChildren(...data.players.map(p=>row([p.id,p.username,p.personas,p.last_login?new Date(p.last_login).toLocaleString('en-GB',{timeZone:'UTC'}):'No tracked login',p.today_logins,p.week_logins,p.month_logins,p.total_logins,p.active_days_30])));
  $('previous').disabled=page===0;$('next').disabled=(page+1)*100>=data.summary.players;$('page').textContent=`Page ${page+1} · 100 players per page`;
}
async function run(action){if(busy)return;busy=true;$('status').textContent='Loading…';try{await action();$('status').textContent='';}catch(error){$('status').textContent=error.message;}finally{busy=false;}}
$('login-form').addEventListener('submit',event=>{event.preventDefault();void run(async()=>{const form=event.target;const body=Object.fromEntries(new FormData(form));form.elements.password.value='';form.elements.setupToken.value='';await api(needsSetup?'setup':'login',body);needsSetup=false;$('setup-secret').hidden=true;$('setup-help').hidden=true;form.elements.setupToken.required=false;form.elements.password.autocomplete='current-password';$('auth-title').textContent='Administrator sign in';page=0;await load();});});
$('logout').addEventListener('click',()=>void run(async()=>{await api('logout',{});showAuth();}));
$('refresh').addEventListener('click',()=>void run(load));
$('period').addEventListener('change',()=>void run(async()=>{page=0;await load();}));
$('previous').addEventListener('click',()=>void run(async()=>{page=Math.max(0,page-1);await load();}));
$('next').addEventListener('click',()=>void run(async()=>{page++;await load();}));
// No polling: an unattended dashboard must not keep its session alive.
void run(async()=>{const status=await api('status');needsSetup=status.needsSetup;$('auth-title').textContent=needsSetup?'Set administrator password':'Administrator sign in';$('setup-secret').hidden=!needsSetup;$('setup-help').hidden=!needsSetup;$('login-form').elements.setupToken.required=needsSetup;$('login-form').elements.password.autocomplete=needsSetup?'new-password':'current-password';if(needsSetup){showAuth();if(!status.setupEnabled)throw Error('Administrator setup is disabled. Configure the private setup secret in Railway first.');}else{try{await load();}catch(error){showAuth();if(!error.message.startsWith('Please sign in'))throw error;}}});
