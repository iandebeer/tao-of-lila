import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';
import {marked} from 'marked';
const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../..'),out=resolve(here,'dist');
const pages=[['user-manual.md','guide','User manual'],['introduction-pamphlet.md','introduction','An invitation to Leela']];
const esc=s=>s.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const slug=s=>s.replace(/<[^>]+>/g,'').toLowerCase().replace(/[^\w\s-]/g,'').trim().replace(/\s+/g,'-');
marked.use({renderer:{
  heading({tokens,depth}){const text=this.parser.parseInline(tokens);return `<h${depth} id="${slug(text)}">${text}</h${depth}>\n`;},
  link({href,tokens}){const text=this.parser.parseInline(tokens);if(href.startsWith('developer-manual.md'))return text+' (in the source repository)';
    for(const [source,path] of pages)if(href.startsWith(source))href='/'+path+'/'+href.slice(source.length);
    if(!/^(https?:|#|\/)/.test(href))throw Error('Unmapped link: '+href);
    return `<a href="${esc(href)}">${text}</a>`;},
  image({href,text}){if(href==='diagrams/user-interface-flow.svg')href='/images/user-interface-flow.svg';return `<img src="${esc(href)}" alt="${esc(text)}" loading="lazy">`;}
}});
const shell=(title,path,body)=>`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${esc(title)} · Leela</title><meta name="description" content="An invitation and practical guide to the Tao of Leela: a contemplative game of questions, change and reflection."><link rel="canonical" href="https://read.leela.day${path}"><link rel="stylesheet" href="/style.css"><link rel="stylesheet" href="/shared/screen-info.css?v=screen-info-20261020"><script src="/shared/screen-info.js?v=screen-info-20261020" defer></script></head><body data-screen-info="${path==='/'?'reading':path==='/404.html'?'missing':path.split('/')[1]}"><a class="skip" href="#main">Skip to content</a><header><a class="brand" href="/">Leela <span>Reading room</span></a><nav aria-label="Main navigation"><a href="/introduction/">Introduction</a><a href="/guide/">User manual</a><a class="play" href="https://play.leela.day/journey/">Play Leela ↗</a></nav></header><main id="main">${body}</main><footer><p>The Tao of Leela · A space for questions, change and reflection.</p><a href="https://play.leela.day/journey/">Begin a journey ↗</a><p class="print-note">Use your browser’s Print command to print or save a PDF.</p></footer></body></html>`;
await mkdir(resolve(out,'images'),{recursive:true});
await copyFile(resolve(root,'docs/diagrams/user-interface-flow.svg'),resolve(out,'images/user-interface-flow.svg'));
await copyFile(resolve(here,'style.css'),resolve(out,'style.css'));
for(const [source,path,title] of pages){await mkdir(resolve(out,path),{recursive:true});const markdown=await readFile(resolve(root,'docs',source),'utf8');await writeFile(resolve(out,path,'index.html'),shell(title,`/${path}/`,`<article>${marked.parse(markdown)}</article>`));}
await writeFile(resolve(out,'index.html'),shell('The reading room','/',`<section class="hero"><p class="eyebrow">THE TAO OF LEELA</p><h1>A question opens<br>a path.</h1><p class="lead">A contemplative game of life, consciousness and change. Begin with curiosity; return with a different question.</p><a class="play" href="https://play.leela.day/journey/">Begin a journey ↗</a></section><section class="books" aria-label="Read about Leela"><a href="/introduction/"><span class="eyebrow">01 · THE PAMPHLET</span><h2>An invitation</h2><p>The ideas behind Leela, the Book of Changes and the art of reflection.</p><span>Read the introduction →</span></a><a href="/guide/"><span class="eyebrow">02 · THE USER MANUAL</span><h2>Your first journey</h2><p>Create a Persona, cast a hexagram, reflect, and find your way back.</p><span>Open the guide →</span></a></section>`));
await writeFile(resolve(out,'404.html'),shell('Page not found','/404.html','<h1>This page is not here.</h1><p><a href="/">Return to the reading room.</a></p>'));
await writeFile(resolve(out,'_headers'),'/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n  Cache-Control: public, max-age=0, must-revalidate\n');
await writeFile(resolve(out,'robots.txt'),'User-agent: *\nAllow: /\nSitemap: https://read.leela.day/sitemap.xml\n');
await writeFile(resolve(out,'sitemap.xml'),'<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+['/','/guide/','/introduction/'].map(p=>`<url><loc>https://read.leela.day${p}</loc></url>`).join('')+'</urlset>');
console.log(`Built reading site: ${out}`);

await mkdir(resolve(out,'shared'),{recursive:true});
for(const asset of ['screen-info.js','screen-info.css'])await copyFile(resolve(root,'app/public/shared',asset),resolve(out,'shared',asset));
