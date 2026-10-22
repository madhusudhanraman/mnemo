import assert from 'node:assert/strict';
import {placeTile} from '../tile-placement.mjs';
const bounds={left:0,top:0,right:840,bottom:760};
for(const left of [20,370,690])for(const top of [20,300,590])for(const preferred of ['above','below']){
 const body={left,top,width:128,bottom:top+150};
 const p=placeTile(body,230,160,bounds,preferred);
 assert.ok(p.left>=12&&p.top>=12&&p.left+230<=828&&p.top+160<=748);
 assert.ok(p.left+230<=body.left||p.left>=body.left+body.width||p.top+160<=body.top||p.top>=body.bottom,'Tile must not cover Mnemo');
}
const clipped={left:300,top:300,right:840,bottom:760};
const p=placeTile({left:320,top:320,width:128,bottom:470},230,160,clipped,'above');
assert.equal(p.side,'right');
console.log('PASS: tile placement at all edges/corners and partially offscreen windows');
