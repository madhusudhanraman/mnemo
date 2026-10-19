// Exercise the standalone page's control/animation code with browser and GPU
// interfaces stubbed. Native reminder UI is verified separately in the app.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {idleOffset} from '../idle-motion.mjs';
const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
assert.ok(!/<script[^>]+src=|^import /m.test(html),'Standalone page must not fetch code');
assert.ok(!html.includes('id="desktop-toolbar"'),'No toolbar under Mnemo');
assert.ok(!html.includes('id="spin"')&&!html.includes('id="vanish"'),'Behaviours have no manual buttons');
assert.ok(html.includes('role="button" tabindex="0" aria-label="Mnemo'),'Ghost is keyboard-accessible');
let source=html.split('<script type="module">')[1].split('</script>')[0];
const uiStart=source.indexOf('function startReminders('),uiEnd=source.indexOf('const pet=document.querySelector',uiStart);
source=source.slice(0,uiStart)+`function startReminders(options){
 const open=()=>globalThis.openCount++;document.getElementById('remind').onclick=open;
 if(window.mnemoDesktop)options.onDesktopMode(window.mnemoDesktop.mode);return {open};
}\n`+source.slice(uiEnd);
source=source.replace('const pet=document.querySelector',`THREE.WebGLRenderer=class{capabilities={maxSamples:4};getDrawingBufferSize(v){return v.set(640,640)}setRenderTarget(){}setPixelRatio(){}setSize(){}setClearColor(){}render(){globalThis.renderCount++}};
THREE.PMREMGenerator=class{fromScene(){return {texture:new THREE.Texture()}}dispose(){}};
const pet=document.querySelector`);
source+='\nglobalThis.page={frame,model,companion,peekaboo,spin,toggleMotion,get time(){return time},get spinStart(){return spinStart},get wander(){return wander}};';
function setup(native=false){
 const elements=new Map(),moves=[],handlers=new Map();
 const el=id=>{if(!elements.has(id)){const classes=new Set();elements.set(id,{offsetWidth:native?240:460,offsetHeight:native?240:460,getBoundingClientRect(){return native?{left:40,top:160,width:240,height:240}:{left:300,top:200,width:460,height:460}},style:{},setAttribute(){},setPointerCapture(){},classList:{add:x=>classes.add(x),remove:x=>classes.delete(x),contains:x=>classes.has(x)}})}return elements.get(id)};
 const desktop=native?{mode:'companion',moveBy:delta=>moves.push(delta),hitRegions(){}}:undefined;
 globalThis.renderCount=0;globalThis.openCount=0;
 const names=['document','window','innerWidth','innerHeight','devicePixelRatio','matchMedia','addEventListener','requestAnimationFrame','setTimeout','clearTimeout'];
 const values=[{querySelector:el,getElementById:id=>el('#'+id)},{mnemoDesktop:desktop,addEventListener:(name,handler)=>handlers.set(name,handler)},native?320:1400,native?440:900,1,()=>({matches:false}),()=>{},()=>{},()=>1,()=>{}];
 new Function(...names,source)(...values);
 let now=0;
 const advance=n=>{for(let i=0;i<n;i++){now+=34;globalThis.page.frame(now)}};
 return {el,moves,advance,page:globalThis.page,setHover:value=>handlers.get('mnemo-hover')?.({detail:value}),setVisible:value=>handlers.get('mnemo-visible')?.({detail:value})};
}
const browser=setup();browser.advance(12);
assert.ok(globalThis.renderCount>0&&globalThis.renderCount<24,'Idle frame cap and opaque pass skipping reduce renders');
assert.match(browser.el('#bubble').style.left,/px$/);
assert.ok(Math.abs(parseFloat(browser.el('#bubble').style.left)-530)<10,'Thought follows the head');
const pet=browser.el('#pet');
const down=(x=900,y=400,shiftKey=false)=>({button:0,clientX:x,clientY:y,screenX:x,screenY:y,shiftKey,pointerId:1});
pet.onpointerdown(down());pet.onpointerup();pet.onclick({shiftKey:false});
assert.equal(globalThis.openCount,1,'Click opens reminders');
pet.onpointerdown(down());pet.onpointermove(down(940));pet.onpointerup();pet.onclick({shiftKey:false});
assert.equal(globalThis.openCount,1,'Drag must not open reminders');
pet.onkeydown({key:'Enter',preventDefault(){}});assert.equal(globalThis.openCount,2,'Keyboard opens reminders');
browser.page.toggleMotion();const before=browser.page.model.rotation.y;browser.advance(1);assert.equal(browser.page.model.rotation.y,before);
browser.page.toggleMotion();browser.page.spin();browser.advance(10);assert.notEqual(browser.page.model.rotation.y,before);
while(browser.page.time<11)browser.advance(1);
browser.page.peekaboo();const beforePeekSpin=browser.page.spinStart;
while(browser.page.time<17)browser.advance(1);
assert.equal(browser.page.spinStart,beforePeekSpin,'Idle spin cannot overlap disappearance');
const native=setup(true);let previous=idleOffset(0),diagonal=false;
for(let i=0;i<400;i++){
 native.advance(1);const w=native.page.wander;
 assert.ok(Math.abs(w.x)<=32&&Math.abs(w.y)<=20,'Wandering stays close to resting spot');
 if(Math.abs(w.x)>2&&Math.abs(w.y)>2)diagonal=true;
 assert.ok(Math.hypot(w.x-previous.x,w.y-previous.y)<1.25,'Drift steps stay within 12.5 points/second at a 100 ms maximum timestep');previous={...w};
}
assert.ok(diagonal,'Drifting includes diagonal movement');
const nativePet=native.el('#pet');native.setHover(true);const frozen={...native.page.wander};native.advance(30);assert.deepEqual(native.page.wander,frozen,'Hover holds still for clicking');
native.setHover(false);native.advance(1);
nativePet.onpointerdown(down());nativePet.onpointermove(down(940));nativePet.onpointerup();nativePet.onclick({shiftKey:false});
assert.equal(globalThis.openCount,0,'Native drag must not open reminders');
assert.equal(native.moves.at(-1).remember,true,'Dropping establishes new resting position');
assert.deepEqual(native.page.wander,{x:0,y:0},'New orbit starts from the drop location');
for(let t=0;t<3600;t+=.1){const w=idleOffset(t);assert.ok(Math.abs(w.x)<=32&&Math.abs(w.y)<=20)}
const beforeHidden=globalThis.renderCount;native.setVisible(false);native.advance(120);assert.equal(globalThis.renderCount,beforeHidden,'Hidden companion does not render');
native.setVisible(true);native.advance(3);assert.ok(globalThis.renderCount>beforeHidden,'Visible companion resumes');
native.page.toggleMotion();native.advance(3);const pausedRenders=globalThis.renderCount;native.advance(120);assert.equal(globalThis.renderCount,pausedRenders,'Paused unchanged companion draws no repeated frames');
console.log('PASS: click/keyboard opens reminders; drag does not; smaller native ghost; no behaviour toolbar; bounded smooth diagonal wandering; hover hold; new resting spot after drag; thought anchor; pause; spin; coordinated Peekaboo; hidden and paused rendering stops.');
