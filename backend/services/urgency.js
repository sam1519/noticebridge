/**
 * Urgency calculation:
 * - High urgency: <= 5 days remaining (including overdue)
 * - Mid urgency: 6 to 15 days remaining
 * - Less urgency: > 15 days remaining (or no deadline)
 */

const MONTHS = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2, apr: 3, april: 3, may: 4,
  jun: 5, june: 5, jul: 6, july: 6, aug: 7, august: 7, sep: 8, sept: 8, september: 8,
  oct: 9, october: 9, nov: 10, november: 10, dec: 11, december: 11,
};

function extractFirstDate(text) {
  if (!text) return null;
  const dmy = /\b(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})\b/i;
  const m1 = text.match(dmy);
  if (m1) {
    const mon = MONTHS[m1[2].toLowerCase()];
    if (mon !== undefined) return new Date(Date.UTC(+m1[3], mon, +m1[1], 12));
  }
  const mdy = /\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b/i;
  const m2 = text.match(mdy);
  if (m2) {
    const mon = MONTHS[m2[1].toLowerCase()];
    if (mon !== undefined) return new Date(Date.UTC(+m2[3], mon, +m2[2], 12));
  }
  const numeric = /\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/;
  const m3 = text.match(numeric);
  if (m3) {
    let y = +m3[3];
    if (y < 100) y += 2000;
    const d = new Date(Date.UTC(y, +m3[2] - 1, +m3[1], 12));
    if (!isNaN(d)) return d;
  }
  return null;
}

function computeUrgency(deadline, fallback = 'low') {
  if (!deadline) return fallback;
  const target = new Date(deadline);
  if (isNaN(target.getTime())) return fallback;

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const due = new Date(target.getFullYear(), target.getMonth(), target.getDate());
  const diffDays = Math.round((due - today) / (1000 * 60 * 60 * 24));

  if (diffDays <= 5) return 'high';      // 5 days or fewer (or overdue)
  if (diffDays <= 15) return 'medium';   // 6 to 15 days (around 15 days)
  return 'low';                         // beyond 15 days
}

module.exports = { computeUrgency, extractFirstDate };
