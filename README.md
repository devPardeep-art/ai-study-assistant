# Study Companion — Multi-AI Learning Assistant

> University of Sussex — Final Year Project  
> A Flutter mobile app powered by a FastAPI backend that uses multiple AI models to help students study smarter.

---

## What the App Does

Study Companion takes any piece of study material — typed text, an uploaded document, a photo of notes, or a voice recording — and automatically generates a **summary**, **flashcards**, and a **quiz** using AI. Users can run the same material through multiple AI models simultaneously and compare their outputs side-by-side, with quality metrics shown for each response.

The app is built for students who want to turn raw lecture notes or textbook content into interactive study aids without manually creating them.

---

## How It Works — End-to-End Flow

```
User input (text / file / camera / voice)
        │
        ▼
Flutter app sends request to FastAPI backend
        │
        ▼
Backend routes to selected AI model(s):
  ┌─────────────┬──────────────┬───────────────┬──────────────────────┐
  │ GPT-4o-mini │ Claude Haiku │ Gemini Flash  │ Local Ollama models  │
  │  (OpenAI)   │ (Anthropic)  │   (Google)    │ llama3/mistral/phi3  │
  └─────────────┴──────────────┴───────────────┴──────────────────────┘
        │
        ▼
Model returns: Summary + Flashcards + Quiz (in one structured output)
        │
        ▼
Backend runs NLP metrics on the output:
  Readability · Keyword coverage · ROUGE scores · Cosine similarity
        │
        ▼
Flutter displays results across tabbed screens with animations
```

---

## App Screens

### Home Screen (`home.dart`)
The main input hub. Students can enter study material four ways:
- **Type** — paste or type text directly into a text field
- **Upload** — pick a PDF, DOCX, or TXT file (up to 10 MB)
- **Camera** — point the camera at printed notes; Google ML Kit extracts the text via OCR
- **Voice** — speak study content; the app transcribes it in real time using the device microphone

After choosing input and selecting an AI model, the user taps **Process** to send the content to the backend.

---

### Results Screen (`Results_screen.dart`)
Displays the AI-generated output in four tabs:

| Tab | What it shows |
|-----|---------------|
| **Summary** | A 3–5 sentence plain-English summary of the material |
| **Flashcards** | 5 interactive Q&A cards — tap any card to flip and reveal the answer with a slide animation |
| **Quiz** | Multiple-choice quiz questions generated from the material |
| **Rate** | Sliders to rate the AI response on Clarity, Accuracy, and Usefulness |

> **Login required** — the Flashcards and Quiz tabs are only accessible when the user is signed in. Signed-out users see a login prompt with an explanation. The tab bar shows a padlock icon on locked tabs.

Quick NLP metrics (Readability, Keyword Coverage, ROUGE-1) are also shown as a preview below the summary. Tapping **Metrics** in the app bar opens the full metrics screen.

---

### Compare Screen (`Compare_screen.dart`)
Sends the same study material to multiple AI models at once and displays their outputs side-by-side in a chat-style conversation interface.

**How it works:**
1. The user pastes text and selects which models to run (any combination of the four local models and up to three cloud models)
2. All selected models run in parallel threads on the backend
3. Each model's response appears as a card, showing readability, keyword coverage, ROUGE-1, and response time
4. An **AI Recommendation** banner highlights which model was fastest, most readable, and had the best content coverage
5. Users can expand any model card to see the full output and then tap **Summary**, **Flashcards**, **Quiz**, or **Feedback** buttons — each opens a full-screen page with the selected view

**Follow-up questions** — after the initial comparison, a sticky input bar at the bottom lets the user ask follow-up questions. The app builds context from previous answers and sends everything back to all models simultaneously, creating a multi-turn conversation across multiple AIs.

**Sessions** — every conversation is auto-saved locally and appears in the Saved tab.

---

### Output Page (inside Compare Screen)
When a user taps Summary, Flashcards, Quiz, or Feedback on a model card, a full-screen page opens with four tabs:

- **Summary** — the model's plain-text summary
- **Flashcards** — interactive flip cards for that model's output
- **Quiz** — a fully interactive multiple-choice quiz; selecting all answers and tapping Submit reveals correct/incorrect answers with a score card, and the result is saved with a timestamp
- **Feedback** — rating sliders (Clarity, Accuracy, Usefulness) that submit the evaluation to the backend

---

### Metrics Screen (`metrics_screen.dart`)
Visual breakdown of NLP quality metrics for any AI response:

| Metric | What it measures |
|--------|-----------------|
| **Flesch Reading Ease** | How easy the output is to read (0–100 scale) |
| **Word / Sentence count** | Basic text statistics |
| **Keyword Coverage** | % of the original material's key terms that appear in the output |
| **ROUGE-1 / ROUGE-2 / ROUGE-L** | How much of the original content is preserved in the summary |
| **Cosine Similarity** | When comparing two models, how similar their outputs are |

