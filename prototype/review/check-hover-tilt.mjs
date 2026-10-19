import assert from 'node:assert/strict';
import {createBehaviours} from '../behaviours.mjs';
const b=createBehaviours();b.curious();let before;
for(let i=0;i<105;i++)before=b.step(1/60);
assert.ok(before.tilt>.17);
for(let i=0;i<15;i++){
 b.curious();const after=b.step(1/60);
 assert.ok(Math.abs(after.tilt-before.tilt)<.006,'Repeated hover must not reset the tilt');before=after;
}
let after=b.step(1/60,{busy:true});assert.ok(after.tilt>0&&Math.abs(after.tilt-before.tilt)<.025,'An interruption eases back rather than snapping');
for(let i=0;i<300;i++)after=b.step(1/60);assert.ok(after.tilt<.0001);
console.log('PASS: repeated hover preserves an ongoing tilt; interruptions ease out; settles upright.');
