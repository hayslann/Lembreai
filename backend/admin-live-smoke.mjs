const base='https://lembreai-ia.hayslan08.workers.dev';
const health=await fetch(base+'/health',{signal:AbortSignal.timeout(15000)});
if(health.status!==200 || (await health.json()).ok!==true)
  throw Error('O servidor Gemini nao respondeu em /health');
for(const path of ['/admin','/admin/api/summary','/admin/api/users']) {
 const response=await fetch(base+path,{redirect:'manual',signal:AbortSignal.timeout(15000)});
 // 302/303 para Cloudflare Access tambem e aceitavel; 200 seria vazamento.
 if(response.status!==403 && response.status!==302 && response.status!==303)
   throw Error('Acesso anonimo ao painel NAO foi bloqueado em '+path+': HTTP '+response.status);
 console.log('Rota protegida de visitante nao autenticado: '+path+' HTTP '+response.status);
}
console.log('Saude de IA publica e rotas administrativas fechadas: OK');
