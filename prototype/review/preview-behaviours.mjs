// All behaviour experiments stay in the standalone HTML preview.
export function createPreviewBehaviours(){
 let sleep=0,wantsSleep=false,flutterTime=Infinity,curiousTime=Infinity;
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x)};
 return {
  sleep(){wantsSleep=true},
  wake(){wantsSleep=false},
  flutter(){wantsSleep=false;flutterTime=0},
  curious(){wantsSleep=false;curiousTime=0},
  step(dt,{busy=false,reduced=false}={}){
   dt=Math.max(0,Math.min(.1,dt));
   const target=wantsSleep&&!busy?1:0;
   sleep+=(target-sleep)*(1-Math.exp(-dt*1.7));
   if(Number.isFinite(flutterTime))flutterTime+=dt;
   if(Number.isFinite(curiousTime))curiousTime+=dt;
   const envelope=(elapsed,duration)=>Number.isFinite(elapsed)&&elapsed>=0&&elapsed<duration?Math.sin(Math.PI*elapsed/duration)**2:0;
   const curious=!busy&&!reduced?envelope(curiousTime,3.6):0;
   const p=flutterTime/3.6;
   const flutter=p>=0&&p<1&&!busy&&!reduced?Math.sin(Math.PI*p)**2:0;
   return {sleep,eyeOpen:1-.7*smooth(sleep),speed:1-.65*sleep,
    curious,flutter,bob:flutter*.10,tilt:curious*.19,
    phase:Number.isFinite(flutterTime)?flutterTime:0};
  }
 };
}

// A travelling spiral in the free fabric; the crown and face stay calm.
export function previewWhirlPoint(x,y,z,v,theta,strength,phase){
 const free=Math.max(0,(v-.34)/.66),weight=free*free*strength;
 const wave=Math.sin(theta*3-v*7-phase*7);
 const angle=weight*(.62+.16*Math.sin(v*7-phase*5));
 const radius=1-weight*.13+weight*.075*wave;
 const c=Math.cos(angle),s=Math.sin(angle);
 return {x:(x*c+z*s)*radius,y:y+weight*(.10+.12*wave),z:(z*c-x*s)*radius};
}
