const router = require('express').Router();
const multer = require('multer');
const crypto = require('crypto');
const auth = require('../middleware/auth');
const Notice = require('../models/Notice');
const Task = require('../models/Task');
const { analyzeNotice, translateText, draftReply } = require('../services/ai');
const { extractText } = require('../services/extract');
const { computeUrgency, extractFirstDate } = require('../services/urgency');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

router.use(auth);

// Create a notice from pasted text or an uploaded file, then analyze it.
router.post('/', upload.single('file'), async (req, res, next) => {
  try {
    let text = (req.body.text || '').trim();
    if (req.file) text = ((await extractText(req.file)) || '').trim();
    if (text.length < 5)
      return res.status(400).json({ message: 'Please enter notice text or upload a clearer file.' });

    const result = await analyzeNotice(text);

    const firstDue = (result.deadlines || [])[0]?.date ? new Date((result.deadlines || [])[0].date) : null;
    const finalUrgency = computeUrgency(firstDue, result.urgency);

    const notice = await Notice.create({
      userId: req.userId,
      title: result.title || 'Notice',
      originalText: text,
      category: result.category || 'other',
      summary: result.summary,
      deadline: firstDue,
      urgency: finalUrgency,
      riskIfIgnored: result.riskIfIgnored,
      amounts: result.amounts || [],
      documentsNeeded: result.documentsNeeded || [],
      highlights: result.highlights || [],
      analyzedBy: result.analyzedBy,
    });

    // Build the action checklist: dated tasks from deadlines + undated tasks from actions.
    const tasks = [];
    for (const d of result.deadlines || []) {
      tasks.push({ userId: req.userId, noticeId: notice._id, title: d.title, dueDate: d.date });
    }
    for (const a of result.actions || []) {
      if (!tasks.some((t) => t.title === a)) {
        tasks.push({ userId: req.userId, noticeId: notice._id, title: a, dueDate: firstDue });
      }
    }
    const createdTasks = tasks.length ? await Task.insertMany(tasks.slice(0, 10)) : [];

    res.status(201).json({ notice, tasks: createdTasks });
  } catch (e) {
    next(e);
  }
});

router.get('/', async (req, res, next) => {
  try {
    const notices = await Notice.find({ userId: req.userId })
      .select('-originalText')
      .sort({ createdAt: -1 })
      .lean();

    // Dynamically calculate urgency based on current date (<=5 high, 6-15 mid, >15 less)
    const tasks = await Task.find({ userId: req.userId, status: 'pending', dueDate: { $ne: null } })
      .sort({ dueDate: 1 })
      .lean();

    const taskMap = {};
    for (const t of tasks) {
      const nid = t.noticeId.toString();
      if (!taskMap[nid] || new Date(t.dueDate) < new Date(taskMap[nid])) {
        taskMap[nid] = t.dueDate;
      }
    }

    for (const n of notices) {
      let dl = n.deadline || taskMap[n._id.toString()];
      if (!dl) {
        dl = extractFirstDate(n.summary?.simple || n.summary?.detailed || n.originalText);
      }
      if (dl) {
        n.deadline = dl;
        n.urgency = computeUrgency(dl, n.urgency);
      }
    }

    res.json({ notices });
  } catch (e) {
    next(e);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const notice = await Notice.findOne({ _id: req.params.id, userId: req.userId }).lean();
    if (!notice) return res.status(404).json({ message: 'Notice not found' });
    const tasks = await Task.find({ noticeId: notice._id }).sort({ dueDate: 1 });
    let dl = notice.deadline || tasks.find((t) => t.dueDate && t.status !== 'done')?.dueDate || tasks.find((t) => t.dueDate)?.dueDate;
    if (!dl) {
      dl = extractFirstDate(notice.summary?.simple || notice.summary?.detailed || notice.originalText);
    }
    if (dl) {
      notice.deadline = dl;
      notice.urgency = computeUrgency(dl, notice.urgency);
    }
    res.json({ notice, tasks });
  } catch (e) {
    next(e);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const notice = await Notice.findOneAndDelete({ _id: req.params.id, userId: req.userId });
    if (!notice) return res.status(404).json({ message: 'Notice not found' });
    await Task.deleteMany({ noticeId: notice._id });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

router.post('/:id/translate', async (req, res, next) => {
  try {
    const { lang } = req.body;
    if (!lang) return res.status(400).json({ message: 'lang is required' });
    const notice = await Notice.findOne({ _id: req.params.id, userId: req.userId });
    if (!notice) return res.status(404).json({ message: 'Notice not found' });

    const cached = notice.translations.get(lang);
    if (cached) return res.json({ lang, text: cached });

    const source = [
      notice.summary?.simple,
      notice.riskIfIgnored && `Risk: ${notice.riskIfIgnored}`,
    ]
      .filter(Boolean)
      .join('\n\n');
    const text = await translateText(source, lang);
    notice.translations.set(lang, text);
    await notice.save();
    res.json({ lang, text });
  } catch (e) {
    next(e);
  }
});

router.post('/:id/reply-draft', async (req, res, next) => {
  try {
    const notice = await Notice.findOne({ _id: req.params.id, userId: req.userId });
    if (!notice) return res.status(404).json({ message: 'Notice not found' });
    const draft = await draftReply(notice, req.body.goal);
    res.json({ draft });
  } catch (e) {
    next(e);
  }
});

router.post('/:id/share', async (req, res, next) => {
  try {
    const notice = await Notice.findOne({ _id: req.params.id, userId: req.userId });
    if (!notice) return res.status(404).json({ message: 'Notice not found' });
    if (!notice.shareToken) {
      notice.shareToken = crypto.randomBytes(12).toString('hex');
      await notice.save();
    }
    const url = `${req.protocol}://${req.get('host')}/api/share/${notice.shareToken}`;
    res.json({ url });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
