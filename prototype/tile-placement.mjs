// All coordinates are in the companion web view, intersected with its display.
export function placeTile(body,width,height,bounds,preferred='below'){
 const gap=8,pad=12;
 const a={left:bounds.left+pad,top:bounds.top+pad,right:bounds.right-pad,bottom:bounds.bottom-pad};
 const x=body.left+body.width/2-width/2,y=(body.top+body.bottom-height)/2;
 const candidates={above:{left:x,top:body.top-gap-height},below:{left:x,top:body.bottom+gap},left:{left:body.left-gap-width,top:y},right:{left:body.left+body.width+gap,top:y}};
 const order=[preferred,...['left','right','above','below'].filter(side=>side!==preferred)];
 const fits=p=>p.left>=a.left&&p.top>=a.top&&p.left+width<=a.right&&p.top+height<=a.bottom;
 const side=order.find(side=>fits(candidates[side]))||order.reduce((best,side)=>{
  const visible=p=>Math.max(0,Math.min(p.left+width,a.right)-Math.max(p.left,a.left))*Math.max(0,Math.min(p.top+height,a.bottom)-Math.max(p.top,a.top));
  return visible(candidates[side])>visible(candidates[best])?side:best;
 });
 const p=candidates[side];
 return {side,left:Math.max(a.left,Math.min(a.right-width,p.left)),top:Math.max(a.top,Math.min(a.bottom-height,p.top))};
}