---

### Saved Screen (`main.dart → SavedScreen`)
Lists all previously saved chat and compare sessions.

- **Login required** — if the user is not signed in, a lock screen is shown instead of the session list, with a "Login / Register" button
- Each conversation card shows the session title, AI model used, last message preview, message count, and timestamp
- **Continue Chat** button resumes the full multi-turn conversation exactly where it was left off
- **Exit button** (red × button next to "Continue Chat") lets the user remove a session from the list after a confirmation prompt
- **Clear All** in the header deletes all sessions at once

---

### Chat Screen (`chat_screen.dart`)
A dedicated conversational interface for asking questions to a single AI model. Supports multi-turn conversations where the app maintains message history and sends it back to the model on each turn. Sessions are auto-saved and can be resumed from the Saved tab.

---

### Login Screen (`Login_screen.dart`)
Two-tab screen for authentication:
- **Login** — email + password, returns a JWT stored in SharedPreferences
- **Register** — name, email, password; triggers a verification email via Gmail SMTP

Password reset is also available (forgot password → reset link sent by email).

---

### Subscription Screen (`Subscription_Screen.dart`)
Explains the Free vs Pro tier and handles the upgrade flow:

| Feature | Free (local models) | Pro (cloud models) |
|---------|--------------------|--------------------|
| Simple LLaMA 3 | ✅ | ✅ |
| Mistral | ✅ | ✅ |
| Phi-3 | ✅ | ✅ |
| Gemma | ✅ | ✅ |
| GPT-4o (OpenAI) | ❌ | ✅ |
| Claude (Anthropic) | ❌ | ✅ |
| Gemini (Google) | ❌ | ✅ |

---

## Backend — FastAPI (`app/`)

The Python backend handles all AI calls, file extraction, NLP analysis, and user authentication.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/debug` | GET | Check which API keys are configured |
| `/upload` | POST | Extract text from PDF/DOCX/TXT file |
| `/upload-and-process` | POST | Upload file + run through selected AI model |
| `/process` | POST | Process plain text with selected AI model |
| `/compare` | POST | Run text through multiple models in parallel threads |
| `/evaluate` | POST | Store user feedback (clarity, accuracy, usefulness) |
| `/auth/register` | POST | Create new user account, send verification email |
| `/auth/login` | POST | Authenticate and return JWT token |
| `/auth/verify-email` | GET | Confirm email address via token link |
| `/auth/forgot-password` | POST | Generate a 1-hour password reset token |
| `/auth/reset-password` | POST | Set new password using reset token |
| `/auth/me` | GET | Return the currently authenticated user's profile |

### AI Models

| Model ID | Provider | Notes |
|----------|----------|-------|
| `openai` | OpenAI | GPT-4o-mini — requires `OPENAI_API_KEY` |
| `claude` | Anthropic | Claude 3 Haiku — requires `ANTHROPIC_API_KEY` |
| `gemini` | Google | Gemini 2.0 Flash — requires `GEMINI_API_KEY` |
| `local` | Ollama (self-hosted) | Supports llama3, mistral, phi3, gemma |

All models implement the same interface: `summarise()`, `flashcards()`, `quiz()`, `process_all()`.  
If a cloud model fails, the backend automatically falls back to local LLaMA 3.

### Database (`study_companion.db`)
SQLite database managed by SQLAlchemy. The `users` table stores:
- `id`, `email`, `name`, `password_hash` (bcrypt)
- `is_verified`, `verification_token`
- `reset_token`, `reset_token_expiry`
- `is_subscribed`, `created_at`

---

## Quiz Result Saving

Every time a user submits a quiz in the app, the result is saved locally with:
- Model name that generated the quiz
- Score and total questions
- Percentage correct
- Full ISO 8601 timestamp of when it was attempted

Results are stored in SharedPreferences under the key `quiz_results` (up to 100 entries) and can be retrieved via `ApiService.getQuizResults()`.

---

## Project Structure

```
individual_project/
│
├── app/                          # FastAPI backend (Python)
│   ├── main.py                   # All API endpoints
│   ├── database.py               # SQLAlchemy + SQLite setup
│   ├── email_service.py          # Gmail SMTP for verification / reset emails
│   ├── auth/
│   │   ├── router.py             # Auth endpoints
│   │   └── utils.py              # JWT, bcrypt helpers
│   ├── models/
│   │   ├── user.py               # SQLAlchemy User model
│   │   ├── openai_model.py       # GPT-4o-mini integration
│   │   ├── claude_model.py       # Claude 3 Haiku integration
│   │   ├── gemini_model.py       # Gemini 2.0 Flash integration
│   │   └── local_model.py        # Ollama local model integration
│   └── utils/
│       ├── file_handler.py       # PDF / DOCX / TXT text extraction
│       └── nlp_metrics.py        # Readability, ROUGE, KeyBERT, cosine similarity
│
├── study_companion/              # Flutter mobile frontend
│   └── lib/
│       ├── main.dart             # App entry, routing, bottom nav, SavedScreen
│       ├── theme.dart            # Colours, text styles, kBaseUrl
│       ├── apiService.dart       # All HTTP calls to the FastAPI backend
│       ├── home.dart             # Input hub (text / file / camera / voice)
│       ├── Camera_Screen.dart    # Camera viewfinder + ML Kit OCR
│       ├── voice_screeen.dart    # Microphone + speech-to-text
│       ├── Results_screen.dart   # Summary / Flashcards (login-gated) / Quiz (login-gated) / Rate
│       ├── metrics_screen.dart   # NLP metric bars
│       ├── Compare_screen.dart   # Multi-model comparison + Output full-screen page
│       ├── chat_screen.dart      # Single-model multi-turn chat
│       ├── Login_screen.dart     # Login + Register tabs
│       └── Subscription_Screen.dart  # Free vs Pro upgrade
│
├── study_companion.db            # SQLite database (auto-created on first run)
├── requirements.txt              # Python dependencies
└── .env                          # API keys (not committed to git)
```

---

## Setup Instructions

### Prerequisites
- Python 3.10+
- Flutter 3.x SDK
- [Ollama](https://ollama.ai) installed and running locally (for local models)

---

### 1. Clone and configure environment

```bash
# In the project root, create a .env file:
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIza...
SECRET_KEY=any-random-string-for-jwt
EMAIL_ADDRESS=your-gmail@gmail.com
EMAIL_PASSWORD=your-gmail-app-password
```

---

### 2. Install Python dependencies

```bash
pip install -r requirements.txt
```

---

### 3. Pull local AI models (optional — needed for free tier)

```bash
ollama pull llama3
ollama pull mistral
ollama pull phi3
ollama pull gemma
```

---

### 4. Start the backend

```bash
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The backend will auto-create `study_companion.db` on first run.  
Visit `http://localhost:8000/docs` for the interactive Swagger UI.

