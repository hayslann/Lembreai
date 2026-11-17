// Verificação manual: node backend/verificar-gemini.mjs
// Não publique GEMINI_API_KEY nem a inclua no aplicativo.
const key = process.env.GEMINI_API_KEY;
if (!key) {
  console.error('Configure GEMINI_API_KEY somente no computador ou servidor.');
  process.exitCode = 1;
} else {
  const model = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
  const endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/' +
    encodeURIComponent(model) + ':generateContent';
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': key,
      },
      body: JSON.stringify({
        contents: [{parts: [{text: 'Responda somente: Conexão com o LembreAI funcionando.'}]}],
      }),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) {
      console.error('Falha no Gemini: HTTP ' + response.status +
        '. Verifique a chave, o modelo e os limites do projeto.');
      process.exitCode = 1;
    } else {
      const data = await response.json();
      const answer = data.candidates?.[0]?.content?.parts?.map(p => p.text || '').join('') || '';
      if (answer.trim()) {
        console.log('Gemini respondeu:', answer.trim());
      } else {
        console.error('A API respondeu, mas sem texto utilizável.');
        process.exitCode = 1;
      }
    }
  } catch (_) {
    console.error('Não foi possível conectar à API do Gemini.');
    process.exitCode = 1;
  }
}
