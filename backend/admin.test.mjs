import test from 'node:test';
import assert from 'node:assert/strict';
import {authenticateAdmin,handleAdmin,recordUsage} from './admin.mjs';
import {systemInstruction} from './brain.mjs';

const request=(path,opts={}) => new Request('https://lembreai-ia.example.workers.dev'+path,opts);
test('painel administrativo nega acesso sem Cloudflare Access', async()=>{
  const r=await handleAdmin(request('/admin'),{ADMIN_EMAIL:'admin@example.com',DB:{}},{});
  assert.equal(r.status,403);
});
test('painel nao aceita identidades de outro e-mail',async()=>{
  const ctx={access:{getIdentity:async()=>({email:'other@example.com'})}};
  assert.equal(await authenticateAdmin({ADMIN_EMAIL:'admin@example.com'},ctx),null);
  const r=await handleAdmin(request('/admin/api/summary'),{ADMIN_EMAIL:'admin@example.com',DB:{}},ctx);
  assert.equal(r.status,403);
});
test('sem identidade autenticada e sem e-mail configurado falha fechado',async()=>{
  const ctx={access:{getIdentity:async()=>({email:'admin@example.com'})}};
  assert.equal(await authenticateAdmin({},ctx),null);
  const r=await handleAdmin(request('/admin'),{DB:{}},ctx);
  assert.equal(r.status,403);
});
test('banco ausente nao gera dados inventados',async()=>{
  const ctx={access:{getIdentity:async()=>({email:'ADMIN@example.com'})}};
  const r=await handleAdmin(request('/admin'),{ADMIN_EMAIL:'admin@example.com'},ctx);
  assert.equal(r.status,503);
});
test('so agrega metricas e nunca armazena texto da conversa',async()=>{
  let statement='';
  let values=[];
  const DB={prepare(sql){statement=sql;return {bind(...v){values=v;return {run:async()=>({success:true})};}}}};
  await recordUsage({DB},{success:true,inputTokens:120,outputTokens:28,hasImage:true});
  assert.match(statement,/usage_daily/);
  assert.ok(!statement.includes('message'));
  assert.deepEqual(values.slice(1),[1,0,120,28,1]);
});
test('Gemini restrito a agenda, saudações continuam naturais',()=>{
  assert.match(systemInstruction,/Sua única função é organizar agendamentos/);
  assert.match(systemInstruction,/cumprimentar, responda naturalmente/);
  assert.match(systemInstruction,/NÃO seja assistente/);
});
