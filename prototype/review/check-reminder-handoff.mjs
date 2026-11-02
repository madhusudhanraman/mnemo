import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const classes=new Set();let removals=0;
const bubble={classList:{add:c=>classes.add(c),remove:c=>{removals++;classes.delete(c)}},replaceChildren(){},append(){}};
const context=vm.createContext({bubble,document:{createElement:()=>({append(){}})},clearTimeout(){},setTimeout(){},
 announcementReveal:null,announcementStart:-100,activeThoughtPersistent:false,bubbleTimer:null,queueGlowOnly:false,queueFlutterAllowed:false,
 behaviours:{flutter(){}},wakeCompanion(){},spotifyCaption:{sync(){}},companion:{setVanished(){}},peekabooReturn:0,nextPeekaboo:0,time:10,
 paused:false,reduced:false,spinStart:0,nextAdventure:0,announcementBaseYaw:0,model:{rotation:{y:0}},invalidateRender(){}});
const source=readFileSync(new URL('../src/reminder-start.js',import.meta.url),'utf8').split('let lastHitReport=')[0];
vm.runInContext(source,context);
vm.runInContext("showThought('First',{persistent:true})",context);
assert.equal(classes.has('show'),false,'First reminder waits for its entrance');
vm.runInContext('announcementReveal();announcementReveal=null',context);
assert.ok(classes.has('show'));
const before=removals;
for(const entrance of ['done','next']){
 vm.runInContext(`showThought('Next',{persistent:true,entrance:'${entrance}'})`,context);
 assert.ok(classes.has('show'),'Queued reminder stays visible');
 assert.equal(removals,before,'Handoff never hides the bubble');
 assert.equal(context.announcementReveal,null,'Animation cannot reveal the reminder again');
}
vm.runInContext('hideThought()',context);
assert.equal(classes.has('show'),false,'Final dismissal hides the bubble');
console.log('PASS: first entrance, uninterrupted Done/Later handoffs, and final dismissal');
