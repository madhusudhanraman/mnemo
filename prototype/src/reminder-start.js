let announcementTimer;
function hideThought(){announcementReveal=null;clearTimeout(announcementTimer);announcementStart=-100;activeThoughtPersistent=false;spotifyCaption?.sync();clearTimeout(bubbleTimer);bubble.classList.remove('show');invalidateRender()}
function showThought(text,{persistent=false,meta='',actions=[],onShown=()=>{},entrance='full'}={}){
 queueGlowOnly=persistent&&entrance!=='full';queueFlutterAllowed=entrance==='done';
 if(queueFlutterAllowed)behaviours.flutter();
 if(persistent)wakeCompanion();
 activeThoughtPersistent=persistent;spotifyCaption?.sync();companion.setVanished(false);peekabooReturn=Infinity;nextPeekaboo=time+180+Math.random()*120;
 clearTimeout(announcementTimer);clearTimeout(bubbleTimer);bubble.classList.remove('show');bubble.replaceChildren();
 if(meta){const label=document.createElement('span');label.className='thought-meta';label.textContent=meta;bubble.append(label)}
 const content=document.createElement('div');content.className='thought-content';content.textContent=text;bubble.append(content);
 if(actions.length){const row=document.createElement('div');row.className='thought-actions';for(const action of actions){const button=document.createElement('button');button.type='button';button.textContent=action.label;button.onclick=action.run;row.append(button)}bubble.append(row)}
 const reveal=()=>{spinStart=-100;bubble.classList.add('show');spotifyCaption.sync();onShown();if(!persistent)bubbleTimer=setTimeout(hideThought,5000)};
 if(persistent&&!paused&&!reduced){
  companion.setVanished(false,true);announcementStart=time;announcementBaseYaw=model.rotation.y;spinStart=-100;
  nextAdventure=Math.max(nextAdventure,time+90);
  announcementReveal=reveal;
 }else reveal();
 invalidateRender();
}
let lastHitReport=0,lastRegionsJSON='';
const spotifyCaption=createSpotifyCaption({desktop,pet,bubble,isReminder:()=>activeThoughtPersistent,onRegions:()=>{lastHitReport=0;reportHitRegions(performance.now());invalidateRender()},onHover:value=>{hovering=value;if(value)wakeCompanion()}});
function reportHitRegions(now){
 if(!desktop||desktop.mode!=='companion'||now-lastHitReport<200)return;lastHitReport=now;
 const r=canvas.getBoundingClientRect();
 const crown=r.top+(-headAnchor.y*.5+.5)*r.height;
 const regions=[{x:r.left+r.width*.24,y:crown,width:r.width*.52,height:Math.max(1,r.top+r.height*.86-crown)}];
 for(const element of [bubble,spotifyCaption.element]){
  if(element===bubble&&!bubble.classList.contains('show'))continue;
  if(element===spotifyCaption.element&&!spotifyCaption.interactive)continue;
  const b=element.getBoundingClientRect();regions.push({x:b.left-4,y:b.top-4,width:b.width+8,height:b.height+8});
 }
 const rounded=regions.map(r=>{const x=Math.floor(r.x/4)*4,y=Math.floor(r.y/4)*4;return {x,y,width:Math.ceil((r.x+r.width-x)/4)*4,height:Math.ceil((r.y+r.height-y)/4)*4}});
 const json=JSON.stringify(rounded);if(json===lastRegionsJSON)return;lastRegionsJSON=json;
 desktop.hitRegions(rounded);
}
function wakeCompanion(){lastInteraction=time;behaviours.wake();invalidateRender()}
window.addEventListener('mnemo-system-activity',event=>{systemActive=Boolean(event.detail);if(systemActive)wakeCompanion();else invalidateRender()});
function celebrateDone(){wakeCompanion();behaviours.flutter()}
const reminderUI=startReminders({showThought,hideThought,onDone:celebrateDone,onDesktopMode(mode){
 position={x:(innerWidth-pet.offsetWidth)/2,y:desktop.mode==='companion'?300:160};target={...position};
 if(mode==='manager')paused=true;
}});
window.addEventListener('mnemo-open-reminders',reminderUI.open);
window.addEventListener('mnemo-pause',toggleMotion);

if(desktop)window.addEventListener('mnemo-hover',event=>{hovering=Boolean(event.detail);spotifyCaption.updateHover(hovering);if(hovering){wakeCompanion();if(!activeThoughtPersistent)behaviours.curious()}});
window.addEventListener('pointerdown',wakeCompanion);


const neutralSize=clothScreenBounds(companion,camera,1);
function applyCompanionSize(height){
 if(!desktop||desktop.mode!=='companion'||!Number.isInteger(height)||height<60||height>180)return;
 const canvasSize=height/neutralSize.height;
 pet.style.width=`${canvasSize}px`;pet.style.height=`${canvasSize}px`;
 renderer.setSize(Math.ceil(canvasSize),Math.ceil(canvasSize),false);fadeRenderer.resize();
 position={x:(innerWidth-canvasSize)/2,y:510-neutralSize.bottom*canvasSize};target={...position};
}
if(desktop?.preferredHeight)applyCompanionSize(desktop.preferredHeight);
window.addEventListener('mnemo-size',event=>{applyCompanionSize(Number(event.detail));invalidateRender()});

const positionMusic=()=>{const r=canvas.getBoundingClientRect();spotifyCaption.position({left:r.left+r.width*.24,top:r.top+r.height*.20,bottom:r.top+r.height*.86,width:r.width*.52})};
const originalPositionBubble=positionBubble;positionBubble=()=>{originalPositionBubble();positionMusic()};

window.addEventListener('mnemo-bounds',()=>{positionBubble();lastHitReport=0;reportHitRegions(performance.now());invalidateRender()});
