 **AI Study Assistant – Multi-Model Learning Companion**

This project is a full-stack AI Study Assistant designed to help students learn smarter and faster.
It processes any block of text and generates:

*  **Simplified summaries**
*  **Flashcards (Q → A format)**
*  **Multiple-choice quizzes**
*  **Model comparison across OpenAI, Claude, Gemini, and Ollama**

It supports BOTH cloud-based LLMs and offline local models.



# **Tech Stack**

### **Backend (FastAPI)**

* FastAPI
* Python
* OpenAI SDK (GPT-4o / GPT-4o-mini)
* Anthropic SDK (Claude 3)
* Google Gemini SDK
* Ollama local inference engine
* Pydantic models
* Uvicorn server

### **Frontend (Flutter)**

* Flutter UI
* REST API integration
* JSON response parsing
* Modern and minimal design

---

# **Key Features**

###  **1. Multi-Model AI Processing**

Supports 4 different AI sources:

| Model               | Source    | Cost      | Online/Offline |
| ------------------- | --------- | --------- | -------------- |
| GPT-4o              | OpenAI    | Paid      | Online         |
| Claude 3            | Anthropic | Paid      | Online         |
| Gemini              | Google    | Free/Paid | Online         |
| LLaMA/Mistral/Gemma | Ollama    | Free      | Offline        |

Switching between models only takes a single JSON parameter.

---

 **2. Unified /process API Endpoint**

The backend exposes a POST endpoint:

```
/process
```

Which returns:

* summary
* flashcards
* quiz
* response time
* token usage
* model name

Everything is structured in clean JSON.

---

###  **3. Local AI with Ollama**

Run AI models fully offline using:

* LLaMA 3
* Mistral
* Phi-3
* Gemma

Perfect for privacy-first applications.

---
 **4. Structured Architecture**

```
app/
    main.py
    models/
        openai_model.py
        claude_model.py
        gemini_model.py
        ollama_model.py
    utils/
    __init__.py
```

Easy to extend for future models.

---

# **Project Goals**

* Build a multi-agent AI backend for learning enhancement
* Compare AI models based on output quality & speed
* Provide a clean Flutter interface for end-users
* Allow offline AI usage via Ollama
* Learn full-stack architecture from scratch

---

#  **How to Run Backend**

```sh
.\venv\Scripts\activate
python -m uvicorn app.main:app --reload
```

Open API Docs:

 [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

---

*How to Run Flutter App**

(To be added once UI is completed)

---

**Ideal For**

* University students
* Learning reinforcement
* AI architecture research
* Multi-model comparison
* Offline AI usage

---

**Future Improvements**

* Export results as PDF
* User authentication
* Real-time study dashboard
* Notes storage & database integration
* Model ranking system
