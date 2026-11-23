// Run:  node test-ai.js     (inside the backend folder)
// Checks your Gemini key and shows which models really work for you.
require('dotenv').config();

const key = process.env.GEMINI_API_KEY;
if (!key || key.includes('XXXX')) {
  console.log('No real GEMINI_API_KEY found in .env');
  process.exit(1);
}

async function timed(label, fn) {
  const t = Date.now();
  try {
    const out = await fn();
    console.log(`${label}: ${out}  (${((Date.now() - t) / 1000).toFixed(1)}s)`);
  } catch (e) {
    console.log(`${label}: FAILED - ${e.message}  (${((Date.now() - t) / 1000).toFixed(1)}s)`);
  }
}

(async () => {
  console.log('Key starts with:', key.slice(0, 6) + '...', ' length:', key.length);

  await timed('List models', async () => {
    const r = await fetch('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200', {
      headers: { 'x-goog-api-key': key },
      signal: AbortSignal.timeout(15000),
    });
    if (!r.ok) throw new Error(`${r.status} ${(await r.text()).slice(0, 150)}`);
    const d = await r.json();
    const names = (d.models || [])
      .filter((m) => (m.supportedGenerationMethods || []).includes('generateContent'))
      .map((m) => m.name.replace('models/', ''))
      .filter((n) => /flash/.test(n));
    return '\n  ' + names.join('\n  ');
  });

  const wanted = [process.env.GEMINI_MODEL || 'gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-3.1-flash-lite'];
  for (const model of [...new Set(wanted)]) {
    await timed(`Try ${model}`, async () => {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        body: JSON.stringify({ contents: [{ parts: [{ text: 'Translate "Pay the tax" into Tamil. Reply with the translation only.' }] }] }),
        signal: AbortSignal.timeout(20000),
      });
      const d = await r.json();
      if (!r.ok) throw new Error(`${r.status} ${d.error?.message || ''}`.slice(0, 150));
      return (d.candidates?.[0]?.content?.parts || []).map((p) => p.text).join('').trim();
    });
  }
})();