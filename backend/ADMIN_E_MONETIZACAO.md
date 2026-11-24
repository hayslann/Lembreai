# LembreAI: central de administração, AdMob e autenticação

## Estado da beta

- IA Gemini no Cloudflare Worker `lembreai-ia`; lembretes ficam no Android.
- D1 `lembreai-operacoes` armazena apenas métricas agregadas, usuários futuros, livro de créditos e pagamentos validados, não fotos nem agenda.
- Página administrativa: `https://lembreai-ia.hayslan08.workers.dev/admin`
- Por segurança o painel retorna **403** até configurar Cloudflare Access e `ADMIN_EMAIL`.
- Não usar uma senha codificada no aplicativo nem abrir endpoints de admin ao público.

## Ativar entrada segura para o administrador

1. Cloudflare > **Zero Trust / Access** > habilitar Cloudflare Access.
2. Adicionar **self-hosted application**, em domínio/caminho `lembreai-ia.hayslan08.workers.dev/admin*` (não o Worker completo, pois a rota /chat precisa continuar pública para a beta).
3. Política **Allow** apenas para o e-mail do proprietário; use login com código por e-mail ou identidade Google com MFA.
4. No Worker `lembreai-ia` > Settings > Variables and Secrets, cadastrar **ADMIN_EMAIL** com exatamente o mesmo e-mail autorizado. Esta variável NÃO deve ir ao código-fonte.
5. Verificar que `/admin` e `/admin/api/*` exigem login, enquanto `/health` funciona publicamente.
6. O código valida novamente `ctx.access` e e-mail, mesmo depois da proteção de borda.

## Dados que a central mostra

- Quantidade de chamadas de IA, êxitos, falhas, imagens e tokens por dia.
- Usuários autenticados, status ativo/bloqueado, créditos, planos, última atividade, pedidos e custo estimado por conta.
- Ativos nos últimos 5 minutos: presença aproximada de contas autenticadas que enviam o sinal de atividade; não representa usuários sem login nem atividade offline.
- Downloads: contador público dos arquivos da versão beta na página de releases do GitHub. Para downloads da Play Store será necessária a conexão/consulta ao Play Console.
- Adicionar e retirar créditos com registro do administrador, UID/e-mail da conta, valor e data; bloquear/desbloquear contas. O Worker impede que uma conta bloqueada use IA, saldo ou anúncios.
- Histórico de contratações verificadas pelo servidor. **Ainda não existe checkout conectado a um provedor de pagamento**, então a tabela permanece vazia até escolher e configurar um provedor e seu webhook.
- Custos: taxa do Gemini e a cobrança da Cloudflare devem ser obtidos dos próprios painéis. Não apresentar uma fatura fictícia: são apenas tokens consumidos.

As ações de crédito e bloqueio requerem a migração `0003_admin_actions.sql`, além das migrações `0002_user_usage_daily.sql` e `0001_operations.sql`. O código registra atividade só para quem entra em uma conta; sem autenticação não dá para distinguir clientes individuais com precisão.

## Firebase Authentication

1. A instalação do plugin Firebase no ChatGPT não é necessária para o aplicativo; o código usa o serviço oficial Firebase Authentication pela API REST.
2. Criar projeto Firebase e app Android com package name `app.lembreai.lembreai`.
3. Ativar login com e-mail/senha e com Google; configurar SHA-1/SHA-256 da assinatura usada para compilar a beta.
4. Cadastrar `FIREBASE_WEB_API_KEY` e `GOOGLE_WEB_CLIENT_ID` como GitHub Actions Secrets. Cadastrar `FIREBASE_WEB_API_KEY` também como secret do Worker Cloudflare.
5. O Worker valida o ID token com o Identity Toolkit antes de registrar o UID e o e-mail. O D1 nunca armazena senhas.
6. A assinatura da compilação e o SHA-1 precisam permanecer iguais para o login Google e as atualizações do APK continuarem funcionando.

