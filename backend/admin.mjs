// Painel de operacoes. NUNCA confie em senha no APK ou no navegador.
// Cloudflare Access autentica. ADMIN_EMAIL (secret) define o administrador.
function reply(data,status=200) {
  return new Response(JSON.stringify(data),{
    status,headers:{'Content-Type':'application/json; charset=utf-8',
      'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}
  });
}
function deny() {return reply({error:'Acesso administrativo negado.'},403);}
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
<table><thead><tr><th>ID</th><th>E-mail</th><th>Plano</th><th>Créditos</th><th>Último uso</th></tr></thead>
<tbody id="users"></tbody></table></section>
<section><h2>Conceder créditos com auditoria</h2>
<form id="grant"><input required id="uid" placeholder="UID autenticado" autocomplete="off">
<input required id="points" type="number" min="1" max="1000" placeholder="Créditos (1–1000)">
<button type="submit">Adicionar créditos</button></form>
<p class="muted">Apenas contas que já existam no banco podem receber créditos. Ação registrada.</p></section>
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
 const [s,u,p]=await Promise.all([
   get('/admin/api/summary'),get('/admin/api/users'),get('/admin/api/purchases')]);
 for(const id of ['requests','successes','errors','inTokens','outTokens','usersCount']) {
  const prop={inTokens:'input_tokens',outTokens:'output_tokens',usersCount:'users'}[id]||id;
  el(id).textContent=fmt(s.total[prop]);
 }
 el('estimatedCost').textContent=s.total.estimated_paid_cost_usd==null?'Não configurado':
   '$ '+Number(s.total.estimated_paid_cost_usd).toFixed(5);
 table('days',s.days,['day','requests','successes','errors','input_tokens','output_tokens','image_requests']);
 table('users',u.users,['uid','email','plan','credit_balance','last_active_at']);
 table('purchases',p.purchases,['user_uid','plan','status','price_cents','created_at']);
 el('status').textContent='Dados atualizados com segurança.';
 }catch(e){el('status').textContent=e.message;}
}
el('refresh').onclick=load;
el('grant').onsubmit=async(e)=>{
 e.preventDefault();
 const uid=el('uid').value.trim();const credits=Number(el('points').value);
 if(!confirm('Conceder '+credits+' créditos para '+uid+'?'))return;
 try {
  const res=await fetch('/admin/api/credits',{method:'POST',credentials:'same-origin',
    headers:{'Content-Type':'application/json'},body:JSON.stringify({uid,credits})});
  const value=await res.json();if(!res.ok)throw Error(value.error||'Falha');
  el('status').textContent='Créditos registrados no livro de auditoria.';
  await load();
 }catch(err){el('status').textContent=err.message;}
};
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
    const inputRate=Number(env.GEMINI_INPUT_USD_PER_MTOK);
    const outputRate=Number(env.GEMINI_OUTPUT_USD_PER_MTOK);
    const configured=env.GEMINI_INPUT_USD_PER_MTOK!=null && env.GEMINI_OUTPUT_USD_PER_MTOK!=null &&
      Number.isFinite(inputRate) && Number.isFinite(outputRate) &&
      inputRate>=0 && outputRate>=0 && inputRate<=100 && outputRate<=100;
    const estimatedCost=configured ?
      Math.round((Number(totals.input_tokens||0)*inputRate+
        Number(totals.output_tokens||0)*outputRate)/1000000*100000)/100000 : null;
    return reply({days,total:{...totals,users:count?.count||0,
      estimated_paid_cost_usd:estimatedCost}});
  }
  if(request.method==='GET' && path==='/admin/api/users') {
    const users=(await env.DB.prepare('SELECT uid,email,plan,credit_balance,last_active_at FROM users ORDER BY last_active_at DESC LIMIT 100').all()).results;
    return reply({users});
  }
  if(request.method==='GET' && path==='/admin/api/purchases') {
    const purchases=(await env.DB.prepare('SELECT user_uid,plan,status,price_cents,currency,created_at FROM purchase_records ORDER BY created_at DESC LIMIT 100').all()).results;
    return reply({purchases});
  }
  if(request.method==='POST' && path==='/admin/api/credits') {
    // O navegador autenticado envia somente pedidos originados deste painel.
    if(request.headers.get('Origin')!==url.origin ||
      !request.headers.get('Content-Type')?.startsWith('application/json')) {
      return reply({error:'Origem inválida.'},403);
    }
    let data;
    try {data=await request.json();}catch(_){return reply({error:'JSON inválido.'},400);}
    const uid=data?.uid, credits=data?.credits;
    if(typeof uid!=='string'||uid.length<5||uid.length>150||
       !/^[A-Za-z0-9:_-]+$/.test(uid)||
       !Number.isInteger(credits)||credits<1||credits>1000)
      return reply({error:'Usuário ou créditos inválidos.'},400);
    const user=await env.DB.prepare("SELECT uid FROM users WHERE uid=? AND account_status='active'").bind(uid).first();
    if(!user)return reply({error:'Usuário não cadastrado/autenticado.'},404);
    const ref='admin:'+crypto.randomUUID();
    await env.DB.batch([
      env.DB.prepare("INSERT INTO credit_ledger(user_uid,event_type,delta,reference_id,actor) VALUES(?,'admin_grant',?,?,?)").bind(uid,credits,ref,email),
      env.DB.prepare("UPDATE users SET credit_balance=(SELECT COALESCE(SUM(delta),0) FROM credit_ledger WHERE user_uid=?) WHERE uid=?").bind(uid,uid),
    ]);
    return reply({ok:true,reference:ref});
  }
  return reply({error:'Rota administrativa não encontrada.'},404);
}

export async function recordUsage(env,{success,inputTokens=0,outputTokens=0,hasImage=false}={}) {
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
}
