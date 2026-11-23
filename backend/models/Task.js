const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    noticeId: { type: mongoose.Schema.Types.ObjectId, ref: 'Notice', required: true, index: true },
    title: { type: String, required: true },
    dueDate: { type: Date, default: null },
    status: { type: String, enum: ['pending', 'done'], default: 'pending' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Task', taskSchema);
