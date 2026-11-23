const mongoose = require('mongoose');

const noticeSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, default: 'Untitled notice' },
    originalText: { type: String, required: true },
    category: { type: String, default: 'other' }, // tax | bank | college | legal | govt | utility | other
    summary: {
      simple: String,
      verySimple: String,
      detailed: String,
    },
    deadline: { type: Date, default: null },
    urgency: { type: String, enum: ['low', 'medium', 'high'], default: 'low' },
    riskIfIgnored: String,
    amounts: [String],
    documentsNeeded: [String],
    highlights: [
      {
        point: String,
        source: String, // exact sentence from the original notice
      },
    ],
    translations: { type: Map, of: String, default: {} }, // lang code -> translated simple summary
    analyzedBy: { type: String, default: 'offline' }, // 'claude' | 'offline'
    shareToken: { type: String, index: true, sparse: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Notice', noticeSchema);
