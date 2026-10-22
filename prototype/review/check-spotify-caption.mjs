import assert from 'node:assert/strict';
import {createSpotifyCaption} from '../spotify-caption.mjs';
class Element {
 constructor(){this.events={};this.children=[];this.style={};this.offsetHeight=48;this.classes=new Set();this.classList={contains:x=>this.classes.has(x),toggle:(x,on)=>on?this.classes.add(x):this.classes.delete(x)}}
 setAttribute(){} append(...items){this.children.push(...items)} addEventListener(name,fn){this.events[name]=fn} contains(x){return this.children.includes(x)}
}
let now=0,id=0;const timers=new Map(),events={};
globalThis.setTimeout=(fn,delay)=>{timers.set(++id,{fn,at:now+delay});return id};globalThis.clearTimeout=id=>timers.delete(id);
function advance(ms){now+=ms;for(const [id,t] of [...timers])if(t.at<=now){timers.delete(id);t.fn()}}
globalThis.innerWidth=320;globalThis.innerHeight=440;
globalThis.document={createElement:()=>new Element(),body:new Element()};globalThis.window={addEventListener:(name,fn)=>events[name]=fn};
let reminder=false,commands=[],reports=0;const bubble=new Element(),pet=new Element();
const ui=createSpotifyCaption({desktop:{spotifyControl:async command=>commands.push(command)},pet,bubble,isReminder:()=>reminder,onRegions:()=>reports++});
const caption=ui.element,[track,controls]=caption.children;
const [previous,toggle,next]=controls.children;
events['mnemo-spotify']({detail:{playing:true,title:'<unsafe track>',artist:'Artist'}});
assert.equal(track.children[0].textContent,'<unsafe track>','Track is text, never HTML');
assert.equal(ui.interactive,false,'Hidden without hover');
ui.updateHover(true);advance(299);assert.equal(ui.interactive,false);advance(1);assert.equal(ui.interactive,true);
ui.updateHover(false);advance(250);caption.events.pointerenter();advance(500);assert.equal(ui.interactive,true,'Moving onto controls retains caption');
await previous.onclick();await toggle.onclick();await next.onclick();assert.deepEqual(commands,['previous','toggle','next']);
events['mnemo-spotify']({detail:{available:true,playing:false,title:'Paused track',artist:'Artist'}});assert.equal(ui.interactive,true,'Paused track stays available for resume');assert.ok(toggle.innerHTML.includes('m4 3 9 5-9 5Z'));
await toggle.onclick();assert.equal(commands.at(-1),'toggle');
events['mnemo-spotify']({detail:{available:true,playing:true,title:'Playing track'}});assert.ok(toggle.innerHTML.includes('x="10"'));
caption.events.pointerleave();advance(500);assert.equal(ui.interactive,false);
ui.updateHover(true);reminder=true;ui.sync();advance(300);assert.equal(ui.interactive,false,'Reminder cancels a pending reveal');
reminder=false;ui.updateHover(true);advance(300);assert.equal(ui.interactive,true);
events['mnemo-spotify']({detail:{playing:false}});assert.equal(ui.interactive,false,'Stopped playback hides caption');
ui.position({left:280,width:100,bottom:430});assert.equal(caption.style.left,'52px');assert.equal(caption.style.top,'331px');
assert.ok(reports>0,'Visibility updates native hit regions');
console.log('PASS: Spotify hover delay, safe text, control handoff, Previous/Play/Pause/Next, reminder priority, pause and viewport bounds');
