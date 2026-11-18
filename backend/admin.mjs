// Painel de operacoes. NUNCA confie em senha no APK ou no navegador.
// Cloudflare Access autentica. ADMIN_EMAIL (secret) define o administrador.
function reply(data,status=200) {
  return new Response(JSON.stringify(data),{
    status,headers:{'Content-Type':'application/json; charset=utf-8',
      'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}
  });
}
function deny() {return reply({error:'Acesso administrativo negado.'},403);}
function validAdminPost(request,url) {
  return request.headers.get('Origin')===url.origin &&
    request.headers.get('Content-Type')?.startsWith('application/json');
}
async function githubApkDownloads(env) {
  const owner=env.GITHUB_OWNER||'hayslann';
  const repo=env.GITHUB_REPO||'Lembreai';
  const tag=env.GITHUB_RELEASE_TAG||'teste-android';
  try {
    const response=await fetch(`https://api.github.com/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/releases/tags/${encodeURIComponent(tag)}`,{
      headers:{Accept:'application/vnd.github+json','User-Agent':'LembreAI-admin'},
      signal:AbortSignal.timeout(5000),
    });
    if(!response.ok)return null;
    const release=await response.json();
    return Array.isArray(release.assets)?release.assets.reduce((n,a)=>n+(Number(a.download_count)||0),0):null;
  } catch (_) {return null;}
}
export async function authenticateAdmin(env,ctx) {
  if (!env.ADMIN_EMAIL || typeof env.ADMIN_EMAIL!=='string' || !ctx?.access) return null;
  try {
    const identity=await ctx.access.getIdentity();
    const email=identity?.email?.trim().toLowerCase();
    const expected=env.ADMIN_EMAIL.trim().toLowerCase();
    return email && email===expected ? email : null;
  } catch(_) {return null;}
}

const html=`<!doctype html>
<html lang="pt-br"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>LembreAI | Administração</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}
body{font:15px system-ui,Arial,sans-serif;background:#100923;color:#faf8ff;margin:0;padding:24px}
main{max-width:1060px;margin:auto}.top{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
h1{font-size:26px;margin:0}.subtitle{color:#bcb2d3}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(185px,1fr));gap:12px;margin:22px 0}
article,section{background:#241539;border:1px solid #45315f;border-radius:16px;padding:20px}
.number{font-size:26px;font-weight:700;margin-top:8px;color:#d9baff}table{width:100%;border-collapse:collapse;font-size:13px}
td,th{padding:12px 8px;text-align:left;border-bottom:1px solid #392d4c}
th{color:#cdbddd}button{cursor:pointer;background:#a660ff;color:#180725;border:0;border-radius:10px;padding:12px;font-weight:700}
input{background:#130a26;border:1px solid #685487;color:white;border-radius:9px;padding:10px;max-width:100%;width:280px}
form{display:flex;gap:10px;flex-wrap:wrap;align-items:center}section{margin-top:18px;overflow-x:auto}
small,.muted{color:#baaccc}#status{margin:15px 0;color:#d8caff}
</style></head><body><main>
<div class="top"><div><h1>🔔 LembreAI — Central do administrador</h1>
<p class="subtitle">Informações agregadas. Sem conteúdo das mensagens ou da agenda.</p></div>
<button id="refresh">Atualizar dados</button></div><div id="status">Carregando...</div>
<div class="grid">
<article>Requisições de IA<div class="number" id="requests">—</div></article>
<article>Concluídas<div class="number" id="successes">—</div></article>
<article>Falhas<div class="number" id="errors">—</div></article>
<article>Tokens de entrada<div class="number" id="inTokens">—</div></article>
<article>Tokens de saída<div class="number" id="outTokens">—</div></article>
<article>Estimativa em USD (tabela paga)<div class="number" id="estimatedCost">—</div></article>
<article>Usuários identificados<div class="number" id="usersCount">—</div></article>
<article>Ativos nos últimos 5 min<div class="number" id="onlineUsers">—</div></article>
<article>Contas bloqueadas<div class="number" id="blockedUsers">—</div></article>
<article>Créditos ativos<div class="number" id="creditsActive">—</div></article>
<article>Downloads do APK no GitHub<div class="number" id="downloads">—</div></article>
</div>
<section><h2>Consumo de IA — últimos 30 dias</h2>
<p class="muted">Custos de Gemini/Cloudflare: consulte as faturas reais.
Sem preço por token configurado, não calculamos um valor fictício.</p>
<table><thead><tr><th>Dia (UTC)</th><th>Pedidos</th><th>Sucesso</th><th>Falhas</th><th>Entrada</th><th>Saída</th><th>Imagens</th></tr></thead><tbody id="days"></tbody></table>
</section>
<section><h2>Usuários, créditos e planos</h2>
<p class="muted">O app beta guarda compromissos no celular.
Identificação individual depende do Firebase Authentication.
Somente créditos de contas verificadas poderão ser lançados.</p>
<table><thead><tr><th>ID</th><th>E-mail</th><th>Plano</th><th>Status</th><th>Créditos ativos</th><th>Pedidos IA</th><th>Tokens entrada</th><th>Tokens saída</th><th>Último uso</th><th>Custo estimado (USD)</th><th>Ação</th></tr></thead>
<tbody id="users"></tbody></table></section>
<section><h2>Administrar créditos com auditoria</h2>
<form id="grant"><input required id="uid" placeholder="UID autenticado" autocomplete="off">
<input required id="points" type="number" min="1" max="1000" placeholder="Créditos (1–1000)">
<select id="creditAction" aria-label="Operação de crédito"><option value="add">Adicionar</option><option value="remove">Retirar</option></select>
<button type="submit">Aplicar alteração</button></form>
<p class="muted">Apenas contas cadastradas. Retiradas respeitam o saldo e ficam registradas com administrador, usuário e data.</p></section>
<section><h2>Auditoria administrativa</h2>
<table><thead><tr><th>Data</th><th>Administrador</th><th>E-mail do usuário</th><th>UID</th><th>Ação</th><th>Quantidade</th></tr></thead>
<tbody id="actions"></tbody></table></section>
<section><h2>Histórico de contratações verificadas</h2>
<table><thead><tr><th>Usuário</th><th>Plano</th><th>Status</th><th>Valor</th><th>Data</th></tr></thead>
<tbody id="purchases"></tbody></table>
<p class="muted">Pagamentos não são presumidos. Somente transações validadas pelo servidor aparecem aqui.</p></section>
</main><script>
const el=(id)=>document.getElementById(id);
const show=(x)=>x==null?'—':String(x);
const fmt=(x)=>Number(x||0).toLocaleString('pt-BR');
const cell=(value)=>{const td=document.createElement('td');td.textContent=show(value);return td;};
function table(id,rows,fields){el(id).replaceChildren();
 for(const entry of rows){const tr=document.createElement('tr');
  for(const name of fields)tr.appendChild(cell(entry[name]));el(id).appendChild(tr);
 }}
async function get(path){const res=await fetch(path,{credentials:'same-origin',cache:'no-store'});
 const body=await res.json();if(!res.ok)throw Error(body.error||'Falha de conexão');return body;}
async function load(){
 el('status').textContent='Consultando banco de dados...';
 try{
 const [s,u,p,a]=await Promise.all([
   get('/admin/api/summary'),get('/admin/api/users'),get('/admin/api/purchases'),get('/admin/api/actions')]);
 for(const id of ['requests','successes','errors','inTokens','outTokens','usersCount']) {
  const prop={inTokens:'input_tokens',outTokens:'output_tokens',usersCount:'users'}[id]||id;
  el(id).textContent=fmt(s.total[prop]);
 }
 el('estimatedCost').textContent=s.total.estimated_paid_cost_usd==null?'Não configurado':
   '$ '+Number(s.total.estimated_paid_cost_usd).toFixed(5);
 el('onlineUsers').textContent=fmt(s.total.active_last_5m);
 el('blockedUsers').textContent=fmt(s.total.blocked_users);
 el('creditsActive').textContent=fmt(s.total.active_credits);
 el('downloads').textContent=s.total.apk_downloads==null?'Indisponível':fmt(s.total.apk_downloads);
 table('days',s.days,['day','requests','successes','errors','input_tokens','output_tokens','image_requests']);
 const userBody=el('users');userBody.replaceChildren();
 for(const user of u.users){const tr=document.createElement('tr');
  for(const value of [user.uid,user.email,user.plan,user.account_status,user.credit_balance,user.requests,user.input_tokens,user.output_tokens,user.last_active_at,user.estimated_paid_cost_usd])tr.appendChild(cell(value));
  const action=document.createElement('td');const button=document.createElement('button');
  button.textContent=user.account_status==='blocked'?'Desbloquear':'Bloquear';button.dataset.uid=user.uid;
  button.onclick=()=>setAccountStatus(user.uid,user.account_status==='blocked'?'active':'blocked');
  action.appendChild(button);tr.appendChild(action);userBody.appendChild(tr);
 }
 table('purchases',p.purchases,['user_uid','plan','status','amount_display','created_at']);
 table('actions',a.actions,['created_at','actor_email','target_email','target_uid','action_type','amount']);
 el('status').textContent='Dados atualizados com segurança.';
 }catch(e){el('status').textContent=e.message;}
}
el('refresh').onclick=load;
el('grant').onsubmit=async(e)=>{
 e.preventDefault();
 const uid=el('uid').value.trim();const credits=Number(el('points').value);const operation=el('creditAction').value;
 if(!confirm((operation==='add'?'Adicionar ':'Retirar ')+credits+' créditos '+(operation==='add'?'para ':'de ')+uid+'?'))return;
 try {
  const res=await fetch('/admin/api/credits',{method:'POST',credentials:'same-origin',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({uid,credits,operation})});
  const value=await res.json();if(!res.ok)throw Error(value.error||'Falha');
  el('status').textContent='Alteração de créditos registrada no livro de auditoria.';
  await load();
 }catch(err){el('status').textContent=err.message;}
};
async function setAccountStatus(uid,status){
 const label=status==='blocked'?'bloquear':'desbloquear';
 if(!confirm('Deseja '+label+' a conta '+uid+'?'))return;
 try{const res=await fetch('/admin/api/users/status',{method:'POST',credentials:'same-origin',
   headers:{'Content-Type':'application/json'},body:JSON.stringify({uid,status})});
   const value=await res.json();if(!res.ok)throw Error(value.error||'Falha');
   el('status').textContent='Status da conta atualizado e auditado.';await load();
 }catch(err){el('status').textContent=err.message;}
}
load();
</script></body></html>`;

export async function handleAdmin(request,env,ctx) {
  const email=await authenticateAdmin(env,ctx);
  if(!email)return deny();
  if(!env.DB)return reply({error:'Banco administrativo não configurado.'},503);
  const url=new URL(request.url);
  const path=url.pathname;
  if(request.method==='GET' && path==='/admin') {
    return new Response(html,{headers:{'Content-Type':'text/html; charset=utf-8',
      'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
      'Content-Security-Policy':"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
      'Referrer-Policy':'no-referrer'}});
  }
  if(request.method==='GET' && path==='/admin/api/summary') {
    const days=(await env.DB.prepare('SELECT day,requests,successes,errors,input_tokens,output_tokens,image_requests FROM usage_daily ORDER BY day DESC LIMIT 30').all()).results;
    const totals=await env.DB.prepare('SELECT COALESCE(SUM(requests),0) requests,COALESCE(SUM(successes),0) successes,COALESCE(SUM(errors),0) errors,COALESCE(SUM(input_tokens),0) input_tokens,COALESCE(SUM(output_tokens),0) output_tokens FROM usage_daily').first();
    const count=await env.DB.prepare('SELECT COUNT(*) AS count FROM users').first();
    const presence=await env.DB.prepare(`SELECT
      SUM(CASE WHEN account_status='blocked' THEN 1 ELSE 0 END) blocked_users,
      SUM(CASE WHEN account_status='active' AND last_active_at>=datetime('now','-5 minutes') THEN 1 ELSE 0 END) active_last_5m
      FROM users`).first();
    const creditTotal=await env.DB.prepare(`SELECT COALESCE(SUM(delta),0) active_credits FROM credit_ledger
      WHERE expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP`).first();
    const downloads=await githubApkDownloads(env);
    const inputRate=Number(env.GEMINI_INPUT_USD_PER_MTOK);
    const outputRate=Number(env.GEMINI_OUTPUT_USD_PER_MTOK);
    const configured=env.GEMINI_INPUT_USD_PER_MTOK!=null && env.GEMINI_OUTPUT_USD_PER_MTOK!=null &&
      Number.isFinite(inputRate) && Number.isFinite(outputRate) &&
      inputRate>=0 && outputRate>=0 && inputRate<=100 && outputRate<=100;
    const estimatedCost=configured ?
      Math.round((Number(totals.input_tokens||0)*inputRate+
        Number(totals.output_tokens||0)*outputRate)/1000000*100000)/100000 : null;
    return reply({days,total:{...totals,users:count?.count||0,
      active_last_5m:Number(presence?.active_last_5m||0),
      blocked_users:Number(presence?.blocked_users||0),
      active_credits:Number(creditTotal?.active_credits||0),apk_downloads:downloads,
      estimated_paid_cost_usd:estimatedCost}});
  }
  if(request.method==='GET' && path==='/admin/api/users') {
    const rows=(await env.DB.prepare(`SELECT u.uid,u.email,u.plan,
      u.account_status,
      COALESCE((SELECT SUM(c.delta) FROM credit_ledger c WHERE c.user_uid=u.uid
        AND (c.expires_at IS NULL OR datetime(c.expires_at)>CURRENT_TIMESTAMP)),0) credit_balance,
      u.last_active_at,COALESCE(SUM(d.requests),0) requests,
      COALESCE(SUM(d.input_tokens),0) input_tokens,
      COALESCE(SUM(d.output_tokens),0) output_tokens
      FROM users u LEFT JOIN usage_user_daily d ON d.user_uid=u.uid
      GROUP BY u.uid ORDER BY u.last_active_at DESC LIMIT 100`).all()).results;
    const inputRate=Number(env.GEMINI_INPUT_USD_PER_MTOK);
    const outputRate=Number(env.GEMINI_OUTPUT_USD_PER_MTOK);
    const configured=env.GEMINI_INPUT_USD_PER_MTOK!=null && env.GEMINI_OUTPUT_USD_PER_MTOK!=null &&
      Number.isFinite(inputRate) && Number.isFinite(outputRate) &&
      inputRate>=0 && outputRate>=0 && inputRate<=100 && outputRate<=100;
    const users=rows.map(user=>({...user,estimated_paid_cost_usd:configured?
      Math.round((Number(user.input_tokens)*inputRate+Number(user.output_tokens)*outputRate)/1000000*100000)/100000:null}));
    return reply({users});
  }
  if(request.method==='GET' && path==='/admin/api/purchases') {
    const purchases=(await env.DB.prepare('SELECT user_uid,plan,status,price_cents,currency,created_at FROM purchase_records ORDER BY created_at DESC LIMIT 100').all()).results
      .map(p=>({...p,amount_display:p.price_cents==null?'—':new Intl.NumberFormat('pt-BR',{style:'currency',currency:p.currency||'BRL'}).format(Number(p.price_cents)/100)}));
    return reply({purchases});
  }
  if(request.method==='GET' && path==='/admin/api/actions') {
    const actions=(await env.DB.prepare(`SELECT a.created_at,a.actor_email,a.target_uid,
      COALESCE(u.email,'—') target_email,a.action_type,a.amount
      FROM admin_actions a LEFT JOIN users u ON u.uid=a.target_uid
      ORDER BY a.created_at DESC LIMIT 100`).all()).results;
    return reply({actions});
  }
  if(request.method==='POST' && path==='/admin/api/credits') {
    if(!validAdminPost(request,url)) {
      return reply({error:'Origem inválida.'},403);
    }
    let data;
    try {data=await request.json();}catch(_){return reply({error:'JSON inválido.'},400);}
    const uid=data?.uid, credits=data?.credits, operation=data?.operation||'add';
    if(typeof uid!=='string'||uid.length<5||uid.length>150||
       !/^[A-Za-z0-9:_-]+$/.test(uid)||
       !Number.isInteger(credits)||credits<1||credits>1000||!['add','remove'].includes(operation))
      return reply({error:'Usuário ou créditos inválidos.'},400);
    const user=await env.DB.prepare("SELECT uid FROM users WHERE uid=?"+(operation==='add'?" AND account_status='active'":'')).bind(uid).first();
    if(!user)return reply({error:'Usuário não cadastrado/autenticado.'},404);
    const ref='admin:'+crypto.randomUUID();
    if(operation==='add') {
      await env.DB.batch([
        env.DB.prepare("INSERT INTO credit_ledger(user_uid,event_type,delta,reference_id,actor) VALUES(?,'admin_grant',?,?,?)").bind(uid,credits,ref,email),
        env.DB.prepare("UPDATE users SET credit_balance=(SELECT COALESCE(SUM(delta),0) FROM credit_ledger WHERE user_uid=? AND (expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP)) WHERE uid=?").bind(uid,uid),
        env.DB.prepare("INSERT INTO admin_actions(actor_email,target_uid,action_type,amount) VALUES(?,?,'credits_added',?)").bind(email,uid,credits),
      ]);
      return reply({ok:true,reference:ref});
    }
    const buckets=(await env.DB.prepare(`SELECT expires_at,SUM(delta) balance FROM credit_ledger
      WHERE user_uid=? AND (expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP)
      GROUP BY expires_at HAVING SUM(delta)>0
      ORDER BY CASE WHEN expires_at IS NULL THEN 1 ELSE 0 END,datetime(expires_at)`)
      .bind(uid).all()).results||[];
    let remaining=credits;const debits=[];
    for(const bucket of buckets){if(remaining<=0)break;const amount=Math.min(remaining,Number(bucket.balance)||0);
      if(amount>0){debits.push({expiry:bucket.expires_at??null,amount});remaining-=amount;}}
    if(remaining>0)return reply({error:'O usuário não tem créditos ativos suficientes.'},409);
    const statements=debits.map((debit,index)=>env.DB.prepare(`INSERT INTO credit_ledger
      (user_uid,event_type,delta,reference_id,actor,expires_at)
      SELECT ?,'admin_remove',?,?,?,? WHERE (SELECT COALESCE(SUM(delta),0) FROM credit_ledger
       WHERE user_uid=? AND expires_at IS ? AND (expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP))>=?`)
      .bind(uid,-debit.amount,ref+':'+index,email,debit.expiry,uid,debit.expiry,debit.amount));
    const results=await env.DB.batch(statements);
    if(results.reduce((sum,result)=>sum+(result.meta?.changes||0),0)!==debits.length)
      return reply({error:'O saldo mudou durante a operação. Atualize o painel e tente novamente.'},409);
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET credit_balance=(SELECT COALESCE(SUM(delta),0) FROM credit_ledger WHERE user_uid=? AND (expires_at IS NULL OR datetime(expires_at)>CURRENT_TIMESTAMP)) WHERE uid=?").bind(uid,uid),
      env.DB.prepare("INSERT INTO admin_actions(actor_email,target_uid,action_type,amount) VALUES(?,?,'credits_removed',?)").bind(email,uid,-credits),
    ]);
    return reply({ok:true,reference:ref});
  }
  if(request.method==='POST' && path==='/admin/api/users/status') {
    if(!validAdminPost(request,url))return reply({error:'Origem inválida.'},403);
    let data;try{data=await request.json();}catch(_){return reply({error:'JSON inválido.'},400);}
    const uid=data?.uid,status=data?.status;
    if(typeof uid!=='string'||uid.length<5||uid.length>150||! /^[A-Za-z0-9:_-]+$/.test(uid)||
      !['active','blocked'].includes(status))return reply({error:'Usuário ou status inválido.'},400);
    const user=await env.DB.prepare('SELECT uid FROM users WHERE uid=?').bind(uid).first();
    if(!user)return reply({error:'Usuário não encontrado.'},404);
    await env.DB.batch([
      env.DB.prepare('UPDATE users SET account_status=? WHERE uid=?').bind(status,uid),
      env.DB.prepare('INSERT INTO admin_actions(actor_email,target_uid,action_type) VALUES(?,?,?)')
        .bind(email,uid,status==='blocked'?'account_blocked':'account_unblocked'),
    ]);
    return reply({ok:true,status});
  }
  return reply({error:'Rota administrativa não encontrada.'},404);
}

