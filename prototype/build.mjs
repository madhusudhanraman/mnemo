import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('./',import.meta.url);
const read=path=>readFileSync(new URL(path,root),'utf8');
let template=read('src/index.template.html');
const three=read('vendor/three.module.mjs');
const exported=three.match(/export \{([^}]+)\};\s*$/s);
if(!exported)throw new Error('Three.js export list missing');
const members=exported[1].split(',').map(member=>{const [local,name]=member.trim().split(/\s+as\s+/);return name?`${name}:${local}`:local}).join(',');
const bundledThree=`const THREE=(()=>{${three.slice(0,exported.index)}\nreturn {${members}};})();`;
const model=read('ghost.mjs').replace(/^import .*;\n/gm,'').replace('export function createGhost','function createGhost');
template=template.replace(/^import \* as THREE from [^;]+;/m,()=>bundledThree);
const spotifyCaption=read('spotify-caption.mjs').replace('export function createSpotifyCaption','function createSpotifyCaption');
const reminders=read('reminders.mjs').replace('export function startReminders','function startReminders');
const fade=read('fade-renderer.mjs').replace(/^import .*;\n/gm,'').replace('export function createFadeRenderer','function createFadeRenderer');
const sizeUtils=read('size-preview.mjs').replace(/^import .*;\n/gm,'').replace(/export function /g,'function ');
const idle=read('idle-motion.mjs').replace('export function idleOffset','function idleOffset');
const gpuCode=read('cloth-gpu.mjs').replace(/export (function|const) /g,'$1 ');
const behaviourCode=read('behaviours.mjs').replace(/export function /g,'function ');
const reminderMotion=read('reminder-motion.mjs').replace(/export function /g,'function ');
const page=template.replace('/* CLOTH_GPU */',()=>gpuCode).replace('/* COMPANION_BEHAVIOURS */',()=>behaviourCode).replace('/* REMINDER_MOTION */',()=>reminderMotion).replace('/* COMPANION_MODEL */',()=>model).replace('/* FADE_RENDERER */',()=>fade).replace('/* IDLE_MOTION */',()=>idle).replace('/* SIZE_UTILS */',()=>sizeUtils).replace('/* SPOTIFY_CAPTION */',()=>spotifyCaption).replace('/* REMINDER_MODULE */',()=>reminders).replace('/* START_REMINDERS */',()=>read('src/reminder-start.js'));

writeFileSync(new URL('index.html',root),page);
writeFileSync(new URL('ghost.html',root),page);
console.log('Built self-contained index.html (no network dependencies).');

let sizes=read('src/sizes.template.html');
const lightingStart=template.indexOf('// Broad softboxes');
const lightingEnd=template.indexOf('const companion=',lightingStart);
const lighting=template.slice(lightingStart,lightingEnd);
sizes=sizes.replace(/^import \* as THREE from [^;]+;/m,()=>bundledThree).replace('/* COMPANION_MODEL */',()=>model).replace('/* SIZE_UTILS */',()=>sizeUtils).replace('/* STUDIO_LIGHTING */',()=>lighting);
writeFileSync(new URL('sizes.html',root),sizes);

// The editor shares the visual styles and reminder logic, but loads no 3D engine.
const editorStyles=template.match(/<style>([\s\S]*?)<\/style>/)[1];
const editor=`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Reminders · Mnemo</title><style>${editorStyles}</style><body class="manager-mode"><button id="remind" hidden>Reminders</button><script type="module">${reminders}\nstartReminders({showThought(){},hideThought(){},onDesktopMode(){}});</script></body></html>`;
writeFileSync(new URL('editor.html',root),editor);
