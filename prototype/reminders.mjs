// Shared UI for the local prototype and native macOS app.
export function startReminders({showThought,hideThought,onDone=()=>{},onDesktopMode}){
 const native=window.mnemoDesktop;
 const root=document.createElement('section');root.id='reminder-panel';
 root.innerHTML=`<header><div><h2>Reminders</h2></div><button id="close-reminders" aria-label="Close reminders">×</button></header>
 <form id="reminder-form" class="thought-form"><label for="reminder-text">Remind me to</label><input id="reminder-text" name="text" placeholder="" maxlength="280" required autocomplete="off"><div class="schedule-modes"><button id="mode-days" type="button" aria-pressed="true">Days</button><button id="mode-date" type="button" aria-pressed="false">Date & Time</button></div><div id="days-controls" class="day-row"><span>in</span><input id="reminder-days" type="number" min="1" max="3650" step="1" value="2" aria-label="Days until reminder" required><span>days</span></div><select id="reminder-time" hidden><option value="days">Days</option><option value="custom">Custom</option></select><input id="reminder-when" type="hidden"><div id="date-controls" hidden><div class="picker-tabs"><button id="show-calendar" type="button" aria-pressed="true">Date</button><button id="show-clock" type="button" aria-pressed="false">Time</button></div><div id="calendar-pane"><div class="month-nav"><button id="month-prev" type="button" aria-label="Previous month">‹</button><span id="picker-month"></span><button id="month-next" type="button" aria-label="Next month">›</button></div><div class="weekdays" aria-hidden="true"><span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span></div><div id="picker-days"></div></div><div id="clock-pane" hidden><div class="time-wheels"><div id="hour-wheel" class="time-wheel" role="listbox" tabindex="0" aria-label="Hour"></div><span class="wheel-colon" aria-hidden="true">:</span><div id="minute-wheel" class="time-wheel" role="listbox" tabindex="0" aria-label="Minute"></div><div class="period-picker"><button id="dial-am" type="button">AM</button><button id="dial-pm" type="button">PM</button></div></div></div><p id="date-summary" aria-live="polite"></p></div><div class="form-bottom"><button id="save-reminder" type="submit" class="primary" aria-label="Save reminder">✓</button></div><button id="cancel-edit" type="button" hidden>Cancel edit</button></form>
 <p id="reminder-message" role="status"></p>
 <div class="list-heading"><h3>Upcoming</h3><span id="reminder-count"></span></div><div id="reminder-list"></div><details id="completed-reminders"><summary>Completed</summary><div id="completed-list"></div></details>
`;
 document.body.append(root);
 const $=id=>document.getElementById(id),form=$('reminder-form'),text=$('reminder-text'),when=$('reminder-when'),message=$('reminder-message');
 const sillyPrompts=[
  "Invade Berlin…",
  "Knock over a casino…",
  "Give the skeletons a bigger closet…",
  "Embark on a fool’s errand…",
  "Schedule a wild goose chase…"
];
 window.addEventListener('mnemo-new-reminder',()=>{if(!editing&&!text.value.trim())freshPrompt()});
 function freshPrompt(){const choices=sillyPrompts.filter(prompt=>prompt!==text.placeholder);text.placeholder=choices[Math.floor(Math.random()*choices.length)]}
 const storageKey='mnemo.reminders.v1';let reminders=[],editing=null,activeId=null,writing=false,pendingAction=null;
 const localDate=d=>new Date(d.getTime()-d.getTimezoneOffset()*60000).toISOString().slice(0,16);
 function relativeSummary(date){
  const minutes=(date.getTime()-Date.now())/60000;
  if(minutes<=0)return 'That time has passed';
  if(minutes<1)return 'In less than a minute';
  if(minutes<45){const count=minutes<10?Math.round(minutes):Math.round(minutes/5)*5;return count===1?'In about a minute':`In about ${count} minutes`}
  if(minutes<90)return 'In about an hour';
  if(minutes<1440)return `In about ${Math.round(minutes/60)} hours`;
  const days=Math.round(minutes/1440);return days===1?'In about a day':`In about ${days} days`;
 }
 const timeLabel=ms=>new Intl.DateTimeFormat(undefined,{dateStyle:'medium',timeStyle:'short'}).format(new Date(ms));
 const uuid=()=>globalThis.crypto?.randomUUID?.()||`${Date.now()}-${Math.random().toString(16).slice(2)}`;
 const api=native||{
  async list(){let rows;try{rows=JSON.parse(localStorage.getItem(storageKey)||'[]')}catch{throw new Error('Saved reminders could not be read. Your saved data has not been changed.')}if(!Array.isArray(rows))throw new Error('Saved reminder data is invalid.');return rows},
  async save(item){const rows=await this.list(),index=rows.findIndex(r=>r.id===item.id);const row={...item,id:item.id||uuid(),status:'pending',createdAt:index<0?Date.now():rows[index].createdAt};if(index<0)rows.push(row);else rows[index]=row;localStorage.setItem(storageKey,JSON.stringify(rows));return rows},
  async action({id,action}){const rows=await this.list(),row=rows.find(r=>r.id===id);if(!row)throw new Error('That reminder no longer exists.');if(action==='delete')rows.splice(rows.indexOf(row),1);else if(action==='done')row.status='done';else if(action==='snooze'){row.status='pending';row.dueAt=Date.now()+3*60*60000}else throw new Error('Unknown reminder action.');localStorage.setItem(storageKey,JSON.stringify(rows));return rows},

 };
 function report(error){message.textContent=error.message||String(error);message.classList.add('error')}
 function open(){if(native?.mode==='companion'){native.manage();return}document.body.classList.add('reminders-open');root.hidden=false;if(!editing&&!text.value.trim())freshPrompt();setTimeout(()=>text.focus(),50);refresh()}
 function close(){if(native?.mode==='manager'){native.closeManager();return}document.body.classList.remove('reminders-open')}
 function reset(){editing=null;form.reset();freshPrompt();when.value=localDate(new Date(Date.now()+2*86400000));$('save-reminder').textContent='✓';$('cancel-edit').hidden=true;when.hidden=true;showPickerPart(false);$('reminder-time').value='days';$('reminder-days').disabled=false;$('reminder-days').value='2';setSchedule('days')}
 async function refresh(){try{reminders=await api.list();render();presentDue()}catch(e){report(e)}}
 function rowView(row,completed=false){
  const article=document.createElement('article');article.className='reminder-row'+(row.status==='due'?' is-due':'');
  const body=document.createElement('div'),title=document.createElement('strong'),time=document.createElement('span');
  title.textContent=row.text;time.textContent=(row.status==='due'?'Due · ':'')+timeLabel(row.dueAt);body.append(title,time);article.append(body);
  const actions=document.createElement('div');actions.className='row-actions';
  function button(label,handler){const b=document.createElement('button');b.type='button';b.textContent=label;b.onclick=handler;actions.append(b)}
  if(!completed){button('Done',()=>act(row.id,'done'));if(row.status==='due')button('Remind Me Later',()=>act(row.id,'snooze'));button('Edit',()=>{editing=row.id;text.value=row.text;when.value=localDate(new Date(row.dueAt));shownMonth=new Date(new Date(row.dueAt).getFullYear(),new Date(row.dueAt).getMonth(),1);setSchedule('custom');$('save-reminder').textContent='✓';$('cancel-edit').hidden=false;text.focus()})}
  button('Delete',()=>act(row.id,'delete'));article.append(actions);return article;
 }
 function render(){
  const pending=reminders.filter(r=>r.status!=='done').sort((a,b)=>a.dueAt-b.dueAt),completed=reminders.filter(r=>r.status==='done').sort((a,b)=>b.dueAt-a.dueAt);
  const list=$('reminder-list'),done=$('completed-list');list.replaceChildren();done.replaceChildren();
  if(!pending.length){const empty=document.createElement('p');empty.className='empty-state';empty.textContent='Nothing to carry for you yet. Add a reminder above.';list.append(empty)}
  pending.forEach(r=>list.append(rowView(r)));completed.forEach(r=>done.append(rowView(r,true)));
  $('reminder-count').textContent=String(pending.length);$('completed-reminders').hidden=!completed.length;
 }
 function presentDue(){
  if(native?.mode==='manager')return;
  const due=reminders.filter(r=>r.status==='due').sort((a,b)=>a.dueAt-b.dueAt);
  if(!due.length){if(activeId){activeId=null;hideThought();if(pendingAction==='done')onDone()}pendingAction=null;return}
  const row=due[0];if(activeId===row.id)return;const entrance=activeId?(pendingAction==='done'?'done':'next'):'full';activeId=row.id;pendingAction=null;
  showThought(row.text,{persistent:true,entrance,meta:due.length>1?`${due.length} reminders waiting`:'A little reminder',actions:[{label:'Done',run:()=>act(row.id,'done')},{label:'Remind Me Later',run:()=>act(row.id,'snooze')}]});
 }
 async function act(id,action){if(writing)return;writing=true;pendingAction=action;try{reminders=await api.action({id,action});if(editing===id)reset();render();presentDue()}catch(e){report(e)}finally{writing=false}}
 form.onsubmit=async e=>{
  e.preventDefault();if(writing)return;
  const choice=$('reminder-time').value;
  const dueAt=choice==='custom'?new Date(when.value).getTime():(()=>{const date=new Date();date.setDate(date.getDate()+Number($('reminder-days').value));return date.getTime()})(),value=text.value.trim();
  if(!value){report(new Error('Add a reminder first.'));text.focus();return}
  if(!Number.isFinite(dueAt)||dueAt<=Date.now()){report(new Error('Choose a time in the future.'));if(choice==='custom'){setSchedule('custom');showPickerPart(true);$('hour-wheel').focus()}else $('reminder-days').focus();return}
  writing=true;$('save-reminder').disabled=true;
  try{reminders=await api.save({id:editing,text:value,dueAt});reset();message.classList.remove('error');message.textContent='Saved. I’ll remind you.';render();if(!activeId&&(!native?.mode||native.mode==='companion'))showThought('Got it. I’ll remind you.')}catch(e){report(e)}finally{writing=false;$('save-reminder').disabled=false}
 };
 $('close-reminders').onclick=close;$('cancel-edit').onclick=reset;
 function setSchedule(mode){
  const custom=mode==='custom';$('reminder-time').value=mode;
  $('days-controls').hidden=custom;$('date-controls').hidden=!custom;$('reminder-days').disabled=custom;
  $('mode-days').setAttribute('aria-pressed',String(!custom));$('mode-date').setAttribute('aria-pressed',String(custom));
  if(custom)renderPicker();
 }
 let shownMonth=new Date();
 function selectedDate(){const date=new Date(when.value);return Number.isFinite(date.getTime())?date:new Date(Date.now()+86400000)}
 function setDateValue(date){when.value=localDate(date);renderPicker()}
 function renderPicker(){
  const selected=selectedDate(),year=shownMonth.getFullYear(),month=shownMonth.getMonth();
  $('picker-month').textContent=new Intl.DateTimeFormat(undefined,{month:'long',year:'numeric'}).format(shownMonth);
  const grid=$('picker-days');grid.replaceChildren();
  const first=new Date(year,month,1).getDay(),count=new Date(year,month+1,0).getDate();
  for(let i=0;i<first;i++)grid.append(document.createElement('span'));
  const today=new Date();today.setHours(0,0,0,0);
  for(let day=1;day<=count;day++){
   const button=document.createElement('button');button.type='button';button.textContent=day;
   const date=new Date(year,month,day);button.disabled=date<today;
   button.setAttribute('aria-label',new Intl.DateTimeFormat(undefined,{dateStyle:'full'}).format(date));
   button.setAttribute('aria-pressed',String(selected.getFullYear()===year&&selected.getMonth()===month&&selected.getDate()===day));
   button.onclick=()=>{date.setHours(selected.getHours(),selected.getMinutes());setDateValue(date);showPickerPart(true)};grid.append(button);
  }
  const hour=selected.getHours()%12||12,minute=selected.getMinutes();
  syncWheel('hour-wheel',hour-1);syncWheel('minute-wheel',minute);
  $('dial-am').setAttribute('aria-pressed',String(selected.getHours()<12));$('dial-pm').setAttribute('aria-pressed',String(selected.getHours()>=12));
  $('date-summary').textContent=relativeSummary(selected);
  $('date-summary').title=timeLabel(selected.getTime());
 }
 function showPickerPart(clock){$('calendar-pane').hidden=clock;$('clock-pane').hidden=!clock;$('show-calendar').setAttribute('aria-pressed',String(!clock));$('show-clock').setAttribute('aria-pressed',String(clock));if(clock)renderPicker()}
 $('show-calendar').onclick=()=>showPickerPart(false);$('show-clock').onclick=()=>showPickerPart(true);
 $('mode-days').onclick=()=>setSchedule('days');$('mode-date').onclick=()=>{const date=selectedDate();shownMonth=new Date(date.getFullYear(),date.getMonth(),1);setSchedule('custom')};
 $('month-prev').onclick=()=>{shownMonth.setMonth(shownMonth.getMonth()-1);renderPicker()};$('month-next').onclick=()=>{shownMonth.setMonth(shownMonth.getMonth()+1);renderPicker()};
 for(const [id,offset] of [['dial-am',0],['dial-pm',12]])$(id).onclick=()=>{const date=selectedDate();date.setHours(date.getHours()%12+offset);setDateValue(date)};
 const wheelRows=36,wheelTimers=new Map();let scrollingWheel=null;
 function wheelValue(id){const date=selectedDate();return id==='hour-wheel'?((date.getHours()%12||12)-1):date.getMinutes()}
 function commitWheel(id,index){const date=selectedDate();if(id==='hour-wheel')date.setHours((index+1)%12+(date.getHours()>=12?12:0));else date.setMinutes(index);if(date.getTime()!==selectedDate().getTime())setDateValue(date)}
 function syncWheel(id,index){const wheel=$(id);wheel.setAttribute('aria-activedescendant',id+'-'+index);for(const [i,button] of [...wheel.children].entries())button.setAttribute('aria-selected',String(i===index));if(scrollingWheel!==id&&Math.abs(wheel.scrollTop-index*wheelRows)>1)wheel.scrollTop=index*wheelRows}
 for(const [id,count] of [['hour-wheel',12],['minute-wheel',60]]){
  const wheel=$(id);
  for(let i=0;i<count;i++){const button=document.createElement('button');button.type='button';button.id=id+'-'+i;button.setAttribute('role','option');button.tabIndex=-1;button.textContent=id==='hour-wheel'?String(i+1):String(i).padStart(2,'0');button.onclick=()=>{scrollingWheel=null;commitWheel(id,i);wheel.scrollTop=i*wheelRows};wheel.append(button)}
  wheel.onscroll=()=>{scrollingWheel=id;commitWheel(id,Math.max(0,Math.min(count-1,Math.round(wheel.scrollTop/wheelRows))));clearTimeout(wheelTimers.get(id));wheelTimers.set(id,setTimeout(()=>{const index=Math.max(0,Math.min(count-1,Math.round(wheel.scrollTop/wheelRows)));scrollingWheel=null;commitWheel(id,index);syncWheel(id,index)},120))};
  wheel.onkeydown=event=>{let index=wheelValue(id);if(event.key==='ArrowDown')index=(index+1)%count;else if(event.key==='ArrowUp')index=(index+count-1)%count;else if(event.key==='Home')index=0;else if(event.key==='End')index=count-1;else return;event.preventDefault();scrollingWheel=null;commitWheel(id,index);syncWheel(id,index)};
 }
 window.addEventListener('mnemo-reminder-action',event=>{if(event.detail?.id===activeId)pendingAction=event.detail.action});
 document.getElementById('remind').onclick=open;
 window.addEventListener('mnemo-reminders-changed',()=>{refresh()});
 if(!native){
  async function tick(){try{const rows=await api.list();let changed=false;const fired=[];for(const row of rows)if(row.status==='pending'&&row.dueAt<=Date.now()){row.status='due';changed=true;fired.push(row)}if(changed){localStorage.setItem(storageKey,JSON.stringify(rows));reminders=rows;render();presentDue();}}catch(e){report(e)}}
  setInterval(tick,1000);window.addEventListener('focus',tick);window.addEventListener('storage',e=>{if(e.key===storageKey)refresh()});tick();
 }
 window.addEventListener('focus',()=>{if($('reminder-time').value==='custom')renderPicker()});
 reset();refresh();
 if(native){document.body.classList.add('desktop-mode',native.mode==='manager'?'manager-mode':'companion-mode');onDesktopMode(native.mode);if(native.mode==='manager')open()}
 return {open,refresh};
}
