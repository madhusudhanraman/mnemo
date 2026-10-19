// Preview-only handoff: glow without a second pirouette.
export function queueCue(elapsed,baseYaw,idleYaw){
 const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*x*(x*(x*6-15)+10)};
 const destination=idleYaw+Math.round((baseYaw-idleYaw)/(Math.PI*2))*Math.PI*2;
 return {yaw:baseYaw+(destination-baseYaw)*smooth(elapsed/.8),
  glow:smooth(elapsed/.3)*(1-smooth((elapsed-1.1)/1.6)),
  showBubble:elapsed>=1.2,active:elapsed>=0&&elapsed<2.7};
}
