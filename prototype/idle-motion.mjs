// A small, slow orbit around the user's resting spot, not a roaming target.
export function idleOffset(seconds){
 return {
  x:Math.sin(seconds*.20)*20+Math.sin(seconds*.47)*12,
  y:Math.sin(seconds*.29)*14+Math.sin(seconds*.61)*6
 };
}
