const {test}=require('node:test');
const assert=require('node:assert/strict');
const {index,visible,latestCommand,follow}=require('../web/app.js');
const node=(id,parent,children=[],extra={})=>({id,parent,children,label:id,command:`(${id})`,...extra});
test('subgoals, implementation and abandoned attempts remain separate and lazy',()=>{
 const model=index([node('split',null,['a','b'],{edges:{a:{},b:{},old:{},impl:{expansion:true}}}),node('a','split'),node('b','split'),node('old','split'),node('impl','split',['primitive'],{expansion:true}),node('primitive','impl')]);
 const open=new Set();assert.deepEqual(visible(model,open,'s:').rows.map(r=>r.key),['s:split']);
 open.add('s:split');const rows=visible(model,open,'s:').rows;
 assert.deepEqual(rows.map(r=>r.key),['s:split','s:split:implementation','s:a','s:b','s:split:history']);
 assert.deepEqual(rows[0].links.active,['a','b']);
 open.add('s:split:implementation');assert(visible(model,open,'s:').rows.some(r=>r.key==='s:impl'));
 assert(!visible(model,open,'s:').rows.some(r=>r.key==='s:primitive'));
 open.add('s:split:history');assert(visible(model,open,'s:').rows.find(r=>r.key==='s:old').history);
});
test('deep histories are bounded and closed implementations are not traversed',()=>{
 const rows=Array.from({length:6000},(_,i)=>node('n'+i,i?'n'+(i-1):null,i<5999?['n'+(i+1)]:[]));
 const model=index(rows),open=new Set(rows.map(n=>'s:'+n.id));
 assert.equal(visible(model,new Set(),'s:').rows.length,1);
 const view=visible(model,open,'s:');assert.equal(view.rows.length,200);assert.equal(view.more,true);
});
test('reparented nodes are not duplicated and cycles do not recurse forever',()=>{
 const m=index([node('a',null,['c']),node('b',null,['c']),node('c','b')]);
 assert.deepEqual(m.links.get('a').active,[]);assert.deepEqual(m.links.get('b').active,['c']);
 const cyclic=index([node('a','b',['b']),node('b','a',['a'])]);
 assert.equal(visible(cyclic,new Set(['s:a','s:b','s:goal:a']),'s:').rows.length,3);
});
test('most recent running command wins over an older captured buffer',()=>{
 assert.equal(latestCommand({running:true,command:'(split)'},{command:'(skosimp*)'}),'(split)');
 assert.equal(latestCommand({running:false,command:'(split)'},{command:'(undo)'}),'(undo)');
});

test('retention gaps do not spill primitive fragments into the top level',()=>{
 const m=index([node('root',null),node('lost-child','evicted-parent'),node('internal','other-evicted-parent',[],{expansion:true})]);
 const view=visible(m,new Set(),'s:');
 assert.deepEqual(view.rows.map(r=>r.key),['s:root','s:_retained:fragments']);
});

test('missing ancestry is grouped by every enclosing PVS goal, never flattened',()=>{
 const rows=[node('top','missing',[],{label:'lemma'}),node('deep','missing-deep',[],{label:'lemma.1.1.1.2.1.2'}),node('sibling','missing-other',[],{label:'lemma.2'})];
 const m=index(rows),open=new Set([...m.goals.keys()].map(g=>'s:goal:'+g));
 const view=visible(m,open,'s:').rows;
 assert.equal(view.find(r=>r.key==='s:deep').parent,'s:goal:lemma.1.1.1.2.1.2');
 assert.equal(view.find(r=>r.key==='s:goal:lemma.1.1.1.2.1.2').parent,'s:goal:lemma.1.1.1.2.1');
 assert.deepEqual(view.filter(r=>r.parent===null).map(r=>r.key),['s:goal:lemma']);
 assert.equal(visible(m,new Set(),'s:').rows.length,1);
});
test('child parent pointers retain hierarchy even when the parent edge snapshot is absent',()=>{
 const m=index([node('root',null),node('child','root',[],{label:'root.1'})]);
 assert.equal(m.fragments.length,0);
 assert(m.links.get('root').history.includes('child'));
});

