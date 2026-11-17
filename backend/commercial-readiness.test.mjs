import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
test('a versao beta nao habilita compra local sem verificacao',()=>{
  const content=readFileSync(new URL('../lib/plan_catalog.dart',import.meta.url),'utf8');
  assert.match(content,/freeActiveReminderLimit=10/);
  assert.match(content,/Plus',200/);
  assert.match(content,/Pro',300/);
  assert.match(content,/available:false|available=false/);
});
test('os termos destacam privacidade, limites e responsabilidades legais',()=>{
  const content=readFileSync(new URL('../lib/legal_text.dart',import.meta.url),'utf8');
  assert.match(content,/LGPD/);
  assert.match(content,/Código de Defesa do Consumidor/);
  assert.match(content,/separadamente/);
});
