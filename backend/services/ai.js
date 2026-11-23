const { analyze: offlineAnalyze } = require('./offlineAnalyzer');
const { computeUrgency } = require('./urgency');

const LANG_NAMES = {
  en: 'English', hi: 'Hindi', ta: 'Tamil', te: 'Telugu', kn: 'Kannada', ml: 'Malayalam',
  bn: 'Bengali', mr: 'Marathi', gu: 'Gujarati', pa: 'Punjabi', ur: 'Urdu',
};

// Which AI is active? Gemini (free) or Claude (paid) if a key is set, else offline.
function provider() {
  if (process.env.GEMINI_API_KEY) return 'gemini';
  if (process.env.ANTHROPIC_API_KEY) return 'claude';
  return 'offline';
}
const hasKey = () => provider() !== 'offline';

async function callClaude(prompt, maxTokens) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': process.env.ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: process.env.AI_MODEL || 'claude-sonnet-5-5',
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }],
    }),
  });
  if (!res.ok) throw new Error(`Claude API error ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return (data.content || []).map((c) => c.text || '').join('');
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Calls Gemini. If a model is busy or slow it retries, then tries backup models.
// Gives up after about 60 seconds in total so the app never hangs.
async function callGemini(prompt, maxTokens, wantJson) {
  const models = [
    ...new Set([process.env.GEMINI_MODEL || 'gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-3.1-flash-lite']),
  ];
  const deadline = Date.now() + 60000;
  let lastStatus = 0;
  let lastBody = '';

  for (const model of models) {
    for (let attempt = 1; attempt <= 2; attempt++) {
      if (Date.now() > deadline) break;
      let res;
      try {
        res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
          method: 'POST',
          signal: AbortSignal.timeout(15000),
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': process.env.GEMINI_API_KEY,
          },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              maxOutputTokens: Math.max(maxTokens, 4096),
              ...(wantJson ? { responseMimeType: 'application/json' } : {}),
            },
          }),
        });
      } catch (e) {
        console.log(`Gemini ${model} no answer in 15s (${e.name}), attempt ${attempt}/2`);
        lastStatus = 503;
        lastBody = e.message;
        continue;
      }

      if (res.ok) {
        const data = await res.json();
        const text = (data.candidates?.[0]?.content?.parts || []).map((p) => p.text || '').join('');
        if (text.trim()) {
          console.log(`Gemini ${model} answered OK`);
          return text;
        }
        break; // empty answer: try next model
      }

      lastStatus = res.status;
      lastBody = await res.text();
      console.log(`Gemini ${model} returned ${res.status}, attempt ${attempt}/2`);
      if (res.status === 503 || res.status === 429) {
        if (attempt < 2) await sleep(1500);
        continue; // retry same model
      }
      if (res.status === 404) break; // model not available: next model
      // 400 / 401 / 403 etc: bad key or bad request, no point retrying
      const err = new Error(`Gemini API error ${res.status}: ${lastBody.slice(0, 300)}`);
      err.status = 502;
      throw err;
    }
  }

  const err = new Error(
    lastStatus === 503 || lastStatus === 429
      ? "Google's free AI is busy or slow right now. Please wait a minute and try again."
      : `Gemini API error ${lastStatus}: ${lastBody.slice(0, 300)}`
  );
  err.status = lastStatus === 503 || lastStatus === 429 ? 503 : 502;
  throw err;
}

async function callLLM(prompt, maxTokens = 2500, wantJson = false) {
  return provider() === 'gemini' ? callGemini(prompt, maxTokens, wantJson) : callClaude(prompt, maxTokens);
}

function extractJson(text) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('No JSON in AI response');
  return JSON.parse(text.slice(start, end + 1));
}

async function analyzeNotice(text) {
  const trimmed = text.slice(0, 12000);
  if (!hasKey()) return { ...offlineAnalyze(trimmed), analyzedBy: 'offline' };

  const today = new Date().toISOString().slice(0, 10);
  const prompt = `You are NoticeBridge, an assistant that explains official notices (tax, bank, college, legal, government, utility) to ordinary people.
Today's date is ${today}. Read the notice below and reply with ONLY a JSON object (no markdown) in exactly this shape:
{
  "title": "short title, max 8 words",
  "category": "tax | bank | college | legal | govt | utility | other",
  "summary": {
    "simple": "2-3 sentence plain-language summary",
    "verySimple": "1-2 very short sentences a 12-year-old understands",
    "detailed": "a fuller summary of 5-8 sentences covering all key facts"
  },
  "urgency": "low | medium | high (high: deadline <= 5 days or overdue; medium: deadline 6 to 15 days; low: deadline > 15 days or no deadline)",
  "riskIfIgnored": "one sentence on what could happen if the reader ignores this",
  "amounts": ["every money amount mentioned, as written"],
  "documentsNeeded": ["documents or items the reader must provide"],
  "highlights": [{"point": "short key point", "source": "EXACT sentence copied from the notice that supports it"}],
  "deadlines": [{"title": "what is due", "date": "YYYY-MM-DD"}],
  "actions": ["clear step the reader must take, starting with a verb"]
}
Rules: never invent facts that are not in the notice. Use [] when nothing applies. Copy "source" text exactly from the notice.

NOTICE:
"""
${trimmed}
"""`;
  try {
    const out = await callLLM(prompt, 3000, true);
    const json = extractJson(out);
    json.deadlines = (json.deadlines || [])
      .map((d) => ({ title: d.title, date: new Date(d.date).toISOString() }))
      .filter((d) => d.date && !isNaN(new Date(d.date)));
    if (json.deadlines.length > 0) {
      json.urgency = computeUrgency(json.deadlines[0].date, json.urgency);
    }
    return { ...json, analyzedBy: provider() };
  } catch (e) {
    console.error('AI analyze failed, using offline analyzer:', e.message);
    return { ...offlineAnalyze(trimmed), analyzedBy: 'offline' };
  }
}

async function translateText(text, lang) {
  if (!hasKey()) {
    const err = new Error(
      'Translation needs an AI key. Add GEMINI_API_KEY (free) to backend/.env and restart the server.'
    );
    err.status = 503;
    throw err;
  }
  const language = LANG_NAMES[lang] || lang;
  const out = await callLLM(
    `Translate the following text into ${language}. Keep it simple and natural, keep numbers, dates and amounts unchanged. Reply with the translation only.\n\n${text}`,
    1500
  );
  return out.trim();
}

async function draftReply(notice, goal) {
  if (!hasKey()) {
    return `Subject: Regarding ${notice.title}\n\nRespected Sir/Madam,\n\nI have received your notice regarding "${notice.title}". ${
      goal ? goal + '\n\n' : ''
    }Kindly acknowledge this letter and let me know if any further information is required from my side.\n\nThank you.\n\nYours faithfully,\n[Your Name]\n[Your Contact Details]`;
  }
  return (
    await callLLM(
      `Write a short, polite, professional reply letter (or email with a subject line) responding to the notice below.
The sender's goal: ${goal || 'acknowledge the notice and ask for any clarification needed'}.
Leave [Your Name] and [Your Contact Details] as placeholders. Do not invent facts.

NOTICE SUMMARY: ${notice.summary?.detailed || ''}
KEY ORIGINAL TEXT: ${notice.originalText.slice(0, 3000)}`,
      1200
    )
  ).trim();
}

module.exports = { analyzeNotice, translateText, draftReply, LANG_NAMES, hasKey, provider };