# Hospedagem Cloudflare Workers do LembreAI

Este projeto foi preparado para ser hospedado no **Cloudflare Workers** com
integração automática ao GitHub. A Cloudflare é responsável pela publicação,
e o **Gemini API Key** fica armazenado como segredo no Worker (nunca no APK).

## Conectar o GitHub à Cloudflare (uma única vez)

1. Acesse https://dash.cloudflare.com/ e entre ou crie uma conta.
2. Vá a **Workers & Pages** → **Create application** → **GitHub**.
3. Autorize a conexão com GitHub e selecione somente o repositório
   **hayslann/Lembreai**.
4. Na configuração do Worker, use:
   - **Nome do Worker:** `lembreai-ia`
   - **Branch:** `main`
   - **Root directory:** `backend`
   - **Build command:** deixe em branco
   - **Deploy command:** `npx wrangler deploy`
5. Salve e faça a primeira publicação.
6. Abra o Worker no painel da Cloudflare e vá a **Settings → Variables & Secrets**.
   Crie o segredo **GEMINI_API_KEY** e cole a chave que você criou no
   https://aistudio.google.com/apikey. **Não coloque a chave como variável
   de texto comum.** A configuração padrão usa Gemini.
7. Copie a URL pública do Worker, por exemplo
   `https://lembreai-ia.SUA-CONTA.workers.dev`. Não invente sua URL.
8. No aplicativo Android atualizado, abra **Configurações (engrenagem)**,
   cole a URL HTTPS, salve e verifique a conexão. Autorize o uso de
   inteligência artificial quando o aplicativo pedir.

A URL `/health` confirma apenas que o Worker está em execução.
Se o Worker responder 503, confira o segredo do Gemini e os limites da conta.

## Proteção de custos e privacidade

O Worker tem um limitador inicial de **75 mensagens por dia no total**,
**20 mensagens por dia por origem** e **5 por minuto por origem**, salvo
se você alterar as variáveis `GLOBAL_DAILY_LIMIT` e `PER_IP_DAILY_LIMIT`.
As cotas são mantidas em Durable Objects, disponíveis no plano Free com
restrições próprias. **É um limite de testes e não autenticação de usuários.**

Antes de abrir o aplicativo ao público, adicione login autenticado e cotas
por usuário. Não confie em tokens fixos colocados no APK. O uso gratuito do
Gemini depende de elegibilidade e limites do Google; pode exigir faturamento
em determinados modelos, contas ou cenários.

O aplicativo solicita consentimento antes de enviar mensagens, trechos da
conversa e compromissos para a IA. Para distribuição pública será necessário
oferecer política de privacidade e controles adequados aos dados pessoais.

## Outros detalhes

- `backend/cloudflare-worker.mjs` é o Worker público preparado para a Cloudflare.
- `backend/wrangler.jsonc` contém o nome, as cotas e o Durable Object.
- `backend/brain.mjs` orienta e valida a interpretação das mensagens.
- `backend/server.mjs` é o servidor Node.js alternativo de desenvolvimento.
- `backend/cloudflare-worker.test.mjs` contém testes locais com API simulada.
- A publicação no Worker pode acontecer automaticamente a cada mudança no
  GitHub, conforme as configurações selecionadas na Cloudflare.
- **Sem a sua autorização da Cloudflare ao GitHub e sem a chave secreta
  cadastrada no painel, o serviço não fica ativo.**
- A assinatura/instalação do APK Android continua sendo feita pelo GitHub.
