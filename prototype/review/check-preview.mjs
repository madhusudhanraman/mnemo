// Exercise the standalone page's control/animation code with browser and GPU
// interfaces stubbed. Native reminder UI is verified separately in the app.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {idleOffset} from '../idle-motion.mjs';
const html=readFileSync(new URL('../appearance-preview.html',import.meta.url),'utf8');
assert.ok(!/<script[^>]+src=|^import /m.test(html),'Standalone page must not fetch code');
assert.ok(!html.includes('id="desktop-toolbar"'),'No toolbar under Mnemo');
assert.ok(!html.includes('id="spin"')&&!html.includes('id="vanish"'),'Behaviours have no manual buttons');
assert.ok(html.includes('role="button" tabindex="0" aria-label="Mnemo'),'Ghost is keyboard-accessible');
let source=html.split('<script type="module">')[1].split('</script>')[0];
source=source.replace('const pet=document.querySelector',`THREE.WebGLRenderer=class{capabilities={maxSamples:4};getDrawingBufferSize(v){return v.set(640,640)}setRenderTarget(){}setPixelRatio(){}setSize(){}setClearColor(){}render(){globalThis.renderCount++}};
THREE.PMREMGenerator=class{fromScene(){return {texture:new THREE.Texture()}}dispose(){}};
const pet=document.querySelector`);
source+='\nglobalThis.page={frame,model,companion,behaviours,peekaboo,spin,toggleMotion,get time(){return time},get spinStart(){return spinStart},get wander(){return wander}};';
function setup(native=false){
 const elements=new Map(),moves=[],handlers=new Map();
 const el=id=>{if(!elements.has(id)){const classes=new Set();elements.set(id,{offsetWidth:native?240:460,offsetHeight:native?240:460,getBoundingClientRect(){return native?{left:40,top:160,width:240,height:240}:{left:300,top:200,width:460,height:460}},value:'',hidden:false,children:[],append(...children){this.children.push(...children)},replaceChildren(){this.children=[]},reset(){},focus(){},style:{},setAttribute(){},setPointerCapture(){},classList:{add:x=>classes.add(x),remove:x=>classes.delete(x),contains:x=>classes.has(x)}})}return elements.get(id)};
 const desktop=native?{mode:'companion',list:async()=>[],moveBy:delta=>moves.push(delta),hitRegions(){}}:undefined;
 globalThis.renderCount=0;globalThis.openCount=0;
 const names=['document','window','innerWidth','innerHeight','devicePixelRatio','matchMedia','addEventListener','requestAnimationFrame','setTimeout','clearTimeout'];
 const values=[{createElement:()=>el('created'+Math.random()),body:{dataset:{},append(){},classList:{add(){},remove(){}}},querySelector:el,getElementById:id=>el('#'+id)},{mnemoDesktop:desktop,addEventListener:(name,handler)=>handlers.set(name,handler)},native?320:1400,native?440:900,1,()=>({matches:false}),()=>{},()=>{},()=>1,()=>{}];
 new Function(...names,source)(...values);
 let now=0;
 const advance=n=>{for(let i=0;i<n;i++){now+=34;globalThis.page.frame(now)}};
 return {el,moves,advance,page:globalThis.page,setHover:value=>handlers.get('mnemo-hover')?.({detail:value})};
}
const preview=setup(true);
function checkTransform(){
 for(const value of [...preview.page.model.position.toArray(),preview.page.model.rotation.x,preview.page.model.rotation.y,preview.page.model.rotation.z])assert.ok(Number.isFinite(value),'Visible model must have a finite transform');
}
preview.advance(3);checkTransform();
preview.page.behaviours.sleep();preview.advance(180);checkTransform();
preview.page.behaviours.wake();preview.advance(180);checkTransform();
preview.page.behaviours.flutter();preview.advance(45);checkTransform();
preview.advance(120);checkTransform();
preview.page.behaviours.curious();preview.advance(45);checkTransform();preview.advance(120);checkTransform();
console.log('PASS: preview renders with finite transforms before flutter, while sleepy, awake, fluttering, curious, swirling and settled.');
