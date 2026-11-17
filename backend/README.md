# LembreAI — integração de inteligência artificial

O aplicativo continua usando lembretes locais quando não existe conexão online.
O sistema online é opcional e usa um servidor intermediário para não divulgar
a chave secreta do Gemini ou da OpenAI dentro do aplicativo Android.

## Funcionalidades no código
- Chat com interpretação local de datas e horários.
- Lembretes armazenados no celular, agenda e notificações programadas.
- Assistente online via Gemini (padrão) ou OpenAI, quando configurado.
- A IA devolve uma sugestão de lembrete; somente o aplicativo cria o registro e agenda avisos.
- Perguntas vagas retornam pedido de esclarecimento, nunca compromisso inventado.

## Passo 1 — Criar uma chave Gemini
1. Abra https://aistudio.google.com/apikey e entre na sua conta.
2. Crie uma chave em um projeto elegível para o plano gratuito.
3. **Não envie a chave pelo chat nem publique no GitHub.**
4. Em um terminal PowerShell do Windows, na pasta do projeto, rode:
   `$env:GEMINI_API_KEY = Read-Host "Cole a chave do Gemini"`
   `node backend/server.mjs`
5. O servidor começa em http://127.0.0.1:8787 e a rota /health verifica a inicialização.
   Isso é acessível apenas neste computador.

## Passo 2 — Conectar Android
Para o aplicativo acessar a IA, é preciso disponibilizar o servidor atrás de
HTTPS e autenticação, e informar sua URL no momento da compilação:
`flutter build apk --debug --dart-define=AI_SERVER_URL=https://seu-servidor.example`

Se a compilação for pelo GitHub Actions, configure a variável do repositório
**LEMBREAI_AI_URL** com a URL HTTPS da API antes de iniciar uma nova compilação.
Essa variável **não** deve conter a chave do Gemini.

Para conectar diretamente ao PC pela rede local, é necessário configurar uma
rota HTTPS e a rede adequadamente; não publique a porta do servidor na internet.
O servidor aceita o cabeçalho Bearer `LEMBREAI_DEV_TOKEN` apenas como proteção
temporária de desenvolvimento; esse token compilado no aplicativo NÃO é
autenticação segura para usuários finais.

## Passo 3 — Alternar para OpenAI
Configure `AI_PROVIDER=openai` e `OPENAI_API_KEY` **no servidor**. O plano
ChatGPT e o faturamento da API OpenAI são independentes.

## Segurança e lançamento comercial
- O plano gratuito do Gemini tem limites e algumas modalidades gratuitas podem
  permitir uso dos dados para melhoria de produtos do provedor. Consulte as
  condições antes de enviar informações pessoais.
- Para disponibilizar a milhares de usuários, implante HTTPS, login real,
  autenticação por usuário no backend, controle de consumo, política de
  privacidade, consentimentos e um banco de dados adequado.
- Não compartilhe chaves, tokens, dados pessoais ou boletos em repositórios públicos.
- O GitHub Pages não executa esse servidor.
- A compilação de APK não significa que o fluxo de autenticação e IA já esteja ativo.


## Testar sua chave no Windows, sem colocá-la no APK

No PowerShell, com Node.js instalado, baixe o repositório e execute:

```powershell
git clone https://github.com/hayslann/Lembreai.git
cd Lembreai
$env:GEMINI_API_KEY = Read-Host "Cole sua chave Gemini (ela fica apenas nesta sessão)"
node backend/verificar-gemini.mjs
```

O teste faz exatamente a chamada REST `generateContent` demonstrada no
exemplo de cURL, usando o cabeçalho `x-goog-api-key`. Se aparecer a resposta
do Gemini, o acesso à API está confirmado. Você pode escolher o modelo com
`$env:GEMINI_MODEL = "gemini-2.5-flash-lite"`.

Para iniciar o servidor local do aplicativo nessa mesma sessão:

```powershell
$env:AI_PROVIDER = "gemini"
node backend/server.mjs
```

Em outro terminal PowerShell, verifique apenas o funcionamento local:
`Invoke-RestMethod http://127.0.0.1:8787/health`.

**Isso ainda não conecta o APK instalado no celular.** É necessário publicar
o servidor em um endereço HTTPS com autenticação por usuário, configurar a
variável `LEMBREAI_AI_URL` no repositório e recompilar o aplicativo.
Não use apenas um token embutido no aplicativo para autenticar usuários finais.

No PowerShell, o `curl` de Bash (com `\\` e `$GEMINI_API_KEY`) pode não
funcionar exatamente como aparece na documentação para Linux. Use o script
`verificar-gemini.mjs` acima para testar com segurança.

Não cole a chave no chat, em arquivos versionados ou em capturas de tela.
