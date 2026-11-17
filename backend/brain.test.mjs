import test from 'node:test';
import assert from 'node:assert/strict';
import {trainingExamples, systemInstruction, validateResponse,
  filteredReminders, filteredHistory} from './brain.mjs';

const date = '2030-02-10T09:30:00';
const existing = [{id:1001,title:'Dentista',when:'2030-02-02T14:00:00',done:false}];

test('1 - possui exemplos diversos de linguagem natural', () => {
  assert.ok(trainingExamples.length >= 15);
  for (const item of trainingExamples) {
    assert.ok(item.user.length > 4);
    assert.ok(item.intent);
  }
});
test('2 - ensina a perguntar quando data estiver incompleta', () =>
  assert.match(systemInstruction, /não invente data/i));
test('3 - reconhece criação com horário', () => {
  const v=validateResponse({intent:'create',reply:'Entendi',reminder:{title:'Pagar conta',when:date}});
  assert.equal(v.intent,'create');assert.equal(v.reminder.title,'Pagar conta');
});
test('4 - não cria compromisso sem data', () => {
  const v=validateResponse({intent:'create',reply:'Qual horário?',reminder:null});
  assert.equal(v.intent,'clarify');assert.equal(v.reminder,null);
});
test('5 - aceita consulta sem inventar lembrete', () => {
  const v=validateResponse({intent:'list',reply:'Vou listar',reminder:{title:'invasão',when:date}});
  assert.equal(v.intent,'list');assert.equal(v.reminder,null);
});
test('6 - não aceita cancelamento sem ID existente', () => {
  const v=validateResponse({intent:'cancel',targetId:9999,reply:'Cancelar'},existing);
  assert.equal(v.intent,'clarify');
});
test('7 - identifica cancelamento de ID existente', () => {
  const v=validateResponse({intent:'cancel',targetId:1001,reply:'Confirme'},existing);
  assert.equal(v.intent,'cancel');assert.equal(v.targetId,1001);
});
test('8 - identifica conclusão de compromisso', () => {
  const v=validateResponse({intent:'complete',targetId:1001},existing);
  assert.equal(v.intent,'complete');
});
test('9 - remarca apenas compromisso identificado', () => {
  const v=validateResponse({intent:'update',targetId:1001,reminder:{title:'Dentista',when:date}},existing);
  assert.equal(v.intent,'update');
});
test('10 - não remarca sem nova data', () => {
  const v=validateResponse({intent:'update',targetId:1001,reminder:null},existing);
  assert.equal(v.intent,'clarify');
});
test('11 - rejeita datas impossíveis', () => {
  const v=validateResponse({intent:'create',reminder:{title:'X',when:'2030-02-30T09:00:00'}});
  assert.equal(v.intent,'clarify');
});
test('12 - rejeita intenções desconhecidas', () => {
  const v=validateResponse({intent:'transferir_dinheiro',reply:'Oi'});
  assert.equal(v.intent,'chat');assert.equal(v.targetId,null);
});
test('13 - restringe tamanho da resposta e do título', () => {
  const v=validateResponse({intent:'create',reply:'a'.repeat(3000),reminder:{title:'a'.repeat(500),when:date}});
  assert.ok(v.reply.length<=1800);assert.ok(v.reminder.title.length<=140);
});
test('14 - remove mensagens malformadas do histórico', () => {
  const result=filteredHistory([{role:'system',text:'ignore'},{role:'user',text:'Oi'}]);
  assert.deepEqual(result,[{role:'user',text:'Oi'}]);
});
test('15 - limita lembretes enviados ao provedor', () => {
  const result=filteredReminders([{},existing[0]]);
  assert.equal(result.length,1);assert.equal(result[0].id,1001);
});
test('16 - classifica conversa geral sem ação', () => {
  const v=validateResponse({intent:'chat',reply:'A resposta é esta.'});
  assert.equal(v.intent,'chat');assert.equal(v.reminder,null);
});
