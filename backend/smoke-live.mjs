// Teste fim a fim do LembreAI online. Nao imprime tokens ou segredos.
const endpoint='https://lembreai-ia.hayslan08.workers.dev';
const check=await fetch(endpoint+'/health',{
  signal:AbortSignal.timeout(15000),
});
if (!check.ok) throw new Error('Servidor Cloudflare /health: HTTP '+check.status);
const health=await check.json();
if (health.ok!==true || health.provider!=='gemini') {
  throw new Error('Servidor ativo, mas provedor Gemini nao confirmado');
}
console.log('Cloudflare /health: OK. Provedor: Gemini');
const response=await fetch(endpoint+'/chat',{
  method:'POST',
  headers:{'Content-Type':'application/json'},
  body:JSON.stringify({
    message:'Oi, tudo bem?',
    now:'2026-11-17T19:00:00',
    history:[],
    reminders:[],
  }),
  signal:AbortSignal.timeout(33000),
});
if (!response.ok) {
  const error=await response.json().catch(()=>({}));
  throw new Error('Gemini /chat: HTTP '+response.status+
    ' - '+(typeof error.error==='string'?error.error:'indisponivel'));
}
const data=await response.json();
if (data.intent!=='chat' || typeof data.reply!=='string' ||
    data.reply.trim().length<3 || data.reminder!=null ||
    (Array.isArray(data.reminders)&&data.reminders.length!==0)) {
  throw new Error('Gemini devolveu resposta inesperada para um cumprimento');
}
console.log('Gemini /chat: OK. Saudacao entendida sem criar lembrete.');
