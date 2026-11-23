const mongoose = require('mongoose');

module.exports = async function connectDB() {
  try {
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/noticebridge');
    console.log('MongoDB connected');
  } catch (e) {
    console.error('MongoDB connection failed:', e.message);
    console.error('Check that MongoDB is running and MONGO_URI in .env is correct.');
    process.exit(1);
  }
};
