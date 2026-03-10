from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from pydantic import BaseModel
from dotenv import load_dotenv
import os

load_dotenv()

from app.models.openai_model import OpenAIModel
from app.models.claude_model import ClaudeModel
from app.models.gemini_model import GeminiModel
from app.models.local_model import LocalModel
from app.utils.nlp_metrics import analyse
from app.utils.file_handler import extract_text, is_allowed_file

app = FastAPI()


@app.get("/debug")
def debug():
    return {
        "openai": os.getenv("OPENAI_API_KEY"),
        "anthropic": os.getenv("ANTHROPIC_API_KEY"),
        "google": os.getenv("GEMINI_API_KEY")
    }


class TextInput(BaseModel):
    text: str
    model: str
    local_model_name: str = "llama3"  # Options: llama3, mistral, phi3, gemma


@app.get("/")
def home():
    return {"message": "Backend is running!"}


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """
    Step 1: Upload a PDF, DOCX, or TXT file and extract its text.
    Use /upload-and-process to do everything in one call.
    """
    if not is_allowed_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail="File type not supported. Please upload a PDF, DOCX, or TXT file."
        )

    file_bytes = await file.read()
    file_size_mb = len(file_bytes) / (1024 * 1024)

    if file_size_mb > 10:
        raise HTTPException(
            status_code=400,
            detail=f"File too large ({file_size_mb:.1f}MB). Maximum size is 10MB."
        )

    try:
        extracted_text = extract_text(file.filename, file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not extracted_text or len(extracted_text.strip()) < 20:
        raise HTTPException(
            status_code=400,
            detail="Could not extract enough text from the file."
        )

    return {
        "filename": file.filename,
        "file_size_mb": round(file_size_mb, 2),
        "character_count": len(extracted_text),
        "word_count": len(extracted_text.split()),
        "extracted_text": extracted_text,
        "message": "File uploaded successfully. Use /upload-and-process to get AI results directly."
    }


@app.post("/upload-and-process")
async def upload_and_process(
    file: UploadFile = File(...),
    model: str = Form(default="local"),
    local_model_name: str = Form(default="llama3")
):
    """
    ONE ENDPOINT DOES EVERYTHING:
    1. Upload your PDF, DOCX, or TXT file
    2. Extracts the text automatically
    3. Sends it to your chosen AI model
    4. Returns summary + flashcards + quiz + NLP metrics

    How to use in /docs:
    - Pick your file
    - Set model: openai / claude / gemini / local
    - Set local_model_name: llama3 / mistral / phi3 (only if model=local)
    - Hit Execute!
    """

    # --- Step 1: Validate and read file ---
    if not is_allowed_file(file.filename):
        raise HTTPException(
            status_code=400,
            detail="File type not supported. Please upload PDF, DOCX, or TXT."
        )

    file_bytes = await file.read()
    file_size_mb = len(file_bytes) / (1024 * 1024)

    if file_size_mb > 10:
        raise HTTPException(
            status_code=400,
            detail=f"File too large ({file_size_mb:.1f}MB). Max is 10MB."
        )

    # --- Step 2: Extract text ---
    try:
        extracted_text = extract_text(file.filename, file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not extracted_text or len(extracted_text.strip()) < 20:
        raise HTTPException(
            status_code=400,
            detail="Could not extract enough text from the file."
        )

    # --- Step 3: Send to AI model ---
    model_name = model.lower()

    try:
        if model_name == "openai":
            result = OpenAIModel().process_all(extracted_text)
        elif model_name == "claude":
            result = ClaudeModel().process_all(extracted_text)
        elif model_name == "gemini":
            result = GeminiModel().process_all(extracted_text)
        elif model_name == "local":
            result = LocalModel(model=local_model_name).process_all(extracted_text)
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown model '{model_name}'. Options: openai, claude, gemini, local"
            )

        # --- Step 4: Add NLP metrics ---
        output_text = result.get("output", "")
        if output_text:
            result["metrics"] = analyse(
                original_text=extracted_text,
                model_output=output_text
            )

        # Add file info to response
        result["file_info"] = {
            "filename": file.filename,
            "file_size_mb": round(file_size_mb, 2),
            "word_count": len(extracted_text.split()),
            "character_count": len(extracted_text)
        }

        return result

    except HTTPException:
        raise
    except Exception as e:
        # Fallback to local if cloud fails
        local = LocalModel()
        fallback = local.summarise(extracted_text)
        return {
            "message": f"'{model_name}' failed. Falling back to local LLaMA3.",
            "fallback_output": fallback,
            "error": str(e),
            "file_info": {
                "filename": file.filename,
                "word_count": len(extracted_text.split())
            }
        }


@app.post("/process")
def process_text(data: TextInput):
    """Process raw text directly without file upload."""
    model_name = data.model.lower()

    try:
        if model_name == "openai":
            result = OpenAIModel().process_all(data.text)
        elif model_name == "claude":
            result = ClaudeModel().process_all(data.text)
        elif model_name == "gemini":
            result = GeminiModel().process_all(data.text)
        elif model_name == "local":
            result = LocalModel(model=data.local_model_name).process_all(data.text)
        else:
            return {"error": f"Unknown model '{model_name}'. Options: openai, claude, gemini, local"}

        output_text = result.get("output", "")
        if output_text:
            result["metrics"] = analyse(
                original_text=data.text,
                model_output=output_text
            )

        return result

    except Exception as e:
        local = LocalModel()
        fallback = local.summarise(data.text)
        return {
            "message": f"'{model_name}' failed. Falling back to local LLaMA3.",
            "fallback_output": fallback,
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