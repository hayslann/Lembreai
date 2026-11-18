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
- Contagem de clientes autenticados (até conectar o Firebase, esta contagem é zero).
- Usuários autenticados, créditos e planos, apenas quando login estiver funcionando.
- Compra: apenas registro verificado pelo provedor de pagamentos, não inferido pelo celular.
- Custos: taxa do Gemini e a cobrança da Cloudflare devem ser obtidos dos próprios painéis. Não apresentar uma fatura fictícia: são apenas tokens consumidos.

## Firebase Authentication

1. Conectar plugin Firebase ao ChatGPT (se disponível) ou abrir console.firebase.google.com.
2. Criar projeto Firebase e app Android com package name `app.lembreai.lembreai` (confirmar identificador no Android gerado).
3. Ativar login com e-mail/senha e com Google; configurar SHA-1/SHA-256 da **assinatura de release fixa**.
4. Habilitar autenticação por Firebase no APK via configuração do projeto. Não inserir nenhuma senha privada nos sources.
5. Integrar verificação de ID token no Worker; **somente depois** ativar identidade, créditos, limites e lançamentos por usuário.
6. Não salvar senhas no D1.

## Google AdMob: anúncios recompensados

1. Criar conta em https://admob.google.com.
2. Apps > Add app > Android > **não publicado** e criar LembreAI.
3. Criar bloco de **Rewarded** e configurar **server-side verification (SSV)** para endpoint seguro no backend. Não usar client-side onUserEarnedReward como prova de crédito.
4. Enquanto não passar pela revisão e loja compatível, continuar com IDs oficiais de teste e **não prometer renda**.
5. Quando aprovado, cadastrar IDs reais via configuração de build; nunca testar clicando anúncios reais.
6. Antes de exibir anúncios comerciais, configurar consentimento UMP, aviso de privacidade e app-ads.txt no domínio indicado pelo AdMob.

Regras propostas: 1 anúncio **verificado via SSV** = 1 lembrete extra por 24 horas, no máximo 3 anúncios premiados por dia. O uso real depende de login verificado, idempotência de transação AdMob, controle de expiração e auditoria de saldo no D1.

## Cuidados importantes

- O texto completo da agenda e do chat não é armazenado no D1.
- Ao usar Gemini, mensagens e fotos escolhidas são enviadas ao fornecedor de IA, conforme consentimento separado.
- O administrador só vê dados vinculados à conta, se a pessoa se autenticar; sem login não é possível identificar corretamente quem usou o app.
- O app comercial deve ter exclusão de conta, política de privacidade completa, backups opcionais consentidos e validação legal.
- Nunca criar créditos nem ativar planos pagos unicamente alterando armazenamento local.
