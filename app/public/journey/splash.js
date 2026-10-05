const terms={
  lila:{name:'Lila',description:'An ancient Indian game of self-knowledge in which movement across the board represents changing states of human experience.'},
  iching:{name:'I Ching',description:'The ancient Chinese Book of Changes, using hexagrams to reflect patterns of change and transformation.'}
};
const term=id=>`<span class="splash-term"><button type="button" class="splash-term-button" aria-describedby="${id}-explanation" aria-controls="${id}-explanation" aria-expanded="false">${terms[id].name}</button><span class="splash-explanation" id="${id}-explanation" role="tooltip" hidden><strong>${terms[id].name}</strong><span>${terms[id].description}</span></span></span>`;
export function splashMarkup(){
  return `<section class="splash" aria-labelledby="splash-title"><header class="splash-heading"><h1 id="splash-title">Tao of Lila</h1><p class="splash-subtitle">A contemplative meeting of ${term('lila')} and the ${term('iching')}</p></header><img class="splash-artwork" width="1254" height="1254" src="/assets/splash/a_richly_detailed_ornate_fantasy_chinese_taoist_i.png" alt="Tao of Lila artwork: a stylised board with snakes and ladders, a central Yin-Yang and Bagua, I Ching symbols, mountains, water and clouds" decoding="async" fetchpriority="high" hidden><div class="splash-entry"><div class="actions"><a class="button" href="#login">Log in</a><a class="button secondary" href="#signup">Sign up</a></div><p class="splash-invitation">Every question opens a path.</p></div></section>`;
}

export function bindSplashTerms(root=document){
  const terms=[...root.querySelectorAll('.splash-term')];
  if(!terms.length)return ()=>{};
  const lifetime=new AbortController();
  const listen=(node,event,handler)=>node.addEventListener(event,handler,{signal:lifetime.signal});
  const setOpen=(term,open)=>{
    term.querySelector('button').setAttribute('aria-expanded',String(open));
    term.querySelector('[role="tooltip"]').hidden=!open;
  };
  const closeAll=()=>terms.forEach(term=>setOpen(term,false));
  const open=term=>{closeAll();setOpen(term,true);};
  for(const term of terms){
    const button=term.querySelector('button');
    listen(term,'pointerenter',event=>{if(event.pointerType==='mouse')open(term);});
    listen(term,'pointerleave',event=>{if(event.pointerType==='mouse')setOpen(term,false);});
    listen(term,'focusin',()=>open(term));
    listen(term,'focusout',event=>{if(!term.contains(event.relatedTarget))setOpen(term,false);});
    // Opening (rather than toggling) also handles touch browsers that focus
    // the button before dispatching its click.
    listen(button,'click',()=>open(term));
  }
  listen(root,'pointerdown',event=>{if(!terms.some(term=>term.contains(event.target)))closeAll();});
  listen(root,'keydown',event=>{if(event.key==='Escape')closeAll();});
  const artwork=root.querySelector('.splash-artwork');
  if(artwork){
    // Never display a broken-image placeholder if the local asset is absent.
    listen(artwork,'load',()=>{artwork.hidden=false;});
    if(artwork.complete&&artwork.naturalWidth>0)artwork.hidden=false;
  }
  return ()=>lifetime.abort();
}
