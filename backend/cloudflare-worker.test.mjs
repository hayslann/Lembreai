import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './cloudflare-worker.mjs';

const url='https://lembreai-ia.test';
const envelope={
  message:'Me lembra amanhã às 14h de pagar a conta',
  now:'2026-11-17T12:00:00',
  history:[],reminders:[],
};
const quota={getByName:()=>({fetch:async()=>new Response('{"allowed":true}',{
  status:200,headers:{'Content-Type':'application/json'}})})};
function post(body,headers={}) {
  return new Request(url+'/chat',{method:'POST',headers:{
    'Content-Type':'application/json',...headers,
  },body:typeof body==='string'?body:JSON.stringify(body)});
}

test('saúde não exige chave',async()=>{
  const result=await worker.fetch(new Request(url+'/health'),{});
  assert.equal(result.status,200);
  assert.equal((await result.json()).ok,true);
});
test('rota inexistente recebe 404',async()=>{
  const result=await worker.fetch(new Request(url+'/other'),{});
  assert.equal(result.status,404);
});
test('sem chave configurada retorna 503',async()=>{
  const result=await worker.fetch(post(envelope),{QUOTA:quota});
  assert.equal(result.status,503);
});
test('token de desenvolvimento bloqueia solicitantes não autorizados',async()=>{
  const result=await worker.fetch(post(envelope),{
    GEMINI_API_KEY:'chave-ficticia',LEMBREAI_DEV_TOKEN:'segredo',
    QUOTA:quota,
  });
  assert.equal(result.status,401);
});
test('JSON malformado não acessa Gemini',async()=>{
  const result=await worker.fetch(post('{{'),{
    GEMINI_API_KEY:'chave-ficticia',QUOTA:quota,
  });
  assert.equal(result.status,400);
});
test('cota diária impede consulta externa',async()=>{
  const refused={getByName:()=>({fetch:async()=>new Response(
    '{"error":"Limite alcançado"}',{status:429})})};
  const result=await worker.fetch(post(envelope),{
    GEMINI_API_KEY:'chave-ficticia',QUOTA:refused,
  });
  assert.equal(result.status,429);
});
test('criação estruturada é validada pelo servidor sem vazar chave',async()=>{
  const original=globalThis.fetch;
  globalThis.fetch=async (uri, options)=>{
    assert.match(String(uri),/generativelanguage.googleapis.com/);
    assert.equal(options.headers['x-goog-api-key'],'chave-ficticia');
    const generated=JSON.stringify({intent:'create',reply:'Entendi',reminder:{
      title:'Pagar a conta',when:'2026-11-18T14:00:00'}});
    return new Response(JSON.stringify({
      candidates:[{content:{parts:[{text:generated}]}}],
    }),{status:200});
  };
  try {
    const result=await worker.fetch(post(envelope),{
      GEMINI_API_KEY:'chave-ficticia',QUOTA:quota,
      AI_PROVIDER:'gemini',GEMINI_MODEL:'gemini-2.5-flash-lite',
    });
    assert.equal(result.status,200);
    const body=await result.json();
    assert.equal(body.intent,'create');
    assert.equal(body.reminder.title,'Pagar a conta');
    assert.ok(!JSON.stringify(body).includes('chave-ficticia'));
  } finally {
    globalThis.fetch=original;
  }
});
