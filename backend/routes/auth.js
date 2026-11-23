const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const auth = require('../middleware/auth');

const sign = (user) =>
  jwt.sign({ id: user._id }, process.env.JWT_SECRET || 'dev_secret', { expiresIn: '30d' });

const publicUser = (u) => ({
  id: u._id,
  name: u.name,
  email: u.email,
  preferredLang: u.preferredLang || 'hi',
  readingLevel: u.readingLevel || 'simple',
  isEmailVerified: u.isEmailVerified ?? true,
  authProvider: u.authProvider || 'email',
  avatarUrl: u.avatarUrl || '',
});

// Damerau-Levenshtein distance for catching professional email typos
function damerauLevenshtein(a, b) {
  const al = a.length, bl = b.length;
  const d = Array(al + 1).fill(null).map(() => Array(bl + 1).fill(0));
  for (let i = 0; i <= al; i++) d[i][0] = i;
  for (let j = 0; j <= bl; j++) d[0][j] = j;
  for (let i = 1; i <= al; i++) {
    for (let j = 1; j <= bl; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost
      );
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[al][bl];
}

const POPULAR_DOMAINS = [
  'gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com',
  'icloud.com', 'live.com', 'proton.me', 'zoho.com'
];

const PROVIDER_NAMES = new Set([
  'gmail', 'yahoo', 'outlook', 'hotmail', 'icloud', 'proton', 'zoho', 'live', 'msn', 'aol'
]);

// Official Domain Validation & Typo Detection
const INVALID_TLDS = new Set(['vom', 'con', 'cmo', 'cpm', 'col', 'comm', 'xom', 'fak', 'testt', 'cm', 'coom']);
const TYPO_DOMAINS = {
  'com.gmail': 'gmail.com',
  'in.gmail': 'gmail.com',
  'co.gmail': 'gmail.com',
  'org.gmail': 'gmail.com',
  'net.gmail': 'gmail.com',
  'com.yahoo': 'yahoo.com',
  'com.outlook': 'outlook.com',
  'gmali.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gmial.com': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gmall.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmaik.com': 'gmail.com',
  'mil.com': 'gmail.com',
  'gila.vom': 'gmail.com',
  'gila.com': 'gmail.com',
  'gmail.vom': 'gmail.com',
  'yaho.com': 'yahoo.com',
  'yahooo.com': 'yahoo.com',
  'hotmial.com': 'hotmail.com',
  'hotamil.com': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outloo.com': 'outlook.com',
  'iclud.com': 'icloud.com',
};

const VALID_TLDS = new Set([
  'com', 'org', 'net', 'edu', 'gov', 'mil', 'int', 'info', 'biz',
  'io', 'co', 'in', 'ai', 'app', 'dev', 'me', 'tech', 'cloud',
  'online', 'site', 'store', 'global', 'uk', 'us', 'ca', 'au',
  'de', 'fr', 'jp', 'cn', 'br', 'za', 'eu', 'ac', 'ch', 'nl', 'se', 'no',
  'es', 'it', 'ru', 'mx', 'sg', 'nz', 'ie', 'tv', 'cc', 'xyz', 'pro', 'name'
]);

function detectDomainTypo(domain) {
  if (POPULAR_DOMAINS.includes(domain)) return null;
  if (TYPO_DOMAINS[domain]) return TYPO_DOMAINS[domain];

  const domainParts = domain.split('.');
  if (domainParts.length === 2) {
    const sub = domainParts[0];
    const tld = domainParts[1];
    // Catch reversed domains like com.gmail, in.gmail, co.gmail
    if (PROVIDER_NAMES.has(tld)) {
      if (['com', 'org', 'net', 'in', 'co'].includes(sub)) {
        return `${tld}.${sub === 'co' ? 'com' : sub}`;
      }
      return `${tld}.com`;
    }
  }

  for (const pop of POPULAR_DOMAINS) {
    if (damerauLevenshtein(domain, pop) <= 2) {
      return pop;
    }
  }
  return null;
}

function validateOfficialEmail(email) {
  if (!email || typeof email !== 'string') {
    return { valid: false, message: 'Email address is required' };
  }
  const cleanEmail = email.trim().toLowerCase();
  const basicRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  if (!basicRegex.test(cleanEmail)) {
    return { valid: false, message: 'Please enter a valid official email address (e.g. name@example.com)' };
  }
  const parts = cleanEmail.split('@');
  if (parts.length !== 2) {
    return { valid: false, message: 'Invalid email format' };
  }
  const domain = parts[1];
  const domainParts = domain.split('.');
  if (domainParts.length < 2) {
    return { valid: false, message: 'Invalid email domain: missing domain extension' };
  }
  const tld = domainParts[domainParts.length - 1];

  const typoSuggestion = detectDomainTypo(domain);
  if (typoSuggestion) {
    return {
      valid: false,
      message: `Invalid email domain "${domain}". Did you mean @${typoSuggestion}?`,
      suggestion: `${parts[0]}@${typoSuggestion}`,
    };
  }

  if (PROVIDER_NAMES.has(tld)) {
    return {
      valid: false,
      message: `Invalid domain extension ".${tld}". "${tld}" is a provider name, not a valid top-level domain. Did you mean @${tld}.com?`,
      suggestion: `${parts[0]}@${tld}.com`,
    };
  }

  if (INVALID_TLDS.has(tld)) {
    return {
      valid: false,
      message: `Invalid top-level domain ".${tld}". Official emails require valid extensions (.com, .org, .edu, etc.)`,
    };
  }

  if (!VALID_TLDS.has(tld)) {
    return {
      valid: false,
      message: `Unrecognized email domain extension ".${tld}". Official emails require standard extensions (.com, .org, .in, etc.).`,
    };
  }

  return { valid: true, cleanEmail };
}

function validatePasswordStrength(password) {
  if (!password || password.length < 8) {
    return 'Password must be at least 8 characters long';
  }
  if (!/[A-Z]/.test(password)) {
    return 'Password must contain at least one uppercase letter (A-Z)';
  }
  if (!/[a-z]/.test(password)) {
    return 'Password must contain at least one lowercase letter (a-z)';
  }
  if (!/[0-9]/.test(password)) {
    return 'Password must contain at least one number (0-9)';
  }
  if (!/[^a-zA-Z0-9\s]/.test(password)) {
    return 'Password must contain at least one special character (!@#$%^&*)';
  }
  if (/\s/.test(password)) {
    return 'Password cannot contain spaces';
  }
  return null;
}

// 1. Official Registration
router.post('/register', async (req, res, next) => {
  try {
    const username = (req.body.username || req.body.name || '').trim();
    const email = (req.body.email || '').trim().toLowerCase();
    const password = req.body.password || '';

    // 1. Username validation: letters and spaces, 3-50 chars
    if (!username) {
      return res.status(400).json({ message: 'Full name or username is required' });
    }
    if (username.length < 3 || username.length > 50) {
      return res.status(400).json({ message: 'Name must be between 3 and 50 characters' });
    }
    if (!/^[a-zA-Z\s]+$/.test(username)) {
      return res.status(400).json({ message: 'Name must contain only letters and spaces' });
    }

    // 2. Strict Official Email validation (rejects fake domains like .vom)
    const emailCheck = validateOfficialEmail(email);
    if (!emailCheck.valid) {
      return res.status(400).json({
        message: emailCheck.message,
        suggestion: emailCheck.suggestion,
      });
    }

    // 3. Password validation
    const passError = validatePasswordStrength(password);
    if (passError) {
      return res.status(400).json({ message: passError });
    }

    if (await User.findOne({ email })) {
      return res.status(409).json({ message: 'An account with this email already exists' });
    }

    const user = await User.create({
      name: username,
      email,
      passwordHash: await bcrypt.hash(password, 10),
      isEmailVerified: true,
      authProvider: 'email',
    });

    res.status(201).json({ token: sign(user), user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

// 2. Official Login
router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const cleanEmail = (email || '').trim().toLowerCase();

    const emailCheck = validateOfficialEmail(cleanEmail);
    if (!emailCheck.valid) {
      return res.status(400).json({
        message: emailCheck.message,
        suggestion: emailCheck.suggestion,
      });
    }

    const user = await User.findOne({ email: cleanEmail });
    if (!user || !(await bcrypt.compare(password || '', user.passwordHash))) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    res.json({ token: sign(user), user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

// 3. Official Google Sign-In / SSO
router.post('/google', async (req, res, next) => {
  try {
    const { email, name, avatarUrl } = req.body;
    const cleanEmail = (email || '').trim().toLowerCase();

    const emailCheck = validateOfficialEmail(cleanEmail);
    if (!emailCheck.valid) {
      return res.status(400).json({ message: 'Invalid Google account email' });
    }

    let user = await User.findOne({ email: cleanEmail });
    if (!user) {
      // Create new verified account for Google user
      const randomPass = crypto.randomBytes(16).toString('hex') + 'A1!';
      const passwordHash = await bcrypt.hash(randomPass, 10);
      user = await User.create({
        name: (name || cleanEmail.split('@')[0]).trim(),
        email: cleanEmail,
        passwordHash,
        isEmailVerified: true,
        authProvider: 'google',
        avatarUrl: avatarUrl || '',
      });
    } else {
      // Update Google metadata if needed
      user.isEmailVerified = true;
      if (avatarUrl && !user.avatarUrl) user.avatarUrl = avatarUrl;
      await user.save();
    }

    res.json({ token: sign(user), user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

// 4. Password Reset (Official self-service reset)
router.post('/reset-password', async (req, res, next) => {
  try {
    const { email, newPassword } = req.body;
    const cleanEmail = (email || '').trim().toLowerCase();

    const emailCheck = validateOfficialEmail(cleanEmail);
    if (!emailCheck.valid) {
      return res.status(400).json({ message: emailCheck.message });
    }

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(404).json({ message: 'No registered account found with this email' });
    }

    const passError = validatePasswordStrength(newPassword);
    if (passError) {
      return res.status(400).json({ message: passError });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ success: true, message: 'Password has been reset successfully. Please log in.' });
  } catch (e) {
    next(e);
  }
});

// 5. Get current profile
router.get('/me', auth, async (req, res, next) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });
    res.json({ user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

// 6. Update Profile (Name, Email, Preferences, Password)
router.patch('/me', auth, async (req, res, next) => {
  try {
    const { preferredLang, readingLevel, name, email, newPassword, currentPassword } = req.body;
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'User not found' });

    if (preferredLang) user.preferredLang = preferredLang;
    if (readingLevel) user.readingLevel = readingLevel;

    // Name update
    if (name !== undefined) {
      const cleanName = name.trim();
      if (cleanName.length < 3 || cleanName.length > 50) {
        return res.status(400).json({ message: 'Name must be between 3 and 50 characters' });
      }
      if (!/^[a-zA-Z\s]+$/.test(cleanName)) {
        return res.status(400).json({ message: 'Name must contain only letters and spaces' });
      }
      user.name = cleanName;
    }

    // Email update (e.g. fixing typos like ram@gila.vom -> ram@gmail.com)
    if (email !== undefined) {
      const cleanEmail = email.trim().toLowerCase();
      if (cleanEmail !== user.email) {
        const emailCheck = validateOfficialEmail(cleanEmail);
        if (!emailCheck.valid) {
          return res.status(400).json({
            message: emailCheck.message,
            suggestion: emailCheck.suggestion,
          });
        }
        const existing = await User.findOne({ email: cleanEmail, _id: { $ne: user._id } });
        if (existing) {
          return res.status(409).json({ message: 'This email is already in use by another account' });
        }
        user.email = cleanEmail;
        user.isEmailVerified = true;
      }
    }

    // Password change
    if (newPassword) {
      if (user.authProvider === 'email' && currentPassword) {
        const match = await bcrypt.compare(currentPassword, user.passwordHash);
        if (!match) {
          return res.status(400).json({ message: 'Current password is incorrect' });
        }
      }
      const passError = validatePasswordStrength(newPassword);
      if (passError) {
        return res.status(400).json({ message: passError });
      }
      user.passwordHash = await bcrypt.hash(newPassword, 10);
    }

    await user.save();
    res.json({ user: publicUser(user) });
  } catch (e) {
    next(e);
  }
});

module.exports = router;