## Assinatura estável e atualização do APK

- As versões anteriores da beta foram compiladas como `debug` pelo GitHub Actions. Cada execução usou uma chave temporária diferente; por isso o Android não consegue instalar essas versões por cima umas das outras.
- Para os próximos APKs instalarem por cima e preservarem os dados locais, configure no repositório GitHub `hayslann/Lembreai` os secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD`. O workflow passa a gerar APK `release` com essa mesma chave e só atualiza o link de download quando a assinatura está configurada.
- A chave privada deve ficar apenas no secret do GitHub; não a coloque no código ou em arquivos versionados. Registre também os SHA-1/SHA-256 dessa chave nas configurações do app Android no Firebase para manter o login Google.
- **Migração da versão já instalada:** como a chave temporária da APK antiga não pode ser recuperada, instalar a primeira versão com assinatura estável exige remover a beta antiga uma única vez. Remover o app apaga os lembretes guardados localmente; depois dessa migração, as próximas versões poderão ser instaladas pelo botão Atualizar sem desinstalar.

Antes de publicar esta alteração, aplicar as migrações D1 na pasta `backend` (`npx wrangler d1 migrations apply lembreai-operacoes --remote`) e cadastrar `FIREBASE_WEB_API_KEY` como secret do Worker (`npx wrangler secret put FIREBASE_WEB_API_KEY`). Sem esses passos, o login pode autenticar no Firebase, mas as rotas de conta e métricas por usuário não ficam disponíveis.

## Google AdMob: anúncios recompensados

1. Conta AdMob e app Android **não publicado** `LembreAI` já cadastrados. ID do app: `ca-app-pub-9334057482133217~5852596397`.
2. Bloco **Rewarded** `Lembrete extra - recompensado` criado para 1 `lembrete_extra`. ID: `ca-app-pub-9334057482133217/5258921211`.
3. Callback SSV `https://lembreai-ia.hayslan08.workers.dev/admob/ssv` foi verificado e salvo no bloco. O Worker verifica assinatura Google, sessão vinculada e duplicidade; a variável secreta `ADMOB_REWARDED_AD_UNIT_ID` foi configurada com o número do bloco para impedir créditos vindos de outro bloco.
4. A conta ainda informa análise de dados e perfil de pagamento incompleto. Até concluir esses requisitos e a análise do app, manter os IDs oficiais de teste no APK e não prometer renda. A unidade real pode demorar até uma hora para começar a preencher anúncios.
5. Quando aprovado, cadastrar `ADMOB_APPLICATION_ID` e `ADMOB_REWARDED_AD_UNIT_ID` como GitHub Actions Secrets. Nunca testar clicando anúncios reais.
6. Antes de anúncios comerciais, configurar consentimento UMP, aviso de privacidade e app-ads.txt no domínio indicado pelo AdMob.

Regra preparada no código: 1 anúncio **verificado via SSV** = 1 crédito para um lembrete além do limite gratuito, válido por 24 horas, no máximo 3 sessões de anúncio por dia. O Worker exige login Firebase, vincula o retorno SSV a uma sessão criada no servidor, rejeita reutilização de transação e registra o crédito no livro de auditoria D1. Isso só fica ativo depois de aplicar a migração, configurar Firebase e AdMob, e publicar o Worker atualizado.

## Cuidados importantes

- O texto completo da agenda e do chat não é armazenado no D1.
- Ao usar Gemini, mensagens e fotos escolhidas são enviadas ao fornecedor de IA, conforme consentimento separado.
- O administrador só vê dados vinculados à conta, se a pessoa se autenticar; sem login não é possível identificar corretamente quem usou o app.
- O app comercial deve ter exclusão de conta, política de privacidade completa, backups opcionais consentidos e validação legal.
- Nunca criar créditos nem ativar planos pagos unicamente alterando armazenamento local.
