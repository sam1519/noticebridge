// Rule-based analyzer used when no AI key is configured (or the AI call fails).
// It is basic but lets the whole app run offline for demos.

const { computeUrgency } = require('./urgency');

const MONTHS = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2, apr: 3, april: 3, may: 4,
  jun: 5, june: 5, jul: 6, july: 6, aug: 7, august: 7, sep: 8, sept: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

const CATEGORY_WORDS = {
  tax: ['income tax', 'gst', 'tax', 'assessment', 'itr', 'tds', 'revenue'],
  bank: ['bank', 'loan', 'emi', 'account', 'overdue', 'credit', 'kyc'],
  college: ['college', 'university', 'semester', 'exam', 'fee', 'admission', 'hall ticket', 'student'],
  legal: ['court', 'legal', 'advocate', 'hearing', 'summons', 'tribunal', 'lawsuit'],
  govt: ['government', 'ministry', 'municipal', 'corporation', 'department', 'panchayat', 'aadhaar', 'passport'],
  utility: ['electricity', 'water bill', 'gas', 'broadband', 'meter', 'utility'],
};

const HIGH_WORDS = ['legal action', 'penalty', 'disconnect', 'cancel', 'immediately', 'final notice', 'last date', 'last warning', 'court', 'fine', 'blocked', 'terminated'];

function splitSentences(text) {
  return text
    .replace(/\s+/g, ' ')
    .split(/(?<=(?<!\b(?:Rs|No|Dr|Mr|Mrs|Ms|St|Sr|Jr))[.!?])\s+(?=[A-Z0-9₹])|\n+/)
    .map((s) => s.trim())
    .filter((s) => s.length >= 4);
}

function parseDatesIn(sentence) {
  const found = [];
  let m;
  // 15/03/2026, 15-03-2026, 15.03.2026
  const numeric = /\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/g;
  while ((m = numeric.exec(sentence))) {
    let y = +m[3];
    if (y < 100) y += 2000;
    const d = new Date(Date.UTC(y, +m[2] - 1, +m[1], 12));
    if (!isNaN(d)) found.push(d);
  }
  // 15 March 2026 / 15th March, 2026
  const dmy = /\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})\b/g;
  while ((m = dmy.exec(sentence))) {
    const mon = MONTHS[m[2].toLowerCase()];
    if (mon !== undefined) found.push(new Date(Date.UTC(+m[3], mon, +m[1], 12)));
  }
  // March 15, 2026
  const mdy = /\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b/g;
  while ((m = mdy.exec(sentence))) {
    const mon = MONTHS[m[1].toLowerCase()];
    if (mon !== undefined) found.push(new Date(Date.UTC(+m[3], mon, +m[2], 12)));
  }
  return found;
}

function analyze(text) {
  const sentences = splitSentences(text);
  const lower = text.toLowerCase();

  // category
  let category = 'other';
  let best = 0;
  for (const [cat, words] of Object.entries(CATEGORY_WORDS)) {
    const score = words.reduce((n, w) => n + (lower.includes(w) ? 1 : 0), 0);
    if (score > best) {
      best = score;
      category = cat;
    }
  }

  // deadlines
  const deadlines = [];
  for (const s of sentences) {
    for (const d of parseDatesIn(s)) {
      deadlines.push({ title: s.length > 120 ? s.slice(0, 117) + '...' : s, date: d.toISOString() });
    }
  }
  deadlines.sort((a, b) => new Date(a.date) - new Date(b.date));

  // amounts
  const amounts = [
    ...new Set(
      (text.match(/(?:(?:₹|Rs\.?|INR|USD|\$)\s?\d[\d,]*(?:\.\d+)?|\b(?:pay|fee|amount|fine|due)\s+(?:₹|Rs\.?|INR|USD|\$)?\s*\d[\d,]*)\b/gi) || [])
        .map((a) => a.trim())
    ),
  ].slice(0, 6);

  // actions & documents
  const actionRe = /\b(must|should|required|requested|shall|please|kindly|submit|pay|attend|appear|reply|respond|visit|bring|attach|furnish)\b/i;
  const actions = sentences.filter((s) => actionRe.test(s)).slice(0, 6);
  const docRe = /\b(submit|attach|enclose|carry|bring|furnish|produce)\b/i;
  const documentsNeeded = sentences.filter((s) => docRe.test(s)).slice(0, 4);

  // urgency: <= 5 days high, 6-15 days medium, > 15 days low
  const highHit = HIGH_WORDS.some((w) => lower.includes(w));
  let urgency = 'low';
  if (deadlines.length > 0) {
    urgency = computeUrgency(deadlines[0].date, highHit ? 'medium' : 'low');
  } else if (highHit) {
    urgency = 'medium';
  }

  const riskIfIgnored = highHit
    ? 'The notice mentions penalties or serious consequences. Ignoring it may lead to fines or further action.'
    : deadlines.length
    ? 'You may miss the deadline mentioned in the notice, which could cause delays or extra charges.'
    : 'No serious consequence is clearly stated, but it is safer to read and respond if needed.';

  const first = sentences.slice(0, 2).join(' ');
  const verySimple = (sentences[0] || text).slice(0, 160);
  const detailed = sentences.slice(0, 6).join(' ');

  const title = (sentences[0] || 'Notice').replace(/^(subject|sub|re)\s*[:\-]\s*/i, '').slice(0, 70);

  const highlights = [];
  if (sentences[0]) highlights.push({ point: 'Main message of the notice', source: sentences[0] });
  if (deadlines[0]) highlights.push({ point: 'Deadline mentioned', source: deadlines[0].title });
  const amtSentence = sentences.find((s) => amounts.length && s.includes(amounts[0]));
  if (amtSentence) highlights.push({ point: 'Amount involved', source: amtSentence });
  if (actions[0]) highlights.push({ point: 'What you need to do', source: actions[0] });

  return {
    title,
    category,
    summary: { simple: first || text.slice(0, 300), verySimple, detailed: detailed || text.slice(0, 600) },
    urgency,
    riskIfIgnored,
    amounts,
    documentsNeeded,
    highlights,
    deadlines,
    actions,
  };
}

module.exports = { analyze };