test('Follow opens the current primitive path without opening sibling branches',()=>{
 const m=index([node('root',null,['other'],{edges:{impl:{expansion:true}}}),node('other','root',['hidden']),node('hidden','other'),node('impl','root',['cursor'],{expansion:true}),node('cursor','impl')]);
 const opened=new Set();const result=follow(m,'cursor',opened,'s:');
 assert.equal(result.target,'cursor');
 assert.deepEqual([...opened].sort(),['s:impl','s:root','s:root:implementation']);
 assert(visible(m,opened,'s:',result.limit).rows.some(r=>r.key==='s:cursor'));
 assert(!visible(m,opened,'s:').rows.some(r=>r.key==='s:hidden'));
});
test('Follow opens retained goal prefixes and historical edges after undo',()=>{
 const m=index([node('root',null),node('fragment','lost',[],{label:'lemma.1.2',edges:{cursor:{}}}),node('cursor','fragment')]);
 const opened=new Set();const result=follow(m,'cursor',opened,'s:');
 for(const k of ['s:_retained:fragments','s:goal:lemma','s:goal:lemma.1','s:goal:lemma.1.2','s:fragment','s:fragment:history'])assert(opened.has(k),k);
 assert(visible(m,opened,'s:',result.limit).rows.some(r=>r.key==='s:cursor'));
});
test('Follow reaches beyond pagination and tracks new cursor nodes',()=>{
 const rows=[node('root',null,Array.from({length:230},(_,i)=>'n'+i)),...Array.from({length:230},(_,i)=>node('n'+i,'root'))];
 let m=index(rows);const opened=new Set();let result=follow(m,'n229',opened,'s:');
 assert(result.limit>200);assert(visible(m,opened,'s:',result.limit).rows.some(r=>r.key==='s:n229'));
 rows[230].children=['next'];rows.push(node('next','n229'));m=index(rows);
 result=follow(m,'next',opened,'s:',result.limit);
 assert(visible(m,opened,'s:',result.limit).rows.some(r=>r.key==='s:next'));
 const before=[...opened];assert.equal(follow(m,'not-yet-received',opened,'s:').target,null);assert.deepEqual([...opened],before);
});

test('commands on one goal form a flat sequence and only split branches indent',()=>{
 const m=index([node('a',null,['b'],{label:'lemma'}),node('b','a',['split'],{label:'lemma'}),node('split','b',['left','right'],{label:'lemma'}),node('left','split',['next'],{label:'lemma.1'}),node('next','left',[],{label:'lemma.1'}),node('right','split',[],{label:'lemma.2'})]);
 let rows=visible(m,new Set(),'s:').rows;
 assert.deepEqual(rows.map(r=>[r.key,r.parent]),[['s:a',null],['s:b',null],['s:split',null]]);
 rows=visible(m,new Set(['s:split']),'s:').rows;
 assert.deepEqual(rows.filter(r=>['s:left','s:next','s:right'].includes(r.key)).map(r=>r.parent),['s:split','s:split','s:split']);
});
test('closed branch colors its entire sequence while its open sibling stays neutral',()=>{
 const rows=[node('split',null,['a','open']),node('a','split',['b'],{label:'lemma.1'}),node('b','a',[],{label:'lemma.1',status:'!'}),node('open','split')];
 let m=index(rows),view=visible(m,new Set(['s:split']),'s:').rows;
 assert(view.find(r=>r.key==='s:a').complete);assert(view.find(r=>r.key==='s:b').complete);
 assert(!view.find(r=>r.key==='s:split').complete);assert(!view.find(r=>r.key==='s:open').complete);
 rows[2].status='OPEN';m=index(rows);assert(!m.completed.has('a'),'undo must clear ancestor completion');
});
test('completion ignores abandoned successes and missing subgoals',()=>{
 const m=index([node('root',null,['missing'],{edges:{old:{}}}),node('old','root',[],{status:'!'})]);
 assert(!m.completed.has('root'));
 const view=visible(m,new Set(['s:root','s:root:history']),'s:',200,true).rows;
 assert(view.find(r=>r.key==='s:root').complete);
 assert(!view.find(r=>r.key==='s:root:history').complete,'whole-proof success must not certify abandoned attempts');
});
test('closed goal groups and primitive subproof lines inherit green completion',()=>{
 const m=index([node('fragment','lost',[],{label:'lemma.1',status:'!',edges:{impl:{expansion:true}}}),node('impl','fragment',['p'],{label:'lemma.1',expansion:true}),node('p','impl',[],{label:'lemma.1'})]);
 const opened=new Set(['s:goal:lemma','s:goal:lemma.1','s:fragment','s:fragment:implementation']);
 const rows=visible(m,opened,'s:').rows;
 assert(rows.length>=6);assert(rows.every(r=>r.complete));
});
