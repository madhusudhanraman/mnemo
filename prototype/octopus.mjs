import * as THREE from './vendor/three.module.mjs';
import {MarchingCubes} from './vendor/MarchingCubes.mjs';
export function createOctopus(){
const model=new THREE.Group();
const skin=new THREE.MeshPhysicalMaterial({color:0xb29aef,roughness:.48,metalness:0,clearcoat:.25,clearcoatRoughness:.28,envMapIntensity:.65});
const pink=new THREE.MeshStandardMaterial({color:0xf1b4ca,roughness:.5});
const dark=new THREE.MeshPhysicalMaterial({color:0x261238,roughness:.2,clearcoat:.8,envMapIntensity:.7});
const sphere=new THREE.SphereGeometry(1,96,64);
function ball(parent,mat,pos,scale){const mesh=new THREE.Mesh(sphere,mat);mesh.position.set(...pos);mesh.scale.set(...scale);parent.add(mesh);return mesh}
// One implicit surface joins dome, mantle and all eight arms.
// Smooth union removes the cut rims and intersecting tube roots.
const resolution=96,extent=2.85,step=extent*2/resolution;
const organicMaterial=skin.clone();organicMaterial.vertexColors=true;organicMaterial.color.set(0xffffff);
const organic=new MarchingCubes(resolution,organicMaterial,false,true,100000);
organic.isolation=0;organic.scale.setScalar(extent);organic.frustumCulled=false;model.add(organic);
const baseField=new Float32Array(resolution**3);
const rootBlend=new Float32Array(resolution**3);
function smoothMin(a,b,k){const h=Math.max(k-Math.abs(a-b),0)/k;return Math.min(a,b)-h*h*k*.25}
function ellipsoid(x,y,z,rx,ry,rz){const k0=Math.hypot(x/rx,y/ry,z/rz),k1=Math.hypot(x/(rx*rx),y/(ry*ry),z/(rz*rz));return k1? k0*(k0-1)/k1:-Math.min(rx,ry,rz)}
for(let z=0;z<resolution;z++)for(let y=0;y<resolution;y++)for(let x=0;x<resolution;x++){
 const wx=x*step-extent,wy=y*step-extent,wz=z*step-extent;
 const dome=ellipsoid(wx,wy-.72,wz,1.40,1.14,1.02);
 const mantle=ellipsoid(wx,wy+.25,wz,.82,.36,.77);
 const index=x+resolution*y+resolution*resolution*z;
 baseField[index]=-smoothMin(dome,mantle,.26);
 rootBlend[index]=.14*THREE.MathUtils.smoothstep(wy,-.85,-.30);
}
function blendSegment(a,b,ra,rb){
 const pad=Math.max(ra,rb)+.08;
 const lo=[a.x,a.y,a.z].map((v,i)=>Math.max(1,Math.floor((Math.min(v,[b.x,b.y,b.z][i])-pad+extent)/step)));
 const hi=[a.x,a.y,a.z].map((v,i)=>Math.min(resolution-2,Math.ceil((Math.max(v,[b.x,b.y,b.z][i])+pad+extent)/step)));
 const dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,len=dx*dx+dy*dy+dz*dz;
 for(let z=lo[2];z<=hi[2];z++)for(let y=lo[1];y<=hi[1];y++)for(let x=lo[0];x<=hi[0];x++){
  const px=x*step-extent-a.x,py=y*step-extent-a.y,pz=z*step-extent-a.z;
  const u=Math.max(0,Math.min(1,(px*dx+py*dy+pz*dz)/len));
  const distance=Math.hypot(px-dx*u,py-dy*u,pz-dz*u)-(ra+(rb-ra)*u);
  const index=x+resolution*y+resolution*resolution*z;
  organic.field[index]=Math.max(organic.field[index],-distance);
 }
}
const previousField=new Float32Array(baseField.length);
let surfaceTime=-100;
// Eyes sit on the head's tangent plane, rather than protruding as eyeballs.
const eyeGroup=new THREE.Group();model.add(eyeGroup);
const shine=new THREE.MeshBasicMaterial({color:0xfff9ff});
const eyeMeshes=[];
for(const x of [-.43,.43]){
 const y=.39,z=1.02*Math.sqrt(1-(x/1.40)**2-((y-.72)/1.14)**2);
 const socket=new THREE.Group();socket.position.set(x,y,z+.012);
 const outward=new THREE.Vector3(x/(1.40**2),(y-.72)/(1.14**2),z/(1.02**2)).normalize();
 socket.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),outward);
 eyeGroup.add(socket);
 ball(socket,dark,[0,0,0],[.21,.335,.027]);
 ball(socket,shine,[-.050,.105,.029],[.049,.078,.008]);
 ball(socket,shine,[.055,-.105,.027],[.019,.025,.005]);
 eyeMeshes.push(socket);
}
// Eight roots around a full ring: four front-facing and four rear-facing.
// A half-sector offset keeps an arm from sitting directly on the viewing axis.
// Each arm has its own reach, resting height and sweep. Root spacing is
// anatomical; the rest of an arm is free to cross another arm in projection.
const armTraits=[
 {reach:1.08,sweep:.12,drop:0,lift:true,speed:.91},
 {reach:1.02,sweep:.65,drop:.15,lift:false,speed:1.15},
 {reach:.83,sweep:-.48,drop:-.16,lift:false,speed:.84},
 {reach:.92,sweep:-.24,drop:.25,lift:true,speed:1.07},
 {reach:1.10,sweep:.32,drop:-.05,lift:false,speed:.93},
 {reach:.85,sweep:-.19,drop:.23,lift:false,speed:1.20},
 {reach:1.03,sweep:.28,drop:-.12,lift:false,speed:.80},
 {reach:.94,sweep:-.30,drop:.12,lift:false,speed:1.03}
];
const armPoses=armTraits.map((trait,i)=>{
 const angle=Math.PI/8+i*Math.PI/4,side=Math.cos(angle)>0?1:-1;
 const rest=trait.lift?[
  [.66,-.06],[.98,-.40],[1.47,-.48],[1.91,-.22],[2.00,.10],[1.87,.22]
 ]:[
  [.66,-.06],[.87,-.55],[1.05,-1.02],[1.39,-1.45],[1.63,-1.45],[1.71,-1.23]
 ];
 return rest.map(([r,y],j)=>{
  const u=j/(rest.length-1),weight=u*u;
  const a=angle+trait.sweep*weight+side*.05*Math.sin(u*Math.PI);
  r*=1+(trait.reach-1)*weight;
  return [Math.cos(a)*r,y-trait.drop*weight,Math.sin(a)*r];
 });
});
if(armPoses.length!==8)throw new Error('The companion must have exactly eight arms');
const arms=[];
const cupGeo=new THREE.SphereGeometry(1,16,12);
for(let i=0;i<8;i++){
 const cups=Array.from({length:4},()=>{const cup=new THREE.Mesh(cupGeo,pink);model.add(cup);return cup});arms.push({cups,pose:armPoses[i]});
}
const up=new THREE.Vector3(0,1,0),axis=new THREE.Vector3();
// Keep a broad attachment, then taper quickly into a flexible slender arm.
function armRadius(u){return .205*Math.pow(1-u,1.7)+.055}
function makeArmCurve(arm,i,t,swimming){
 const trait=armTraits[i];
 const phase=t*(swimming?2.5:1.3)*trait.speed+i*1.1;
 const gather=swimming?.48:.18*(.5+.5*Math.sin(t*.42-1.4));
 const baseCurve=new THREE.CatmullRomCurve3(arm.pose.map(([x,y,z],j)=>{
  const u=j/(arm.pose.length-1),weight=u*u;
  const sweep=Math.sin(t*.37*trait.speed+i*1.7)*.25*weight;
  const px=x*Math.cos(sweep)-z*Math.sin(sweep),pz=x*Math.sin(sweep)+z*Math.cos(sweep);
  // On a swimming stroke the arms loosely trail together; in idle they
  // alternately gather and unfurl. Different depths preserve occlusion.
  const target=new THREE.Vector3(.20*Math.sin(i*2.3),-1.30-trait.drop,-.70-i*.055);
  return new THREE.Vector3(px,y,pz).lerp(target,gather*weight);
 }));
 const angle=Math.atan2(arm.pose[0][2],arm.pose[0][0]);
 const lateral=new THREE.Vector3(-Math.sin(angle),0,Math.cos(angle));
 const activity=.45+.55*Math.pow(.5+.5*Math.sin(t*.38+i*2.1),2);
 const motion=(swimming?1.35:1)*activity;
 const points=Array.from({length:33},(_,j)=>{
  const u=j/32,p=baseCurve.getPoint(u),tangent=baseCurve.getTangent(u).normalize();
  const bend=new THREE.Vector3().crossVectors(tangent,lateral).normalize();
  const envelope=Math.pow(u,1.5)*motion;
  // Phase moves toward the tip: the arm bends along its length instead of
  // translating as a rigid limb. A slower tip curl adds an independent motion.
  const wave=Math.sin(phase-u*5.2)*.20+Math.sin(phase*1.7-u*8.0)*.045*u;
  const curl=Math.sin(t*.63+i*1.4)*.10*u*u*u;
  p.addScaledVector(bend,wave*envelope+curl*motion);
  p.addScaledVector(lateral,Math.sin(phase*.83-u*4.0)*.12*envelope);
  return p;
 });
 return new THREE.CatmullRomCurve3(points);
}
function skinArm(arm,curve){
 // Segment fields are combined first, then blended once into the body.
 // This avoids inflating an arm where adjacent sampling segments overlap.
 previousField.set(organic.field);
 organic.field.fill(-100);
 let a=curve.getPoint(0);
 for(let j=1;j<=32;j++){
  const u=j/32,b=curve.getPoint(u);
  // Use a sharp union within each arm; Catmull-Rom samples make it smooth.
  blendSegment(a,b,armRadius((j-1)/32),armRadius(u));a=b;
 }
 for(let k=0;k<organic.field.length;k++){const blend=rootBlend[k];organic.field[k]=blend>0?-smoothMin(-previousField[k],-organic.field[k],blend):Math.max(previousField[k],organic.field[k]);}
 arm.cups.forEach((cup,k)=>{const u=.50+k*.105,p=curve.getPoint(u),r=armRadius(u);axis.copy(curve.getTangent(u)).normalize();const outward=new THREE.Vector3(0,-1,0).addScaledVector(axis,axis.y).normalize();cup.position.copy(p).addScaledVector(outward,r*.94);cup.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),outward);cup.scale.set(r*.43,r*.43,r*.12)})
}

