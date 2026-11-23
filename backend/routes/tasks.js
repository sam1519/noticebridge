const router = require('express').Router();
const auth = require('../middleware/auth');
const Task = require('../models/Task');
const { computeUrgency } = require('../services/urgency');

router.use(auth);

// All tasks of the logged-in user (pending first, earliest deadline first).
router.get('/', async (req, res, next) => {
  try {
    const tasks = await Task.find({ userId: req.userId })
      .populate('noticeId', 'title urgency deadline')
      .lean();
    for (const t of tasks) {
      if (t.noticeId) {
        const d = t.dueDate || t.noticeId.deadline;
        if (d) {
          t.noticeId.urgency = computeUrgency(d, t.noticeId.urgency);
        }
      }
    }
    tasks.sort((a, b) => {
      if (a.status !== b.status) return a.status === 'pending' ? -1 : 1;
      const da = a.dueDate ? new Date(a.dueDate).getTime() : Infinity;
      const db = b.dueDate ? new Date(b.dueDate).getTime() : Infinity;
      return da - db;
    });
    res.json({ tasks });
  } catch (e) {
    next(e);
  }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const update = {};
    if (req.body.status) update.status = req.body.status;
    if (req.body.dueDate !== undefined) update.dueDate = req.body.dueDate;
    const task = await Task.findOneAndUpdate({ _id: req.params.id, userId: req.userId }, update, { new: true });
    if (!task) return res.status(404).json({ message: 'Task not found' });
    res.json({ task });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
