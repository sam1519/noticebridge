require('dotenv').config();
const express = require('express');
const cors = require('cors');
const connectDB = require('./config/db');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

app.get('/', (req, res) =>
  res.json({
    app: 'NoticeBridge API',
    status: 'running',
    ai: require('./services/ai').provider(),
  })
);

app.use('/api/auth', require('./routes/auth'));
app.use('/api/notices', require('./routes/notices'));
app.use('/api/tasks', require('./routes/tasks'));
app.use('/api/share', require('./routes/share'));

app.use((err, req, res, next) => {
  console.error(err);
  res.status(err.status || 500).json({ message: err.message || 'Server error' });
});

const PORT = process.env.PORT || 5000;
connectDB().then(() => {
  app.listen(PORT, () => console.log(`NoticeBridge API running on http://localhost:${PORT}`));
});