export async function recordUsage(env,{success,inputTokens=0,outputTokens=0,hasImage=false,user=null}={}) {
  if(!env.DB)return;
  const day=new Date().toISOString().slice(0,10);
  const int=(x)=>Number.isSafeInteger(x)&&x>=0?Math.min(x,2000000):0;
  await env.DB.prepare(`INSERT INTO usage_daily(day,requests,successes,errors,input_tokens,output_tokens,image_requests,updated_at)
    VALUES(?,1,?,?,?,?,?,CURRENT_TIMESTAMP)
    ON CONFLICT(day) DO UPDATE SET requests=requests+1,successes=successes+excluded.successes,
      errors=errors+excluded.errors,input_tokens=input_tokens+excluded.input_tokens,
      output_tokens=output_tokens+excluded.output_tokens,image_requests=image_requests+excluded.image_requests,
      updated_at=CURRENT_TIMESTAMP`)
    .bind(day,success?1:0,success?0:1,int(inputTokens),int(outputTokens),hasImage?1:0).run();
  if(user?.uid) {
    await env.DB.prepare(`INSERT INTO usage_user_daily(day,user_uid,requests,successes,errors,input_tokens,output_tokens,image_requests,updated_at)
      VALUES(?,?,1,?,?,?,?,?,CURRENT_TIMESTAMP)
      ON CONFLICT(day,user_uid) DO UPDATE SET requests=requests+1,
        successes=successes+excluded.successes,errors=errors+excluded.errors,
        input_tokens=input_tokens+excluded.input_tokens,
        output_tokens=output_tokens+excluded.output_tokens,
        image_requests=image_requests+excluded.image_requests,updated_at=CURRENT_TIMESTAMP`)
      .bind(day,user.uid,success?1:0,success?0:1,int(inputTokens),int(outputTokens),hasImage?1:0).run();
  }
}
