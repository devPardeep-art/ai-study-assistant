from fastapi import FastAPI
from pydantic import BaseModel
from dotenv import load_dotenv
import os

# Load environment variables (.env)
load_dotenv()

# Import model handlers
from app.models.openai_model import OpenAIModel
from app.models.claude_model import ClaudeModel
from app.models.gemini_model import GeminiModel
from app.models.local_model import LocalModel


app = FastAPI()

@app.get("/debug")
def debug():
    return {
        "openai": os.getenv("OPENAI_API_KEY"),
        "anthropic": os.getenv("ANTHROPIC_API_KEY"),
        "google": os.getenv("GOOGLE_API_KEY")
    }



class TextInput(BaseModel):
    text: str
    model: str


@app.get("/")
def home():
    return {"message": "Backend is running!"}



@app.post("/upload")
def upload_file():
    return {"message": "Upload endpoint placeholder"}



@app.post("/process")
def process_text(data: TextInput):
    model_name = data.model.lower()

    try:
        # ---- OpenAI ---- #
        if model_name == "openai":
            return OpenAIModel().summarise(data.text)

        # ---- Anthropic Claude ---- #
        elif model_name == "claude":
            return ClaudeModel().summarise(data.text)

        # ---- Google Gemini ---- #
        elif model_name == "gemini":
            return GeminiModel().summarise(data.text)

        # ---- Local Model (Ollama) ---- #
        elif model_name == "local":
            return LocalModel().summarise(data.text)

        else:
            return {"error": f"Unknown model selected: {model_name}"}

    except Exception as e:
        # If API fails → fallback to offline LLaMA automatically
        local = LocalModel()
        return {
            "message": f"API model '{model_name}' failed. Using local fallback.",
            "fallback_output": local.summarise(data.text),
            "error": str(e)
        }



class Evaluation(BaseModel):
    model: str
    clarity: int
    accuracy: int
    usefulness: int
    comments: str | None = None


@app.post("/evaluate")
def evaluate_model(data: Evaluation):
    return {
        "message": "Evaluation received",
        "data": data
    }
