const router = require('express').Router();
const Notice = require('../models/Notice');
const Task = require('../models/Task');
const { computeUrgency } = require('../services/urgency');

const esc = (s = '') =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Public, read-only page a family member can open in any browser (no login).
router.get('/:token', async (req, res, next) => {
  try {
    const n = await Notice.findOne({ shareToken: req.params.token });
    if (!n) return res.status(404).send('This shared notice does not exist.');
    const tasks = await Task.find({ noticeId: n._id }).sort({ dueDate: 1 });
    const dl = n.deadline || tasks.find((t) => t.dueDate)?.dueDate;
    const currentUrgency = dl ? computeUrgency(dl, n.urgency) : n.urgency;
    const color = { high: '#d32f2f', medium: '#f57c00', low: '#388e3c' }[currentUrgency];
    res.send(`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(n.title)} - NoticeBridge</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:0 auto;padding:20px;background:#f4f6fb;color:#1c2333}
.card{background:#fff;border-radius:14px;padding:18px;margin-bottom:14px;box-shadow:0 1px 6px #0001}
.badge{display:inline-block;color:#fff;background:${color};padding:3px 12px;border-radius:99px;font-size:13px;font-weight:600}
h1{font-size:22px}h3{margin:0 0 8px}li{margin-bottom:6px}</style></head><body>
<h1>${esc(n.title)}</h1><span class="badge">${esc(currentUrgency.toUpperCase())} urgency</span>
<div class="card"><h3>Summary</h3><p>${esc(n.summary?.simple)}</p></div>
<div class="card"><h3>What if ignored?</h3><p>${esc(n.riskIfIgnored)}</p></div>
<div class="card"><h3>To do</h3><ul>${tasks
      .map((t) => `<li>${esc(t.title)}${t.dueDate ? ` <b>(by ${t.dueDate.toDateString()})</b>` : ''}</li>`)
      .join('') || '<li>Nothing specific.</li>'}</ul></div>
<p style="color:#667;font-size:12px">Shared via NoticeBridge. This is a simplified explanation, not legal advice.</p>
</body></html>`);
  } catch (e) {
    next(e);
  }
});

module.exports = router;