---

### 5. Install Flutter dependencies

```bash
cd study_companion
flutter pub get
```

---

### 6. Configure the backend URL

In `study_companion/lib/theme.dart`, set `kBaseUrl` to match your setup:

```dart
// Android emulator
const kBaseUrl = 'http://10.0.2.2:8000';

// Physical Android/iOS device (use your machine's local IP)
const kBaseUrl = 'http://192.168.1.X:8000';

// iOS simulator
const kBaseUrl = 'http://localhost:8000';
```

---

### 7. Add platform permissions

**Android** — add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**iOS** — add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan lecture notes and textbooks</string>
<key>NSMicrophoneUsageDescription</key>
<string>Used to accept voice questions for the AI</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to convert your speech to text</string>
```

---

### 8. Run the app

```bash
flutter run
```

---

## Key Flutter Dependencies

| Package | Purpose |
|---------|---------|
| `camera` | Live camera viewfinder |
| `google_mlkit_text_recognition` | OCR — extract text from photos |
| `speech_to_text` | Microphone → real-time transcription |
| `flutter_tts` | Read AI answers aloud (text-to-speech) |
| `file_picker` | Pick PDF / DOCX / TXT from device storage |
| `http` | HTTP requests to the FastAPI backend |
| `shared_preferences` | Persist JWT token, sessions, quiz results locally |
| `percent_indicator` | Progress bars for NLP metric visualisation |

## Key Python Dependencies

| Package | Purpose |
|---------|---------|
| `fastapi` + `uvicorn` | Web framework and ASGI server |
| `sqlalchemy` | ORM for SQLite user database |
| `bcrypt` + `pyjwt` | Password hashing and JWT authentication |
| `openai` | GPT-4o-mini API |
| `anthropic` | Claude 3 Haiku API |
| `google-genai` | Gemini 2.0 Flash API |
| `requests` | HTTP calls to local Ollama server |
| `pypdf` + `python-docx` | Extract text from PDF and Word documents |
| `textstat` | Flesch reading ease and other readability scores |
| `nltk` | Sentence and word tokenisation |
| `rouge_score` | ROUGE-1, ROUGE-2, ROUGE-L content preservation metrics |
| `scikit-learn` | TF-IDF cosine similarity between model outputs |
| `keybert` | Keyword extraction for coverage analysis |
