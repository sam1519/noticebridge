const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    preferredLang: { type: String, default: 'hi' },
    readingLevel: { type: String, enum: ['simple', 'verySimple', 'detailed'], default: 'simple' },
    isEmailVerified: { type: Boolean, default: true },
    authProvider: { type: String, default: 'email' },
    avatarUrl: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
