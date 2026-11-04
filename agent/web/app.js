// Pure projection of native proof snapshots. No proof operations or eager descendants.
const ProofExplorer = (() => {
 function index(rows){
  const byId=new Map(rows.map(n=>[n.id,n])), links=new Map(), incoming=new Set(), descendants=new Map();
  for(const n of rows)if(n.parent){if(!descendants.has(n.parent))descendants.set(n.parent,[]);descendants.get(n.parent).push(n.id);}
  for(const n of rows){
   const active=[],implementation=[],history=[];
   const ids=new Set([...(n.children||[]),...Object.keys(n.edges||{})]);
   for(const id of descendants.get(n.id)||[])ids.add(id);
   for(const id of ids){
    const child=byId.get(id);if(!child||id===n.id)continue;
    // Native reparenting can leave retained historical edges behind.
    if(child.parent&&child.parent!==n.id&&byId.has(child.parent))continue;
    if(n.edges?.[id]?.expansion||child.expansion&&child.parent===n.id)implementation.push(id);
    else if((n.children||[]).includes(id))active.push(id);else history.push(id);
    incoming.add(id);
   }
   links.set(n.id,{active,implementation,history});
  }
  const roots=rows.filter(n=>!incoming.has(n.id)&&!n.parent).map(n=>n.id);
  const fragments=rows.filter(n=>!incoming.has(n.id)&&n.parent).map(n=>n.id);
  if(!roots.length&&!fragments.length&&rows.length)fragments.push(rows[0].id);
  // Goal labels organize incomplete history; they do not invent missing commands.
  const goals=new Map(),goalRoots=[];
  for(const id of fragments){
   const n=byId.get(id),parts=(n.label||'Unlabelled states').split('.');let parent=null;
   for(let i=0;i<parts.length;i++){
    const label=parts.slice(0,i+1).join('.');
    if(!goals.has(label)){
     goals.set(label,{label,title:i?'Goal '+parts.slice(1,i+1).join('.'):'Goal '+parts[0],ids:[],children:[]});
     if(parent)goals.get(parent).children.push(label);else goalRoots.push(label);
    }
    parent=label;
   }
   goals.get(parent).ids.push(id);
  }
  for(const goal of goals.values())goal.children.sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
  // Completion flows through current proof children only, never abandoned trials.
  const completed=new Set(),waiting=new Map(),dependents=new Map(),queue=[];
  for(const n of rows){
   if(n.status==='!'){completed.add(n.id);queue.push(n.id);}
   const kids=[...new Set(n.children||[])];
   if(kids.length&&kids.every(id=>byId.has(id)&&links.get(n.id).active.includes(id))){
    waiting.set(n.id,kids.length);
    for(const id of kids){if(!dependents.has(id))dependents.set(id,[]);dependents.get(id).push(n.id);}
   }
  }
  for(let i=0;i<queue.length;i++)for(const parent of dependents.get(queue[i])||[]){
   waiting.set(parent,waiting.get(parent)-1);
   if(waiting.get(parent)===0&&!completed.has(parent)){completed.add(parent);queue.push(parent);}
  }
  const completedGoals=new Set();
  for(const goal of [...goals.values()].sort((a,b)=>b.label.split('.').length-a.label.split('.').length)){
   if((goal.ids.length||goal.children.length)&&goal.ids.every(id=>completed.has(id))&&goal.children.every(label=>completedGoals.has(label)))completedGoals.add(goal.label);
  }
  return {byId,links,roots,fragments,goals,goalRoots,completed,completedGoals};
 }
 // Open the display ancestry, including lazy implementation/history and goal groups.
 function follow(model,target,opened,prefix,limit=200){
  if(!model.byId.has(target))return {target:null,limit};
  const parents=new Map();
  for(const [id,links] of model.links)for(const kind of ['active','implementation','history'])
   for(const child of links[kind])if(!parents.has(child)||model.byId.get(child)?.parent===id)parents.set(child,{id,kind});
  let id=target;const seen=new Set();
  while(parents.has(id)&&!seen.has(id)){
   seen.add(id);const p=parents.get(id);opened.add(prefix+p.id);
   if(p.kind!=='active')opened.add(prefix+p.id+':'+p.kind);
   id=p.id;
  }
  if(model.fragments.includes(id)){
   if(model.roots.length)opened.add(prefix+'_retained:fragments');
   const parts=(model.byId.get(id).label||'Unlabelled states').split('.');
   for(let i=1;i<=parts.length;i++)opened.add(prefix+'goal:'+parts.slice(0,i).join('.'));
  }
  // Pagination must not hide the requested cursor. This projects only open paths;
  // unopened descendants are still not visited or rendered.
  const view=visible(model,opened,prefix,Infinity),offset=view.rows.findIndex(r=>r.key===prefix+target);
  return {target:offset<0?null:target,limit:Math.max(limit,offset+1)};
 }
 function title(n,complete=false){return n.command_label||n.input_command||n.command||(complete||n.status==='!'?'QED':'Open goal');}
 function latestCommand(s,b,n){return (s.running&&s.command)||b?.command||s.command||n?.input_command||n?.command||'';}
 function visible(model,opened,prefix,limit=200,wholeProof=false){
  const result=[],stack=[];
  if(model.fragments.length){
   if(model.roots.length)stack.push({group:'fragments',owner:'_retained',goals:model.goalRoots,ids:[],parent:null,path:[],title:'Retained history',complete:wholeProof});
   else for(const goal of model.goalRoots.slice().reverse())stack.push({goal,parent:null,path:[],complete:wholeProof});
  }
  stack.push(...model.roots.slice().reverse().map(id=>({id,parent:null,path:[],complete:wholeProof})));
  while(stack.length&&result.length<limit){
   const item=stack.pop();
   if(item.goal){
    const goal=model.goals.get(item.goal),row={...item,key:prefix+'goal:'+item.goal,type:'group',title:goal.title,complete:!!item.complete||model.completedGoals.has(item.goal),open:opened.has(prefix+'goal:'+item.goal)};
    result.push(row);
    if(row.open){
     for(const child of goal.children.slice().reverse())stack.push({goal:child,parent:row.key,path:[],complete:row.complete});
     for(const id of goal.ids.slice().reverse())stack.push({id,parent:row.key,path:[],complete:row.complete});
    }
    continue;
   }
   if(item.group){
    const row={...item,key:prefix+item.owner+':'+item.group,type:'group'};row.open=opened.has(row.key);result.push(row);
    if(row.open)for(const goal of (item.goals||[]).slice().reverse())stack.push({goal,parent:row.key,path:[],complete:row.complete});
    if(row.open)for(const id of item.ids.slice().reverse())stack.push({id,parent:row.key,path:item.path,history:item.group==='history'||item.history,complete:item.group==='history'?false:row.complete});
    continue;
   }
   if(item.path.includes(item.id))continue;
   const n=model.byId.get(item.id);if(!n)continue;
   const links=model.links.get(n.id),key=prefix+n.id;
   const linear=links.active.length===1&&model.byId.get(links.active[0])?.label===n.label;
   const expandable=links.implementation.length>0||links.history.length>0||(!linear&&links.active.length>0);
   const row={...item,node:n,key,type:'command',links,linear,expandable,open:opened.has(key),complete:!!item.complete||model.completed.has(n.id)};result.push(row);
   const path=[...item.path,n.id];
   // A continuation is the next line of this goal, not another nested goal.
   if(linear)stack.push({id:links.active[0],parent:item.parent,path,history:item.history,complete:row.complete});
   if(!row.open)continue;
   if(links.history.length)stack.push({group:'history',owner:n.id,ids:links.history,parent:key,path,title:'Earlier attempts',history:true,complete:false});
   if(!linear)for(const id of links.active.slice().reverse())stack.push({id,parent:key,path,history:item.history,complete:row.complete});
   if(links.implementation.length)stack.push({group:'implementation',owner:n.id,ids:links.implementation,parent:key,path,title:'Primitive steps',history:item.history,complete:row.complete});
  }
  return {rows:result,more:stack.length>0};
 }
 return {index,visible,title,latestCommand,follow};
})();
if(typeof module!=='undefined')module.exports=ProofExplorer;
if(typeof document!=='undefined'){
'use strict';
const forest=document.querySelector('#forest'),panel=document.querySelector('#popover'),detail=document.querySelector('#detail');
let buffers=new Map(),openBuffers=new Set(),displayGeneration=null,connectionState=null;
let sessions=new Map(),nodes=new Map(),panes=new Map(),indexes=new Map(),strategies=[],pinned=false,hovered=null,dirty=false,latestGap=0,observationError=null,opened=new Set(),following=null,folded=new Set(),knownThreads=new Set();
const key=(sid,id)=>sid+':'+id;
function text(tag,content,cls){const n=document.createElement(tag);n.textContent=content;if(cls)n.className=cls;detail.append(n);return n;}
function showNode(node,event,pin=false,edge=null){
 if(!node)return;
 if(pinned&&!pin)return;hovered={node,event,edge};pinned=pin;panel.classList.toggle('pinned',pin);detail.replaceChildren();
 const session=sessions.get(node.session_id)||{};
 text('h3',edge?.label||node.command_label||node.label||node.id);
 const seq=node.sequent;
 if(seq){(seq.antecedents||[]).forEach((s,i)=>text('pre',`−${i+1}  ${s}`));text('div','','rule');(seq.succedents||[]).forEach((s,i)=>text('pre',`+${i+1}  ${s}`));if(seq.hidden)text('div',`${seq.hidden} hidden formula(s)`,'caption');if(seq.truncated)text('div','Display truncated; the native proof is unchanged.','caption');}
 else text('div','This state was outside the retained snapshot window.','caption');
 const command=edge?.command||node.input_command||node.command;
 if(command){text('div',edge?.expansion?'Strategy expansion':'Command','caption');text('pre',command);const name=command.match(/^\s*\(\s*([^\s()]+)/)?.[1]?.toLowerCase();const help=strategies.find(s=>s.name.toLowerCase()===name);if(help?.doc)text('div',help.doc,'doc');else text('div','No native command description available.','caption');}
 text('div',`${session.actor||'Agent'} · ${node.session_id}${pin?' · pinned':''}`,'caption');place(event);
}
function place(){panel.hidden=false;}
document.querySelector('#unpin').onclick=()=>{pinned=false;hovered=null;panel.hidden=true;};
document.addEventListener('keydown',e=>{if(e.key==='Escape'){pinned=false;panel.hidden=true;hovered=null;}});
function bind(target,node,edge,child){const show=(e,pin=false)=>{const current=nodes.get(key(node.session_id,node.id))||node;showNode(current,e,pin,current.edges?.[child]||edge);};target.addEventListener('pointerenter',e=>show(e));target.addEventListener('focus',e=>show(e));target.addEventListener('click',e=>show(e,true));target.addEventListener('keydown',e=>{if(e.key==='Enter')show(e,true);});}
function rail(){
 const list=document.querySelector('#agents');
 for(const s of sessions.values()){
  let b=[...list.children].find(b=>b.dataset.session===s.session_id);
  if(!b){b=document.createElement('button');b.className='agent-entry';b.dataset.session=s.session_id;b.append(document.createElement('strong'),document.createElement('span'),document.createElement('small'));b.onclick=()=>{following=following===s.session_id?null:s.session_id;if(following){openBuffers.add(s.session_id);reveal(sessions.get(s.session_id));}schedule();};list.append(b);}
  const who=s.actor&&s.actor!=='Agent'?s.actor:(s.kind==='evaluator'?'PVSio':'Proof thread');
  b.children[0].textContent=who+' · '+s.session_id;
  b.children[1].textContent=(s.formula||s.session_id).split('#').at(-1);
  b.children[2].textContent=s.running?(s.command_label||s.command||'Working…'):s.proof_result==='proved'?'✓ QED':s.closed?'Closed':s.kind==='evaluator'?(s.evaluation?.pvsResult||'Ready'):(s.command_label||s.command||'Ready');
  b.classList.toggle('running',!!s.running);b.classList.toggle('following',following===s.session_id);b.setAttribute('aria-pressed',String(following===s.session_id));b.title='Jump to this session and follow its current step. Click again to stop following.';
 }
}

function reveal(s){folded.delete(s.session_id);}
function button(label,action,cls){const b=document.createElement('button');b.type='button';b.textContent=label;if(cls)b.className=cls;b.onclick=action;return b;}
function foldThread(id,close){if(close){folded.add(id);if(following===id)following=null;}else folded.delete(id);schedule();}
const overview=document.createElement('nav');overview.className='overview';overview.setAttribute('aria-label','Thread visibility');
overview.append(button('Collapse threads',()=>{for(const id of sessions.keys())foldThread(id,true);}),button('Show threads',()=>{folded.clear();schedule();}),button('Collapse completed',()=>{for(const s of sessions.values())if(s.proof_result==='proved'||s.closed)foldThread(s.session_id,true);}));forest.prepend(overview);
function stopFollowing(){following=null;rail();schedule();}
forest.addEventListener('wheel',stopFollowing,{passive:true});
forest.addEventListener('pointerdown',e=>{if(!e.target.closest('.proof-controls'))stopFollowing();});
forest.addEventListener('touchmove',stopFollowing,{passive:true});
forest.addEventListener('keydown',e=>{if(['ArrowUp','ArrowDown','PageUp','PageDown','Home','End'].includes(e.key))stopFollowing();});
function pane(s){
 if(panes.has(s.session_id))return panes.get(s.session_id);
 if(!knownThreads.has(s.session_id)){knownThreads.add(s.session_id);if(s.proof_result==='proved'||s.closed)folded.add(s.session_id);}
 document.querySelector('#empty')?.remove();
 const box=document.createElement('section');box.className='attempt';box.setAttribute('aria-label',s.session_id);
 const heading=document.createElement('h2'),toggle=button('',()=>foldThread(s.session_id,!folded.has(s.session_id)),'thread-toggle');
 const name=document.createElement('strong');name.textContent=(s.formula||s.session_id).split('#').at(-1);
 const actor=document.createElement('span'),status=document.createElement('span');status.className='thread-status';toggle.append(name,actor,status);heading.append(toggle);
 const controls=document.createElement('nav');controls.className='proof-controls';controls.setAttribute('aria-label','Proof navigation '+s.session_id);
 const workspace=document.createElement('div');workspace.className='proof-workspace';
 const viewport=document.createElement('div');viewport.className='proof-explorer';viewport.tabIndex=0;viewport.setAttribute('aria-label','Proof construction '+s.session_id);
 const list=document.createElement('ul');list.className='proof-list';viewport.append(list);
 const more=button('Show more steps',()=>{p.limit+=200;p.signature=null;schedule();},'more-steps');viewport.append(more);more.hidden=true;
 const p={box,actor,status,toggle,controls,workspace,viewport,list,more,rows:new Map(),limit:200};
 const follow=button('Follow',()=>{following=following===s.session_id?null:s.session_id;if(following)reveal(sessions.get(s.session_id));schedule();});follow.title='Expand to the current step and keep following this thread';p.followButton=follow;
 const collapse=button('Collapse steps',()=>{stopFollowing();for(const k of opened)if(k.startsWith(s.session_id+':'))opened.delete(k);schedule();});
 const consoleToggle=button('*pvs*',()=>{if(openBuffers.has(s.session_id))openBuffers.delete(s.session_id);else openBuffers.add(s.session_id);schedule();},'buffer-toggle');consoleToggle.setAttribute('aria-label','Show PVS buffer for '+s.session_id);p.consoleToggle=consoleToggle;
 controls.append(follow,collapse,consoleToggle);
 const buffer=document.createElement('section');buffer.className='thread-buffer';buffer.setAttribute('aria-label','PVS buffer '+s.session_id);
 const bufferHead=document.createElement('header');bufferHead.className='buffer-head';
 const state=document.createElement('div');state.className='buffer-state';
 const cmd=document.createElement('pre');cmd.className='buffer-command';cmd.setAttribute('aria-label','Most recent command');
 bufferHead.append(cmd,state);
 const body=document.createElement('div');body.className='buffer-body';body.tabIndex=0;
 const seq=document.createElement('pre');seq.className='buffer-sequent';const out=document.createElement('pre');out.className='buffer-output';
 const history=document.createElement('details'),summary=document.createElement('summary'),transcript=document.createElement('pre');summary.textContent='Recent *pvs* transcript';history.append(summary,transcript);
 const limit=document.createElement('div');limit.className='buffer-limit';body.append(seq,out,history,limit);buffer.append(bufferHead,body);
 Object.assign(p,{buffer,bufferBody:body,bufferState:state,bufferCommand:cmd,bufferSequent:seq,bufferOutput:out,bufferTranscript:transcript,bufferLimit:limit});
 workspace.append(viewport,buffer);box.append(heading,controls,workspace);forest.append(box);panes.set(s.session_id,p);return p;
}
function renderExplorer(s,p){
 let model=indexes.get(s.session_id);
 if(!model){model=ProofExplorer.index([...nodes.values()].filter(n=>n.session_id===s.session_id));indexes.set(s.session_id,model);}
 if(following===s.session_id){const path=ProofExplorer.follow(model,s.observer_id,opened,s.session_id+':',p.limit);p.limit=path.limit;}
 const view=ProofExplorer.visible(model,opened,s.session_id+':',p.limit,s.proof_result==='proved'),visible=new Set(view.rows.map(r=>r.key));
 let focus=model.byId.get(s.observer_id),seen=new Set();
 while(focus&&!visible.has(key(s.session_id,focus.id))&&!seen.has(focus.id)){seen.add(focus.id);focus=model.byId.get(focus.parent);}
 for(const [k,r] of p.rows)if(!visible.has(k)){r.li.remove();p.rows.delete(k);}
 for(const row of view.rows){
  let r=p.rows.get(row.key);
  if(!r){
   const li=document.createElement('li'),control=button('',()=>{const current=r.data;if(!current.expandable&&current.type!=='group'){showNode(current.node,null);return;}if(opened.has(current.key))opened.delete(current.key);else opened.add(current.key);schedule();},'proof-block');
   const goal=document.createElement('span'),label=document.createElement('span'),code=document.createElement('code'),meta=document.createElement('span');goal.className='goal-label';label.className='step-label';code.className='step-code';meta.className='step-meta';control.append(goal,label,code,meta);
   const children=document.createElement('ul');children.className='proof-list';li.append(control,children);r={li,control,goal,label,code,meta,children};p.rows.set(row.key,r);
   const inspect=e=>{const d=r.data;if(d.type==='command')showNode(nodes.get(key(s.session_id,d.node.id))||d.node,e);};control.addEventListener('pointerenter',inspect);control.addEventListener('focus',inspect);
  }
  r.data=row;
  const n=row.node,isCommand=row.type==='command',closed=isCommand&&n.status==='!'&&!row.links.active.length;
  r.li.className='proof-item'+(row.history?' history':'')+(row.complete?' complete':'');r.control.className='proof-block'+(!isCommand?' group-block':'')+(row.complete?' qed':'')+(focus?.id===n?.id&&isCommand?' current':'');
  r.control.dataset.node=isCommand?n.id:'';r.control.classList.toggle('has-label',!!n?.command_label);
  const expandable=isCommand?row.expandable:true;
  if(expandable)r.control.setAttribute('aria-expanded',String(row.open));else r.control.removeAttribute('aria-expanded');
  r.children.hidden=!row.open;
  r.goal.textContent=isCommand?(n.label?.includes('.')?n.label.slice(n.label.indexOf('.')+1):''):'';
  r.label.textContent=isCommand?ProofExplorer.title(n,row.complete):row.title;
  r.code.textContent=isCommand&&n.command_label?(n.input_command||n.command||''):'';r.code.hidden=true;
  const count=isCommand?row.links.active.length:0;
  r.meta.textContent=isCommand?[closed?'✓ QED':count>1?count+' subgoals':count===1?'':'',row.links.implementation.length?'⋯':'',focus?.id===n.id?'current':''].filter(Boolean).join(' · '):row.complete?'✓':'';
  const parent=row.parent?p.rows.get(row.parent)?.children:p.list;
  // Preserve DOM identities and keyboard focus when a live snapshot changes.
  if(parent&&r.li.parentElement!==parent)parent.append(r.li);
 }
 // Reorder only when native history actually changed, never replace open blocks.
 const groups=new Map();for(const row of view.rows){const parent=row.parent?p.rows.get(row.parent)?.children:p.list;if(!groups.has(parent))groups.set(parent,[]);groups.get(parent).push(p.rows.get(row.key).li);}
 for(const [parent,items] of groups)items.forEach((li,i)=>{if(parent.children[i]!==li)parent.insertBefore(li,parent.children[i]||null);});
 p.more.hidden=!view.more;
 if(!view.rows.length){if(!p.empty){p.empty=document.createElement('p');p.empty.className='caption';p.empty.textContent='Waiting for the first proof step…';p.viewport.prepend(p.empty);}}else if(p.empty){p.empty.remove();p.empty=null;}
 p.focus=focus&&p.rows.get(key(s.session_id,focus.id))?.control;
}
function draw(){
 dirty=false;rail();if(following&&sessions.has(following))reveal(sessions.get(following));
 for(const s of sessions.values()){
  const p=pane(s),isFolded=folded.has(s.session_id),bufferOpen=openBuffers.has(s.session_id)||s.kind==='evaluator';
  p.followButton.textContent=following===s.session_id?'Following':'Follow';p.followButton.setAttribute('aria-pressed',String(following===s.session_id));
  p.actor.textContent=s.actor&&s.actor!=='Agent'?s.actor:'';p.box.classList.toggle('selected',following===s.session_id);p.box.classList.toggle('folded',isFolded);
  p.toggle.setAttribute('aria-expanded',String(!isFolded));p.toggle.setAttribute('aria-label',(isFolded?'Expand':'Collapse')+' thread '+s.session_id);
  p.status.textContent=s.proof_result==='proved'?'✓ QED':s.running?'Working…':s.closed?'Closed':'';p.status.classList.toggle('complete',s.proof_result==='proved');
  p.workspace.hidden=isFolded;p.controls.hidden=isFolded||s.kind==='evaluator';p.viewport.hidden=s.kind==='evaluator';p.buffer.hidden=!bufferOpen;p.workspace.classList.toggle('with-buffer',bufferOpen&&s.kind!=='evaluator');p.consoleToggle.setAttribute('aria-pressed',String(bufferOpen));
  if(isFolded)continue;
  if(bufferOpen)renderBuffer(s,p);
  if(s.kind!=='evaluator')renderExplorer(s,p);
 }
 const p=panes.get(following);
 if(p){
  const target=p.focus||p.box;target.scrollIntoView({block:'nearest',inline:'nearest'});
  if(p.focus){
   const row=p.focus.getBoundingClientRect(),view=p.viewport.getBoundingClientRect();
   // A row can be wider than a narrow split pane. Keep its disclosure reachable.
   if(row.left<view.left+8||row.right>view.right-8)p.viewport.scrollLeft+=row.left-view.left-8;
  }
 }
}
function renderBuffer(s,p){
 const b=buffers.get(s.session_id),n=nodes.get(key(s.session_id,s.observer_id))||[...nodes.values()].reverse().find(n=>n.session_id===s.session_id&&!n.expansion&&n.sequent);
 const running=b?.status==='running'||s.running;
 p.bufferState.textContent=s.uncertain?'Disconnected · last observed state':running?'Running · last returned sequent':b?.status==='proved'||s.proof_result==='proved'?'Q.E.D.':b?.status==='interrupted'?'Interrupted':s.closed?'Closed':s.kind==='evaluator'?'PVSio':'Rule?';
 const command=ProofExplorer.latestCommand(s,b,n);
 p.bufferCommand.textContent=command?(s.kind==='evaluator'?'PVSio> ':'Rule? ')+command:'No command applied yet';
 const fallback=n?.sequent?[(n.label||''),...(n.sequent.antecedents||[]).map((f,i)=>`[−${i+1}] ${f}`),'  |-------',...(n.sequent.succedents||[]).map((f,i)=>`[${i+1}] ${f}`)].join('\n\n'):'';
 const seq=b?.sequent||fallback||(s.kind==='evaluator'?'':s.closed?'No retained sequent for this closed thread.':'Waiting for this thread’s first sequent…');
 if(p.bufferSequent.textContent!==seq)p.bufferSequent.textContent=seq;
 const out=b?.output||s.evaluation?.pvsResult||'';
 if(p.bufferOutput.textContent!==out){const atEnd=p.bufferBody.scrollTop+p.bufferBody.clientHeight>=p.bufferBody.scrollHeight-32;p.bufferOutput.textContent=out;if(atEnd)p.bufferBody.scrollTop=p.bufferBody.scrollHeight;}
 if(p.bufferTranscript.textContent!==(b?.transcript||''))p.bufferTranscript.textContent=b?.transcript||'';
 p.bufferLimit.textContent=b?.truncated?'Earlier or oversized text was truncated; the proof is unchanged.':!b&&connectionState?.buffers===false?'This worker predates live output capture; showing available sequent snapshots.':!b&&s.closed?'Capture started after this command; earlier output is unavailable.':'';
}
function schedule(){if(!dirty){dirty=true;setTimeout(()=>requestAnimationFrame(draw),80);}}
window.addEventListener('resize',schedule);
function notice(){document.querySelector('#notice').textContent=connectionState?.state==='reconnecting'?'PVS disconnected · reconnecting automatically…':observationError?'Observation paused: '+observationError:latestGap?'Some earlier states are outside the retained history.':connectionState?.generation>1?'Connected to restarted PVS · fresh proof history.':'';}
function accept(message){
 const {kind,value}=message;
 if(kind==='snapshot'){
  const generation=value.connection?.generation;
  if(displayGeneration!==null&&generation!==displayGeneration){opened.clear();folded.clear();knownThreads.clear();openBuffers.clear();following=null;pinned=false;hovered=null;panel.hidden=true;}
  displayGeneration=generation;connectionState=value.connection||null;
  for(const p of panes.values())p.box.remove();panes.clear();indexes.clear();document.querySelector('#agents').replaceChildren();
  sessions=new Map(value.sessions.map(s=>[s.session_id,s]));nodes=new Map(value.nodes.map(n=>[key(n.session_id,n.id),n]));buffers=new Map((value.buffers||[]).map(b=>[b.session_id,b]));
  strategies=value.strategies;latestGap=value.gaps;observationError=value.capture_error||(value.closed?'Viewer closed':null);rail();
 }else if(kind==='node'){nodes.set(key(value.session_id,value.id),value);indexes.delete(value.session_id);}
 else if(kind==='session')sessions.set(value.session_id,value);
 else if(kind==='buffer')buffers.set(value.session_id,value);
 else if(kind==='connection'){connectionState=value;if(value.state==='connected')observationError=null;}
 else if(kind==='strategies'){strategies=value;rail();}
 else if(kind==='gap')latestGap=value;
 else if(kind==='remove'){const old=nodes.get(value.key);nodes.delete(value.key);if(old)indexes.delete(old.session_id);latestGap=value.gaps;}
 else if(kind==='error')observationError=value;
 notice();schedule();
}
const stream=new EventSource('events');stream.onmessage=e=>accept(JSON.parse(e.data));stream.onerror=()=>{document.querySelector('#notice').textContent='Viewer disconnected. Reconnecting…';};stream.onopen=notice;

}
