# NoticeBridge – AI-Powered Notice Understanding System

Turn complex notices (tax, bank, college, legal, government, utility) into:
simple summaries · urgency + "what if I ignore this?" · multilingual text with read-aloud ·
action checklist · deadline tracking · reply drafts · family share link.

**Stack:** Flutter (UI) · Node.js + Express (API) · MongoDB (database) · optional AI (Claude API)

```
noticebridge/
├── backend/          Node.js + Express + MongoDB API
├── app/              Flutter app (mobile / web / Windows)
└── sample_notices/   Two text notices to test with
```

---

## 1. Prerequisites (install these first)

| # | Software | Needed for | Download |
|---|----------|-----------|----------|
| 1 | **Node.js 18 or newer (LTS)** | Backend | https://nodejs.org |
| 2 | **MongoDB** – choose ONE: <br>a) MongoDB Community Server + Compass (local) <br>b) MongoDB Atlas free cluster (cloud, no install) | Database | https://www.mongodb.com/try/download/community  ·  https://www.mongodb.com/cloud/atlas |
| 3 | **Flutter SDK (3.19 or newer)** | App | https://docs.flutter.dev/get-started/install/windows |
| 4 | **Google Chrome** | Easiest way to run the app | https://www.google.com/chrome |
| 5 | **VS Code** (recommended editor) + Flutter extension | Editing | https://code.visualstudio.com |
| 6 | *Optional:* **Android Studio** | Android emulator / phone | https://developer.android.com/studio |
| 7 | *Optional:* **Anthropic API key** | Full AI summaries, translation, reply drafts | https://console.anthropic.com |

Notes
- You do **not** need an API key to start. Without one the backend uses a built-in rule-based analyzer
  (summary, dates, amounts, urgency, tasks all work; **translation and AI reply drafts need the key**).
- Reading text from **photos** uses Tesseract OCR, which downloads its English language data the first
  time you upload an image, so the laptop needs internet at least once for that.
- Windows desktop builds of Flutter additionally need **Visual Studio 2022 with "Desktop development with C++"**.
  Skip it by using Chrome or Android instead.
- Check your setup: open PowerShell and run `node -v`, `npm -v`, `flutter doctor`.

---

## 2. Run the backend

```powershell
cd backend
copy .env.example .env        # then open .env and check MONGO_URI (and add ANTHROPIC_API_KEY if you have one)
npm install
npm start
```

You should see `MongoDB connected` and `NoticeBridge API running on http://localhost:5000`.
Open http://localhost:5000 in a browser; it shows `"status": "running"` and which AI mode is active.

MongoDB options for `MONGO_URI`:
- **Local:** `mongodb://127.0.0.1:27017/noticebridge` (MongoDB Community must be running as a service)
- **Atlas:** paste the connection string from Atlas (allow your IP under *Network Access*)

## 3. Run the Flutter app

Open a **second** PowerShell window:

```powershell
cd app
.\setup.ps1                   # one time: creates android/web/windows folders and installs packages
flutter run -d chrome
```

If PowerShell blocks the script: `Set-ExecutionPolicy -Scope Process Bypass` then run it again.

Other targets: `flutter run -d windows`, or start an Android emulator and use `flutter run`.

### Which backend URL does the app use?
| Where the app runs | URL (set automatically) |
|---|---|
| Chrome / Windows | `http://127.0.0.1:5000` |
| Android emulator | `http://10.0.2.2:5000` |
| Real phone on same Wi-Fi | `http://<laptop-IP>:5000` – set it in the app: **Login screen → Server settings** |

(For a real phone, find your laptop IP with `ipconfig`, and allow Node.js through Windows Firewall.)

## 4. Try it
1. Create an account in the app.
2. **Add notice** → paste the text from `sample_notices/property_tax_notice.txt`
   (or upload that file, any PDF, or a photo of a notice).
3. Explore the tabs: **Summary** (urgency, risk, source-linked highlights, read aloud),
   **Translate**, **Tasks**, **Reply**. Use the share icon for a family link.
4. The **Deadlines** tab collects tasks from all notices; the home screen warns about tasks due soon.

---

## 5. API reference (for your report)

| Method | Route | Purpose |
|---|---|---|
| POST | `/api/auth/register`, `/api/auth/login` | Create account / log in (JWT) |
| GET / PATCH | `/api/auth/me` | Profile, preferred language, reading level |
| POST | `/api/notices` | Upload file or text → analyze → create notice + tasks |
| GET | `/api/notices`, `/api/notices/:id` | List / read notices |
| DELETE | `/api/notices/:id` | Delete notice and its tasks |
| POST | `/api/notices/:id/translate` | Translate summary (cached in MongoDB) |
| POST | `/api/notices/:id/reply-draft` | Draft a reply letter |
| POST | `/api/notices/:id/share` | Create public read-only share link |
| GET | `/api/share/:token` | Public family view page |
| GET / PATCH | `/api/tasks`, `/api/tasks/:id` | Deadline checklist |

MongoDB collections: `users`, `notices`, `tasks`.

## 6. Troubleshooting
| Problem | Fix |
|---|---|
| `MongoDB connection failed` | Start the MongoDB service, or fix `MONGO_URI` / Atlas IP access list |
| App says "Cannot reach the server" | Backend not running, or wrong URL (see table above) |
| Translate says "needs an AI key" | Add `ANTHROPIC_API_KEY` to `backend/.env`, restart `npm start` |
| Photo upload is slow / fails | First OCR run downloads language data; use a clear, well-lit photo, or paste text |
| `flutter` not recognized | Add `flutter\bin` to PATH, reopen PowerShell, run `flutter doctor` |

## 7. Ideas to extend
Push notifications (Firebase Cloud Messaging) · scheduled email reminders · React admin dashboard ·
more languages · handwriting OCR · deploy backend to Render/Railway.

*NoticeBridge provides simplified explanations only. It is not legal or financial advice.*
