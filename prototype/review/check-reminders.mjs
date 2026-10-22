// Exercise the actual reminder UI with a minimal DOM and a controlled native bridge.
import assert from 'node:assert/strict';
import {startReminders} from '../reminders.mjs';
const elements=new Map(),handlers={},timers=new Map();let serial=0,shown,hidden=0;
function element(){return {value:'',hidden:false,disabled:false,textContent:'',style:{},attrs:{},children:[],classList:{add(){},remove(){}},append(...nodes){this.children.push(...nodes)},replaceChildren(){this.children=[]},setAttribute(k,v){this.attrs[k]=v},focus(){this.focused=true},reset(){},setPointerCapture(){},getBoundingClientRect(){return {left:0,top:0,width:176,height:176}}}}
function get(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)}
globalThis.document={createElement:element,getElementById:get,body:{append(){},classList:{add(){}}}};
globalThis.setTimeout=(fn,delay)=>{timers.set(++serial,{fn,delay});return serial};globalThis.clearTimeout=id=>timers.delete(id);
let rows=[{id:'a',text:'Test reminder',status:'due',dueAt:1}],actions=[],saves=[];
globalThis.window={addEventListener:(name,fn)=>handlers[name]=fn,mnemoDesktop:{mode:'companion',async list(){return rows.map(r=>({...r}))},async save(row){saves.push(row);return []},async action({id,action}){actions.push(action);rows=rows.map(r=>r.id===id?({...r,status:action==='done'?'done':'pending',dueAt:Date.now()+10800000}):r);return rows}}};
const flush=()=>new Promise(resolve=>queueMicrotask(resolve));
startReminders({showThought:(text,options)=>{shown=options},hideThought:()=>hidden++,onDesktopMode(){}});await flush();
assert.deepEqual(shown.actions.map(a=>a.label),['Done','Remind Me Later']);
assert.equal(shown.persistent,true);assert.ok(![...timers.values()].some(t=>t.delay===45000),'No automatic dismissal timer');
await shown.actions[1].run();assert.deepEqual(actions,['snooze']);assert.ok(hidden);
rows=[{id:'b',text:'Second',status:'due',dueAt:2}];handlers['mnemo-reminders-changed']();await flush();await shown.actions[0].run();assert.deepEqual(actions,['snooze','done']);
rows=[{id:'c',text:'Third',status:'due',dueAt:3}];handlers['mnemo-reminders-changed']();await flush();
assert.equal(shown.persistent,true);assert.deepEqual(actions,['snooze','done']);assert.ok(![...timers.values()].some(t=>t.delay===45000),'Unanswered reminders remain until acted on');
rows=[];handlers['mnemo-reminders-changed']();await flush();
rows=[1,2,3].map(i=>({id:'q'+i,text:'Queued '+i,status:'due',dueAt:i}));handlers['mnemo-reminders-changed']();await flush();assert.equal(shown.entrance,'full');
await shown.actions[0].run();assert.equal(shown.entrance,'done','Done advances with glow and flutter');
await shown.actions[1].run();assert.equal(shown.entrance,'next','Later advances with glow only');
await shown.actions[0].run();
assert.equal(get('reminder-time').value,'days');assert.equal(get('date-controls').hidden,true);
get('mode-date').onclick();assert.equal(get('days-controls').hidden,true);assert.equal(get('date-controls').hidden,false);assert.equal(get('reminder-days').disabled,true);
get('show-clock').onclick();assert.equal(get('calendar-pane').hidden,true);assert.equal(get('clock-pane').hidden,false);
const before=new Date(get('reminder-when').value);get('hour-wheel').children[2].onclick();const after=new Date(get('reminder-when').value);assert.equal(after.getHours()%12,3);assert.equal(after.getDate(),before.getDate());
get('minute-wheel').children[25].onclick();assert.equal(new Date(get('reminder-when').value).getMinutes(),25);
get('minute-wheel').onkeydown({key:'ArrowDown',preventDefault(){}});assert.equal(new Date(get('reminder-when').value).getMinutes(),26);
get('minute-wheel').onkeydown({key:'End',preventDefault(){}});assert.equal(new Date(get('reminder-when').value).getMinutes(),59);
get('minute-wheel').onkeydown({key:'ArrowDown',preventDefault(){}});assert.equal(new Date(get('reminder-when').value).getMinutes(),0);
get('dial-am').onclick();assert.equal(new Date(get('reminder-when').value).getHours(),3);
get('mode-days').onclick();assert.equal(get('date-controls').hidden,true);assert.equal(get('days-controls').hidden,false);assert.equal(get('reminder-days').disabled,false);
get('reminder-text').value='Two days';get('reminder-days').value='2';
await get('reminder-form').onsubmit({preventDefault(){}});assert.equal(saves.length,1);
const expected=new Date();expected.setDate(expected.getDate()+2);assert.ok(Math.abs(saves[0].dueAt-expected.getTime())<2000);
console.log('PASS: Done/Later actions, persistent unanswered bubble, explicit postponement, exclusive modes, hour/minute wheels, AM/PM and calendar-day saving.');

const realNow=Date.now;
const fixedNow=new Date(2026,9,22,15,40).getTime();
Date.now=()=>fixedNow;
try{
 for(const [minutes,label] of [[1,'In about a minute'],[25,'In about 25 minutes'],[60,'In about an hour'],[180,'In about 3 hours'],[2880,'In about 2 days'],[-5,'That time has passed']]){
  const date=new Date(fixedNow+minutes*60000);
  get('reminder-when').value=new Date(date.getTime()-date.getTimezoneOffset()*60000).toISOString().slice(0,16);
  get('mode-date').onclick();assert.equal(get('date-summary').textContent,label);
  assert.ok(get('date-summary').title,'Exact date remains available as a tooltip');
 }
}finally{Date.now=realNow}
console.log('PASS: picker summary expresses rough time remaining and identifies past times');

get('reminder-text').value='';
for(let i=0;i<100;i++){
 const previous=get('reminder-text').placeholder;
 handlers['mnemo-new-reminder']();
 assert.ok(get('reminder-text').placeholder.endsWith('…'));
 assert.notEqual(get('reminder-text').placeholder,previous,'Fresh prompts avoid consecutive repeats');
 assert.equal(get('reminder-text').value,'','A prompt is never actual reminder text');
}
get('reminder-text').value='My draft';const draftPrompt=get('reminder-text').placeholder;
handlers['mnemo-new-reminder']();assert.equal(get('reminder-text').value,'My draft');assert.equal(get('reminder-text').placeholder,draftPrompt);
console.log('PASS: new reminder prompts rotate without replacing a draft');
