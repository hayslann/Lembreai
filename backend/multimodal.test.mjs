import test from 'node:test';
import assert from 'node:assert/strict';
import {validateResponse, filteredImage} from './brain.mjs';
import worker from './cloudflare-worker.mjs';

test('compreende varios compromissos extraidos de uma agenda',()=>{
  const response=validateResponse({intent:'create',reply:'Encontrei duas provas',
    reminders:[
      {title:'Prova de matemática',when:'2030-04-10T08:00:00',location:'Sala 12'},
      {title:'Prova de geografia',when:'2030-04-13T13:30:00',location:'Sala 7'},
    ]});
  assert.equal(response.intent,'create');
  assert.equal(response.reminders.length,2);
  assert.equal(response.reminders[0].location,'Sala 12');
  assert.equal(response.reminder.title,'Prova de matemática');
});
test('nao duplica eventos extraidos do email',()=>{
  const response=validateResponse({intent:'create',reminders:[
    {title:'Reunião',when:'2030-04-10T09:00:00'},
    {title:'Reunião',when:'2030-04-10T09:00:00'},
  ]});
  assert.equal(response.reminders.length,1);
});
test('rejeita datas impossiveis e nao inventa horario',()=>{
  const response=validateResponse({intent:'create',reminders:[
    {title:'Prova',when:'2030-02-30T15:00:00'},
    {title:'Prova',when:'2030-02-10'},
  ]});
  assert.equal(response.intent,'clarify');
});
test('nao cria eventos falsos em cumprimentos',()=>{
  const response=validateResponse({intent:'chat',reply:'Oi! Tudo bem?',
    reminders:[{title:'Invasão',when:'2030-01-01T08:00:00'}]});
  assert.equal(response.intent,'chat');
  assert.equal(response.reminders.length,0);
});
test('permite apenas imagem e formato validos',()=>{
  const image=filteredImage({mimeType:'image/png',data:'aGVsbG8='});
  assert.equal(image.mimeType,'image/png');
  assert.throws(()=>filteredImage({mimeType:'text/html',data:'aGVsbG8='}));
  assert.throws(()=>filteredImage({mimeType:'image/jpeg',data:'oops'}));
});
test('Worker envia foto na parte multimodal para Gemini',async()=>{
  const original=globalThis.fetch;
  const quota={getByName:()=>({fetch:async()=>new Response('{"allowed":true}')})};
  globalThis.fetch=async(_url,options)=>{
    const sent=JSON.parse(options.body);
    const parts=sent.contents.at(-1).parts;
    assert.equal(parts[1].inlineData.mimeType,'image/jpeg');
    assert.equal(parts[1].inlineData.data,'aGVsbG8=');
    return new Response(JSON.stringify({candidates:[{content:{parts:[
      {text:JSON.stringify({intent:'create',reminders:[
        {title:'Prova de história',when:'2030-02-10T08:00:00',location:'Escola'}]})}
    ]}}]}),{status:200});
  };
  try{
    const request=new Request('https://lembreai-ia.test/chat',{
      method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({message:'Organize esta foto',now:'2026-11-17T18:46:00',
        history:[],reminders:[],image:{mimeType:'image/jpeg',data:'aGVsbG8='}}),
    });
    const result=await worker.fetch(request,{GEMINI_API_KEY:'chave-teste',QUOTA:quota});
    assert.equal(result.status,200);
    assert.equal((await result.json()).reminders.length,1);
  } finally {globalThis.fetch=original;}
});
