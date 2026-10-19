// Reminder prelude with a continuous return to idle.
export function reminderNotice(elapsed,baseYaw,idleYaw){
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*x*(x*(x*6-15)+10)};
 const spinSeconds=1.9,fadeSeconds=.85,total=3.35;
 const destination=idleYaw+Math.round((baseYaw-idleYaw)/(Math.PI*2))*Math.PI*2;
 let yaw=baseYaw+Math.PI*2*smooth(elapsed/spinSeconds);
 if(elapsed>spinSeconds)yaw+=(destination-baseYaw)*smooth((elapsed-spinSeconds)/fadeSeconds);
 const glow=smooth(elapsed/.3)*(1-smooth((elapsed-1.55)/1.8));
 return {yaw,glow,showBubble:elapsed>=spinSeconds,active:elapsed>=0&&elapsed<total};
}

// Keep the same filter layers at rest and during the cue. Returning an empty
// filter would instantly restore the stylesheet's resting shadow.
export function companionShadow(glow,light){
 glow=Math.max(0,Math.min(1,glow));
 const rest=`drop-shadow(0 18px 22px rgba(6,6,17,${.4*(1-.65*glow)}))`;
 if(glow===0)return rest;
 const inner=light?`rgba(112,65,184,${glow*.95})`:`rgba(218,194,255,${glow*.95})`;
 const middle=light?`rgba(141,86,220,${glow*.8})`:`rgba(244,235,255,${glow*.8})`;
 const outer=light?`rgba(156,106,225,${glow*.55})`:`rgba(218,194,255,${glow*.45})`;
 return `${rest} drop-shadow(0 0 3px ${inner}) drop-shadow(0 0 ${8+glow*10}px ${middle}) drop-shadow(0 0 ${16+glow*14}px ${outer})`;
}

// Subsequent reminders use a glow-only handoff.
export function queueCue(elapsed,baseYaw,idleYaw){
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*x*(x*(x*6-15)+10)};
 const destination=idleYaw+Math.round((baseYaw-idleYaw)/(Math.PI*2))*Math.PI*2;
 return {yaw:baseYaw+(destination-baseYaw)*smooth(elapsed/.8),
  glow:smooth(elapsed/.3)*(1-smooth((elapsed-1.1)/1.6)),
  showBubble:elapsed>=1.2,active:elapsed>=0&&elapsed<2.7};
}
