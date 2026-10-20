// Hover UI is independent of the 3D renderer; no extra animation loop.
export function createSpotifyCaption({desktop,pet,bubble,isReminder,onRegions,onHover=()=>{}}){
 const caption=document.createElement('div');caption.id='spotify-caption';caption.setAttribute('aria-label','Now playing on Spotify');
 const track=document.createElement('div');track.className='spotify-track';
 const title=document.createElement('div');title.className='spotify-title';
 const artist=document.createElement('div');artist.className='spotify-artist';
 const skip=document.createElement('button');skip.type='button';skip.textContent='Skip';skip.setAttribute('aria-label','Skip Spotify track');
 track.append(title,artist);caption.append(track,skip);document.body.append(caption);
 let state={playing:false},over=false,showTimer,hideTimer,visible=false;
 function setVisible(value){visible=value;caption.classList.toggle('show',value);caption.inert=!value;onRegions()}
 function eligible(){return state.playing&&!isReminder()&&!bubble.classList.contains('show')}
 function updateHover(value){
  over=value;clearTimeout(showTimer);clearTimeout(hideTimer);
  if(value&&eligible()){showTimer=setTimeout(()=>{if(over&&eligible())setVisible(true)},300)}
  else hideTimer=setTimeout(()=>{if(!over)setVisible(false)},500);
 }
 caption.inert=true;
 caption.addEventListener('pointerenter',()=>{updateHover(true);onHover(true)});
 caption.addEventListener('pointerleave',()=>{updateHover(false);onHover(false)});
 caption.addEventListener('focusin',()=>updateHover(true));
 caption.addEventListener('focusout',event=>{if(!caption.contains(event.relatedTarget))updateHover(false)});
 if(!desktop){pet.addEventListener('pointerenter',()=>updateHover(true));pet.addEventListener('pointerleave',()=>updateHover(false))}
 skip.onclick=async()=>{skip.disabled=true;skip.textContent='…';try{await desktop?.spotifySkip?.();skip.title=''}catch(error){skip.title=error.message}finally{skip.disabled=false;skip.textContent='Skip'}};
 window.addEventListener('mnemo-spotify',event=>{
  state=event.detail||{playing:false};title.textContent=String(state.title||'');artist.textContent=String(state.artist||'');
  track.title=[state.title,state.artist].filter(Boolean).join(' — ');
  if(!eligible())setVisible(false);else if(over&&!visible)updateHover(true);
 });
 function sync(){if(!eligible()){clearTimeout(showTimer);setVisible(false)}}
 function position(rect){
  const maxWidth=Math.min(220,innerWidth-16);caption.style.maxWidth=`${maxWidth}px`;
  const width=Math.min(caption.offsetWidth||maxWidth,maxWidth);
  caption.style.left=`${Math.max(8,Math.min(innerWidth-width-8,rect.left+rect.width/2-width/2))}px`;
  caption.style.top=`${Math.max(8,Math.min(innerHeight-caption.offsetHeight-8,rect.bottom+7))}px`;
 }
 return {element:caption,updateHover,sync,position,get interactive(){return visible}};
}
