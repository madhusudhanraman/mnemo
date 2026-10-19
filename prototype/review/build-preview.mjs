import {readFileSync,writeFileSync} from 'node:fs';
const root=new URL('../',import.meta.url);
let page=readFileSync(new URL('ghost.html',root),'utf8');
const bridge=`<script>addEventListener('error',event=>{const status=document.getElementById('preview-status');if(status)status.textContent='Preview error: '+event.message});addEventListener('unhandledrejection',event=>{const status=document.getElementById('preview-status');if(status)status.textContent='Preview error: '+(event.reason?.message||event.reason)});window.mnemoPreviewRows=[];window.mnemoDesktop={mode:'companion',preferredHeight:140,list:async()=>window.mnemoPreviewRows.map(row=>({...row})),action:async({id,action})=>{const row=window.mnemoPreviewRows.find(row=>row.id===id);if(!row)throw new Error('Preview reminder missing');if(action==='done')row.status='done';else if(action==='snooze'){row.status='pending';row.dueAt=Date.now()+10800000}else throw new Error('Unknown preview action');return window.mnemoPreviewRows.map(row=>({...row}))},hitRegions(){},moveBy(){},manage(){},closeManager(){}};</script>`;
page=page.replace('<script type="module">',bridge+'<script type="module">');
const controls=`<aside id="preview-controls"><div class="preview-title">Mnemo · appearance preview</div><div class="preview-buttons"><button id="preview-idle">Linger</button><button id="preview-reminder">Show Reminder</button><button id="preview-multiple">Multiple Reminders</button><button id="preview-sleep">Sleepy Drift</button><button id="preview-flutter">Whirl Flutter</button><button id="preview-curious">Curious Tilt</button><button id="preview-peek">Peekaboo</button></div><div class="preview-options"><label>Background <select id="preview-background"><option value="dark">Dark</option><option value="light">Light</option><option value="mixed">Mixed</option></select></label><label>Height <input id="preview-size" type="range" min="60" max="180" value="140"><output id="preview-height">140 pt</output></label></div><p id="preview-status" role="status">Lingering · no reminders are saved</p></aside>`;
page=page.replace('<main>',controls+'<main>');
page=page.replace('</style>',`#preview-controls{position:fixed;left:20px;right:20px;bottom:18px;z-index:30;max-width:650px;margin:auto;background:#242131;color:#eee7fa;padding:16px 20px;border:1px solid #494054;border-radius:18px;font-size:13px}.preview-title{font-weight:500}.preview-buttons{display:flex;flex-wrap:wrap;margin-top:8px}#preview-controls button{padding:7px 12px;font-size:12px}.preview-options{display:flex;gap:20px;flex-wrap:wrap}.preview-options label{display:flex;align-items:center;gap:10px;margin:6px 0;font-size:12px}.preview-options select{width:auto;padding:5px 8px;font-size:12px}.preview-options input{width:110px;padding:0}.preview-options output{min-width:44px}#preview-status{font-size:12px;margin:8px 0 0;color:#b9adca}body.desktop-mode{background:#171723}body[data-preview-background=light]{background:#fbfafc}body[data-preview-background=mixed]{background:linear-gradient(135deg,#faf9fb 0%,#faf9fb 48%,#242131 49%,#242131 100%)}#reminder-panel{display:none!important}#pet{cursor:default}#pet:focus-visible{filter:none}@media(max-height:580px){#preview-controls{padding:10px 14px;bottom:8px}.preview-options{gap:8px}.preview-title{display:none}}
</style>`);
const demo=`
// Preview uses the actual production mesh, motion and thought-bubble code.
const previewStatus=document.getElementById('preview-status');
function placePreview(){const side=pet.offsetWidth,controls=document.getElementById('preview-controls').getBoundingClientRect(),stageBottom=Math.max(160,controls.top-16),sheetHeight=neutralSize.height*side,crown=Math.max(12,(stageBottom-sheetHeight)/2);position={x:(innerWidth-side)/2,y:crown-neutralSize.top*side};target={...position};idleClock=0;wander={x:0,y:0}}
hideThought();placePreview();pet.onclick=null;pet.onpointerdown=null;pet.onpointermove=null;pet.onpointerup=null;
function previewWake(){lastInteraction=time;behaviours.wake()}
function previewFlutter(){hideThought();previewWake();behaviours.flutter();previewStatus.textContent='Whirl flutter · a spiral ripple through the sheet'}
function previewIdle(){window.mnemoPreviewRows=[];reminderUI.refresh();previewWake();hideThought();companion.setVanished(false,true);spinStart=-100;nextAdventure=time+8;nextPeekaboo=Infinity;previewStatus.textContent='Lingering · no reminders are saved'}
document.getElementById('preview-idle').onclick=previewIdle;
async function previewMultiple(){
 window.previewQueueStep=0;window.previewPendingAction=null;
 hideThought();previewWake();window.mnemoPreviewRows=[];await reminderUI.refresh();
 const now=Date.now();window.mnemoPreviewRows=[
  {id:'demo-books',text:'Renew my library books.',dueAt:now-3000,status:'due',createdAt:now-86400000},
  {id:'demo-plants',text:'Water the plants.',dueAt:now-2000,status:'due',createdAt:now-86400000},
  {id:'demo-call',text:'Call the repair shop.',dueAt:now-1000,status:'due',createdAt:now-86400000}
 ];
 previewStatus.textContent='3 sample reminders · Done or Remind Me Later advances the queue';
 await reminderUI.refresh();
}
document.getElementById('preview-multiple').onclick=previewMultiple;

document.getElementById('preview-reminder').onclick=()=>{window.previewQueueStep=0;previewWake();hideThought();previewStatus.textContent='Glow → faster pirouette → thought bubble';showThought('Renew my library books.',{persistent:true,onShown:()=>{previewStatus.textContent='Reminder · waiting for Done or Remind Me Later'},actions:[{label:'Done',run:previewFlutter},{label:'Remind Me Later',run:()=>{hideThought();previewStatus.textContent='Would return in 3 hours · preview only'}}]})};
document.getElementById('preview-sleep').onclick=()=>{hideThought();lastInteraction=time;behaviours.sleep();nextAdventure=time+120;nextPeekaboo=time+120;previewStatus.textContent='Sleepy drift · drooping eyes and slower fabric movement'};
document.getElementById('preview-flutter').onclick=previewFlutter;
document.getElementById('preview-curious').onclick=()=>{hideThought();previewWake();companion.setVanished(false,true);behaviours.curious();nextAdventure=time+8;nextPeekaboo=Infinity;previewStatus.textContent='Curious tilt · a small lean, then softly back to centre'};

document.getElementById('preview-peek').onclick=()=>{hideThought();peekaboo();previewStatus.textContent='Peekaboo · eyes remain while the sheet fades'};
document.getElementById('preview-background').onchange=e=>{document.body.dataset.previewBackground=e.target.value;window.dispatchEvent(new CustomEvent('mnemo-colour',{detail:e.target.value==='light'}))};
document.getElementById('preview-size').oninput=e=>{applyCompanionSize(Number(e.target.value));document.getElementById('preview-height').textContent=e.target.value+' pt';placePreview()};
addEventListener('resize',placePreview);
addEventListener('pointerdown',event=>{if(!event.target.closest('#preview-sleep'))previewWake()});
previewIdle();frame(0);
`;
page=page.replace('</script>', '</script>');
const end=page.lastIndexOf('</script>');page=page.slice(0,end)+demo+page.slice(end);
writeFileSync(new URL('appearance-preview.html',root),page);
writeFileSync(new URL('multiple-reminders-preview.html',root),page.replace('previewIdle();frame(0);','previewMultiple();frame(0);'));
console.log('Built appearance and multiple-reminder previews.');