// Overlapping silhouettes should be separate arms in depth, never welded
// together at a crossing. Resolve close distal segments along the depth axis.
function separateArms(curves){
 const priorities=curves.map((curve,i)=>curve.points[0].z+i*.0001);
 for(let pass=0;pass<8;pass++){
  for(let i=0;i<curves.length;i++)for(let k=0;k<i;k++){
   const direction=priorities[i]>priorities[k]?1:-1;
   for(let j=14;j<=32;j++)for(let l=14;l<=32;l++){
    const p=curves[i].points[j],q=curves[k].points[l];
    const gap=armRadius(j/32)+armRadius(l/32)+.12;
    const dx=p.x-q.x,dy=p.y-q.y;
    if(dx*dx+dy*dy>=gap*gap)continue;
    const required=Math.sqrt(gap*gap-dx*dx-dy*dy);
    const actual=(p.z-q.z)*direction;
    if(actual<required){const correction=Math.min(.08,(required-actual)*.22);p.z+=direction*correction;q.z-=direction*correction;}
   }
  }
  for(const curve of curves){const z=curve.points.map(p=>p.z);for(let j=13;j<32;j++)curve.points[j].z=z[j]*.6+(z[j-1]+z[j+1])*.2;}
 }
}
const colorLow=new THREE.Color(0x9e82da),colorHigh=new THREE.Color(0xd3bdf3),colorPink=new THREE.Color(0xf3b9d0),colorCheek=new THREE.Color(0xefadcb);
function colorSkin(){
 const pos=organic.geometry.attributes.position,norm=organic.geometry.attributes.normal,colors=organic.geometry.attributes.color;
 for(let i=0;i<organic.count;i++){
  const x=pos.getX(i)*extent,y=pos.getY(i)*extent,z=pos.getZ(i)*extent;
  const mix=THREE.MathUtils.clamp(.42+y*.22-x*.065,0,1);
  let r=colorLow.r+(colorHigh.r-colorLow.r)*mix,g=colorLow.g+(colorHigh.g-colorLow.g)*mix,b=colorLow.b+(colorHigh.b-colorLow.b)*mix;
  const cheek=Math.exp(-(((Math.abs(x)-.73)/.18)**2+((y-.16)/.10)**2))*THREE.MathUtils.smoothstep(z,.6,.85)*.72;
  r+=(colorCheek.r-r)*cheek;g+=(colorCheek.g-g)*cheek;b+=(colorCheek.b-b)*cheek;
  const ny=norm.getY(i)/Math.max(1e-6,Math.hypot(norm.getX(i),norm.getY(i),norm.getZ(i)));
  const underside=THREE.MathUtils.smoothstep(-y,.45,.85)*THREE.MathUtils.smoothstep(-ny,.3,.85)*.65;
  r+=(colorPink.r-r)*underside;g+=(colorPink.g-g)*underside;b+=(colorPink.b-b)*underside;
  colors.setXYZ(i,r,g,b);
 }colors.needsUpdate=true;
}
function update(t,swimming=false){
 if(t-surfaceTime>=1/30||surfaceTime<0){organic.reset();organic.field.set(baseField);const curves=arms.map((arm,i)=>makeArmCurve(arm,i,t,swimming));separateArms(curves);arms.forEach((arm,i)=>skinArm(arm,curves[i]));organic.update();colorSkin();surfaceTime=t;}
 const blink=t%5.7;for(const eye of eyeMeshes)eye.scale.y=blink>5.5?.1:1;
}
update(0);
return {group:model,update,surface:organic,armPoses};
}
