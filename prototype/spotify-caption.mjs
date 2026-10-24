import {placeTile} from './tile-placement.mjs';
// Hover UI is independent of the 3D renderer; no extra animation loop.
export function createSpotifyCaption({desktop,pet,bubble,isReminder,onRegions,onHover=()=>{}}){
 const caption=document.createElement('div');caption.id='spotify-caption';caption.setAttribute('aria-label','Now playing on Spotify');
 const track=document.createElement('div');track.className='spotify-track';
 const title=document.createElement('div');title.className='spotify-title';
 const artist=document.createElement('div');artist.className='spotify-artist';
 const controls=document.createElement('div');controls.className='spotify-controls';
 function drawControl(button,kind){
  const shapes={
   previous:'<rect x="2" y="3" width="2" height="10" rx=".5"/><path d="M13 3 5 8l8 5Z"/>',
   next:'<path d="m3 3 8 5-8 5Z"/><rect x="12" y="3" width="2" height="10" rx=".5"/>',
   play:'<path d="m4 3 9 5-9 5Z"/>',
   pause:'<rect x="3" y="3" width="3" height="10" rx=".5"/><rect x="10" y="3" width="3" height="10" rx=".5"/>'
  };
  button.innerHTML=`<svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true" focusable="false" style="vertical-align:middle">${shapes[kind]}</svg>`;
 }
 const buttons=[];
 for(const [command,label,icon] of [['previous','Previous Spotify track','⏮'],['toggle','Pause Spotify','⏸'],['next','Next Spotify track','⏭']]){
  const button=document.createElement('button');button.type='button';button.textContent=icon;button.title=label;button.setAttribute('aria-label',label);
  drawControl(button,command==='toggle'?'pause':command);
  button.onclick=async()=>{buttons.forEach(b=>b.disabled=true);try{await desktop?.spotifyControl?.(command);button.title=command==='toggle'?(state.playing?'Pause Spotify':'Play Spotify'):label}catch(error){button.title=error.message}finally{buttons.forEach(b=>b.disabled=false)}};
  buttons.push(button);controls.append(button);
 }
 const like=document.createElement('button');like.type='button';like.setAttribute('aria-label','Save Spotify song');
 const feedback=document.createElement('div');feedback.className='spotify-feedback';feedback.setAttribute('role','status');feedback.hidden=true;
 let liking=false;
 function renderLike(){
  const saved=state.liked===true;like.disabled=liking||!state.canLike;like.setAttribute('aria-pressed',String(saved));
  like.title=!state.canLike?'This item cannot be saved':!state.libraryConnected?'Connect Spotify to save songs':saved?'Remove from Liked Songs':'Add to Liked Songs';like.setAttribute('aria-label',like.title);
  like.innerHTML=`<svg width="16" height="16" viewBox="0 0 24 24" fill="${saved?'currentColor':'none'}" stroke="currentColor" stroke-width="1.8" aria-hidden="true" style="vertical-align:middle"><path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/></svg>`;
 }
 like.onclick=async()=>{if(liking||!state.canLike)return;liking=true;renderLike();feedback.hidden=true;try{const result=await desktop?.spotifyLike?.(state.uri);if(result?.needsConnection){feedback.textContent='Connect Spotify in Settings.';feedback.hidden=false}}catch(error){feedback.textContent=error.message;feedback.hidden=false}finally{liking=false;renderLike()}};
 controls.append(like);
 track.append(title,artist);caption.append(track,controls,feedback);document.body.append(caption);
 let state={playing:false},over=false,showTimer,hideTimer,visible=false;
 function setVisible(value){visible=value;caption.classList.toggle('show',value);caption.inert=!value;onRegions()}
 function eligible(){return (state.available||state.playing)&&!isReminder()&&!bubble.classList.contains('show')}
 function updateHover(value){
  over=value;clearTimeout(showTimer);clearTimeout(hideTimer);
  if(value&&eligible()){showTimer=setTimeout(()=>{if(over&&eligible())setVisible(true)},state.playing?300:1000)}
  else hideTimer=setTimeout(()=>{if(!over)setVisible(false)},500);
 }
 caption.inert=true;
 caption.addEventListener('pointerenter',()=>{updateHover(true);onHover(true)});
 caption.addEventListener('pointerleave',()=>{updateHover(false);onHover(false)});
 caption.addEventListener('focusin',()=>updateHover(true));
 caption.addEventListener('focusout',event=>{if(!caption.contains(event.relatedTarget))updateHover(false)});
 if(!desktop){pet.addEventListener('pointerenter',()=>updateHover(true));pet.addEventListener('pointerleave',()=>updateHover(false))}
 window.addEventListener('mnemo-spotify',event=>{
  state=event.detail||{playing:false};title.textContent=String(state.title||'');artist.textContent=String(state.artist||'');
  drawControl(buttons[1],state.playing?'pause':'play');buttons[1].title=state.playing?'Pause Spotify':'Play Spotify';buttons[1].setAttribute('aria-label',buttons[1].title);
  track.title=[state.title,state.artist].filter(Boolean).join(' — ');renderLike();
  if(!eligible())setVisible(false);else if(over&&!visible)updateHover(true);
 });
 function sync(){if(!eligible()){clearTimeout(showTimer);setVisible(false)}}
 function position(rect){
  const maxWidth=Math.min(220,innerWidth-16);caption.style.maxWidth=`${maxWidth}px`;
  const width=Math.min(caption.offsetWidth||maxWidth,maxWidth);
  const bounds=window.mnemoUsableBounds||{left:0,top:0,right:innerWidth,bottom:innerHeight};
  const p=placeTile({...rect,top:rect.top??rect.bottom-150},width,caption.offsetHeight,bounds);
  caption.style.left=`${p.left}px`;caption.style.top=`${p.top}px`;

 }
 return {element:caption,updateHover,sync,position,get interactive(){return visible}};
}
