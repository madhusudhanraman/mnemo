import * as THREE from './vendor/three.module.mjs';
import {installClothGPU} from './cloth-gpu.mjs';

export function createGhost({around=128,down=80,gpu=false}={}){
 const group=new THREE.Group();
 const geometry=new THREE.BufferGeometry();
 const positions=new Float32Array((around+1)*(down+1)*3);
 const colors=new Float32Array(positions.length);
 const parameters=new Float32Array((around+1)*(down+1)*2);
 for(let row=0;row<=down;row++)for(let col=0;col<=around;col++){const i=(row*(around+1)+col)*2;parameters[i]=col/around*Math.PI*2;parameters[i+1]=row/down}
 geometry.setAttribute('clothParam',new THREE.BufferAttribute(parameters,2));
 geometry.setAttribute('position',new THREE.BufferAttribute(positions,3).setUsage(THREE.DynamicDrawUsage));
 geometry.setAttribute('color',new THREE.BufferAttribute(colors,3));
 const indices=[];
 for(let row=0;row<down;row++)for(let col=0;col<around;col++){
  const a=row*(around+1)+col,b=a+around+1;
  if(row>0)indices.push(a,b,a+1);
  indices.push(b,b+1,a+1);
 }
 geometry.setIndex(indices);
 const material=new THREE.MeshPhysicalMaterial({
  color:0xffffff,vertexColors:true,roughness:.87,metalness:0,
  sheen:.65,sheenColor:new THREE.Color(0xf6efff),sheenRoughness:.9,
  side:THREE.DoubleSide,envMapIntensity:.32,transparent:false,depthWrite:true
 });
 const gpuUniforms=gpu?installClothGPU(material):null;
 const sheet=new THREE.Mesh(geometry,material);sheet.frustumCulled=false;group.add(sheet);
 const cream=new THREE.Color(0xfffcf4),lavender=new THREE.Color(0xe5e1f2),rose=new THREE.Color(0xf0c7d4);
 for(let row=0;row<=down;row++)for(let col=0;col<=around;col++){
  const v=row/down,theta=col/around*Math.PI*2;
  const color=cream.clone().lerp(lavender,THREE.MathUtils.smoothstep(v,.25,1)*.65);
  const front=Math.atan2(Math.sin(theta),Math.cos(theta));
  const blush=Math.exp(-(((Math.abs(front)-.55)/.16)**2+((v-.385)/.032)**2))*.38;
  color.lerp(rose,blush);color.toArray(colors,(row*(around+1)+col)*3);
 }

 // A rounded crown continues into a loose, flared, open-bottom sheet.
 // Motion is small at the crown and grows toward the free hem.
 function surface(theta,v,t,moving=false){
  const y=1.60-3.10*v;
  const dome=v<.34?Math.sqrt(Math.max(0,1-((y-.546)/1.054)**2)):1;
  const flare=THREE.MathUtils.smoothstep(v,.34,1);
  const radius=1.04*dome+.26*flare;
  const drape=THREE.MathUtils.smoothstep(v,.20,1),free=v*v;
  const speed=moving?1.6:1;
  // Persistent soft folds, with two travelling waves of unequal frequency.
  const folds=(Math.cos(theta*7+.3*Math.sin(theta*2))*.065
    +Math.sin(theta*11-v*5+t*1.35*speed)*.031)*drape;
  const ripple=(Math.sin(theta*4+v*6-t*1.55*speed)*.042
    +Math.cos(theta*3-v*3+t*.83)*.027)*free;
  const r=radius+folds+ripple;
  const swayX=Math.sin(t*.95-v*2.8)*.19*Math.pow(v,1.8);
  const swayZ=Math.cos(t*.71-v*2.1)*.10*v*v;
  const hem=(Math.sin(theta*6+t*.70)*.11+Math.sin(theta*3-t*1.15)*.075)*Math.pow(v,7);
  const breath=Math.sin(t*.85)*.009*dome;
  return new THREE.Vector3(
   Math.sin(theta)*(r+breath)+swayX,
   y+hem+Math.sin(theta*2+t*.9)*.025*free,
   Math.cos(theta)*(r+breath)*.82+swayZ
  );
 }

 const eyeMaterial=new THREE.MeshPhysicalMaterial({color:0x29243b,roughness:.36,clearcoat:.18,envMapIntensity:.35});
 const darkEyeColour=new THREE.Color(0x29243b),lightEyeColour=new THREE.Color(0xfffcf6);
 let eyeContrast=0,eyeContrastTarget=0;
 const highlightMaterial=new THREE.MeshBasicMaterial({color:0xfffcf6,transparent:true,opacity:1,depthWrite:false});
 const eyeGeometry=new THREE.SphereGeometry(1,40,28),eyes=[];
 for(const theta of [-.31,.31]){
  const socket=new THREE.Group();group.add(socket);
  const eye=new THREE.Mesh(eyeGeometry,eyeMaterial);eye.scale.set(.135,.215,.025);socket.add(eye);
  const highlight=new THREE.Mesh(eyeGeometry,highlightMaterial);
  highlight.position.set(-.035,.067,.024);highlight.scale.set(.026,.039,.006);socket.add(highlight);
  eyes.push({socket,highlight,theta,v:.322});
 }
 const tangent=new THREE.Vector3(),vertical=new THREE.Vector3(),normal=new THREE.Vector3();
 let lastTime=NaN,lastMoving=false,vanishTarget=1,clothVisibility=1;
 function setVanished(value,immediate=false){vanishTarget=value?0:1;if(immediate){clothVisibility=vanishTarget;sheet.visible=vanishTarget>0}}
 function updateEyes(){
  eyeMaterial.color.lerpColors(darkEyeColour,lightEyeColour,eyeContrast);
  highlightMaterial.opacity=1-eyeContrast;
  for(const {highlight} of eyes)highlight.visible=eyeContrast<.999;
 }
 function setEyeContrast(){eyeContrastTarget=0;eyeContrast=0;updateEyes()}

 function update(t,moving=false){
  const delta=Number.isFinite(lastTime)?Math.max(0,Math.min(.1,t-lastTime)):0;
  eyeContrast=THREE.MathUtils.damp(eyeContrast,eyeContrastTarget,7,delta);updateEyes();
  if(t===lastTime&&moving===lastMoving)return;
  clothVisibility=THREE.MathUtils.damp(clothVisibility,vanishTarget,3.8,delta);
  if(Math.abs(clothVisibility-vanishTarget)<.0001)clothVisibility=vanishTarget;
  sheet.visible=clothVisibility>0;
  if(!gpu||!Number.isFinite(lastTime)){
  for(let row=0;row<=down;row++)for(let col=0;col<=around;col++){
   const p=surface(col/around*Math.PI*2,row/down,t,moving);
   geometry.attributes.position.setXYZ(row*(around+1)+col,p.x,p.y,p.z);
  }
  geometry.attributes.position.needsUpdate=true;
  geometry.computeVertexNormals();
  // Match normals across the circular seam and close the crown smoothly.
  const normals=geometry.attributes.normal;
  for(let row=1;row<=down;row++){
   const first=row*(around+1),last=first+around;
   normal.fromBufferAttribute(normals,first).add(new THREE.Vector3().fromBufferAttribute(normals,last)).normalize();
   normals.setXYZ(first,normal.x,normal.y,normal.z);normals.setXYZ(last,normal.x,normal.y,normal.z);
  }
  for(let col=0;col<=around;col++)normals.setXYZ(col,0,1,0);
  normals.needsUpdate=true;
  }
  if(gpuUniforms){gpuUniforms.clothTime.value=t;gpuUniforms.clothSpeed.value=moving?1.6:1}
  for(const {socket,theta,v} of eyes){
   const p=surface(theta,v,t,moving);
   tangent.copy(surface(theta+.001,v,t,moving)).sub(surface(theta-.001,v,t,moving));
   vertical.copy(surface(theta,v+.001,t,moving)).sub(surface(theta,v-.001,t,moving));
   normal.crossVectors(vertical,tangent).normalize();
   socket.position.copy(p).addScaledVector(normal,.009);
   socket.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),normal);
   const blink=t%6.4;
   socket.scale.y=blink>6.20?1-.92*Math.sin((blink-6.20)/.20*Math.PI):1;
  }
  lastTime=t;lastMoving=moving;
 }
 update(0);
 return {group,update,gpu,setEyeContrast,setFlutter(strength,phase){if(gpuUniforms){gpuUniforms.clothFlutter.value=strength;gpuUniforms.clothPhase.value=phase}},sheet,surface,geometry,around,down,setVanished,get visibility(){return clothVisibility}};
}
