import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import * as THREE from '../vendor/three.module.mjs';
import {createGhost} from '../ghost.mjs';
import {clothVertexSource} from '../cloth-gpu.mjs';
import {whirlPoint} from '../behaviours.mjs';
// Evaluate the shader's scalar surface equations against the CPU reference.
// Native rendering separately verifies compilation on the target GPU.
let body=clothVertexSource.split('vec3 clothSurface(float theta,float v){')[1].split('\nvec3 clothNormal')[0].trim();body=body.slice(0,body.lastIndexOf('}')).replace(/\bfloat\s+(\w+)/g,'let $1').replace(/\bvec3\s+(\w+)/g,'let $1');
const evaluate=new Function('theta','v','clothTime','clothSpeed','clothFlutter','clothPhase','sin','cos','pow','sqrt','max','clamp','smoothstep','vec3',body);
const cpu=createGhost({around:96,down:64}),gpu=createGhost({around:96,down:64,gpu:true});
for(const t of [0,.3,2,8,40])for(const moving of [false,true])for(const strength of [0,.5,1])for(const v of [0,.05,.2,.322,.34,.6,.95,1])for(let i=0;i<=12;i++){
 const theta=i/12*Math.PI*2,p=cpu.surface(theta,v,t,moving),expected=whirlPoint(p.x,p.y,p.z,v,theta,strength,t);
 const actual=evaluate(theta,v,t,moving?1.6:1,strength,t,Math.sin,Math.cos,Math.pow,Math.sqrt,Math.max,THREE.MathUtils.clamp,(a,b,x)=>THREE.MathUtils.smoothstep(x,a,b),(x,y,z)=>({x,y,z}));
 for(const axis of ['x','y','z'])assert.ok(Math.abs(expected[axis]-actual[axis])<1e-10,`Surface mismatch: ${axis}`);
}
const shader={uniforms:{},vertexShader:THREE.ShaderLib.physical.vertexShader};gpu.sheet.material.onBeforeCompile(shader);
assert.ok(shader.vertexShader.includes('vec3 objectNormal=clothNormal('));assert.ok(shader.vertexShader.includes('vec3 transformed=clothSurface('));
assert.ok(!shader.vertexShader.includes('#include <begin_vertex>'));
const positionVersion=gpu.geometry.attributes.position.version,normalVersion=gpu.geometry.attributes.normal.version;
for(let i=0;i<120;i++){gpu.setFlutter(.5,i/30);gpu.update(i/30);}
assert.equal(gpu.geometry.attributes.position.version,positionVersion,'GPU mode never uploads animated positions');assert.equal(gpu.geometry.attributes.normal.version,normalVersion,'GPU mode never recalculates normal buffers');
assert.equal(shader.uniforms.clothTime.value,119/30);
for(const ghost of [cpu,gpu]){const start=performance.now();for(let i=0;i<300;i++)ghost.update(10+i/20);console.log(`${ghost.gpu?'GPU uniform/eye':'CPU cloth'} update: ${((performance.now()-start)/300).toFixed(3)} ms (Node CPU only)`)}
console.log('PASS: shader surface matches CPU reference; normal/position hooks, uniform changes, and static GPU buffers verified.');
