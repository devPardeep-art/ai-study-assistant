from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
import requests as _requests

load_dotenv()

from app.database import engine, Base
from app.auth.router import router as auth_router
from app.models.openai_model import OpenAIModel
from app.models.claude_model import ClaudeModel
from app.models.gemini_model import GeminiModel
from app.models.local_model import LocalModel
from app.utils.nlp_metrics import analyse, get_cosine_similarity
from app.utils.file_handler import extract_text, is_allowed_file

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Study Companion API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)

_LOCAL_MODEL_NAMES = {"llama3", "mistral", "phi3", "gemma"}


def _run_model(model_name: str, text: str, local_model_name: str = "llama3"):
    """Run text through a model. Accepts cloud names, 'local', or direct local model names."""
    if model_name == "openai":
        return OpenAIModel().process_all(text)
    elif model_name == "claude":
        return ClaudeModel().process_all(text)
    elif model_name == "gemini":
        return GeminiModel().process_all(text)
    elif model_name == "local":
        return LocalModel(model=local_model_name).process_all(text)
    elif model_name in _LOCAL_MODEL_NAMES:
        return LocalModel(model=model_name).process_all(text)
    raise ValueError(f"Unknown model '{model_name}'")


@app.get("/debug")
def debug():
    """
    Returns the availability status of configured API keys without exposing their values.
    """
    return {
        "openai": "set" if os.getenv("OPENAI_API_KEY") else "missing",
        "anthropic": "set" if os.getenv("ANTHROPIC_API_KEY") else "missing",
        "google": "set" if os.getenv("GEMINI_API_KEY") else "missing",
    }


class TextInput(BaseModel):
    text: str
    model: str
    local_model_name: str = "llama3"


class CompareInput(BaseModel):
    text: str
    models: list = ["local"]
    local_model_name: str = "llama3"


@app.get("/")
def home():
    """
    Health check endpoint confirming the backend is operational.
    """
    return {"message": "Backend is running!"}


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """
    Accepts a file upload and extracts its plain text content.

    Args:
        file (UploadFile): The uploaded file. Supported formats: PDF, DOCX, TXT.

    Returns:
        dict: Filename, file size, character count, word count, and extracted text.

    Raises:
        HTTPException 400: If the file type is unsupported, exceeds 10MB, or text extraction fails.
    """
    if not is_allowed_file(file.filename):
        raise HTTPException(status_code=400, detail="File type not supported. Upload PDF, DOCX, or TXT.")

    file_bytes = await file.read()
    file_size_mb = len(file_bytes) / (1024 * 1024)

    if file_size_mb > 10:
        raise HTTPException(status_code=400, detail=f"File too large ({file_size_mb:.1f}MB). Max is 10MB.")

    try:
        extracted_text = extract_text(file.filename, file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not extracted_text or len(extracted_text.strip()) < 20:
        raise HTTPException(status_code=400, detail="Could not extract enough text from the file.")

    return {
        "filename": file.filename,
        "file_size_mb": round(file_size_mb, 2),
        "character_count": len(extracted_text),
        "word_count": len(extracted_text.split()),
        "extracted_text": extracted_text,
        "message": "File uploaded. Use /upload-and-process or /process with this text."
    }


@app.post("/upload-and-process")
async def upload_and_process(
    file: UploadFile = File(...),
    model: str = Form(default="local"),
    local_model_name: str = Form(default="llama3")
):
    """
    Accepts a file upload, extracts its text, and processes it through the specified model.

    Args:
        file (UploadFile): The uploaded file. Supported formats: PDF, DOCX, TXT.
        model (str): The model to use for processing. Options: local, openai, claude, gemini.
        local_model_name (str): The local Ollama model name. Used only when model is 'local'.

    Returns:
        dict: Model output, NLP metrics, and file metadata.

    Raises:
        HTTPException 400: If the file type is unsupported, exceeds 10MB, or an unknown model is specified.
    """
    if not is_allowed_file(file.filename):
        raise HTTPException(status_code=400, detail="File type not supported. Upload PDF, DOCX, or TXT.")

    file_bytes = await file.read()
    file_size_mb = len(file_bytes) / (1024 * 1024)

    if file_size_mb > 10:
        raise HTTPException(status_code=400, detail="File too large. Max is 10MB.")

    try:
        extracted_text = extract_text(file.filename, file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if not extracted_text or len(extracted_text.strip()) < 20:
        raise HTTPException(status_code=400, detail="Could not extract enough text.")

    model_name = model.lower()

    try:
        result = _run_model(model_name, extracted_text, local_model_name)

        output_text = result.get("output", "")
        if output_text:
            result["metrics"] = analyse(original_text=extracted_text, model_output=output_text)

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
        error_msg = str(e)
        if model_name not in _LOCAL_MODEL_NAMES and model_name != "local":
            try:
                fallback = LocalModel().summarise(extracted_text)
                return {
                    "message": f"'{model_name}' failed — falling back to local LLaMA3.",
                    "fallback_output": fallback,
                    "error": error_msg,
                }
            except Exception:
                pass
        return {"error": error_msg}


@app.post("/process")
def process_text(data: TextInput):
    """
    Processes plain text input through the specified model.

    Args:
        data (TextInput): Contains 'text', 'model', and optional 'local_model_name'.

    Returns:
        dict: Model output and NLP metrics. Falls back to local LLaMA3 on failure.
    """
    model_name = data.model.lower()

    try:
        result = _run_model(model_name, data.text, data.local_model_name)
        output_text = result.get("output", "")
        if output_text:
            result["metrics"] = analyse(original_text=data.text, model_output=output_text)
        return result

    except Exception as e:
        error_msg = str(e)
        if model_name not in _LOCAL_MODEL_NAMES and model_name != "local":
            try:
                fallback = LocalModel().summarise(data.text)
                return {
                    "message": f"'{model_name}' failed — falling back to local LLaMA3.",
                    "fallback_output": fallback,
                    "error": error_msg,
                }
            except Exception:
                pass
        return {"error": error_msg}


@app.post("/compare")
def compare_models(data: CompareInput):
    """
    Sends the same text to multiple models simultaneously and compares their outputs.

    Args:
        data (CompareInput): Contains 'text', 'models' list, and optional 'local_model_name'.

    Returns:
        dict: Each model's output with NLP metrics, and an automatic comparison summary.

    Raises:
        HTTPException 400: If text is empty or no models are specified.
    """
    if not data.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty.")

    if not data.models:
        raise HTTPException(status_code=400, detail="Please specify at least one model.")

    def _run_one(model_name: str):
        name = model_name.lower()
        try:
            result = _run_model(name, data.text, data.local_model_name)
            output_text = result.get("output", "")
            if output_text:
                result["metrics"] = analyse(original_text=data.text, model_output=output_text)
            return name, result
        except ValueError as e:
            return name, {"error": str(e)}
        except Exception as e:
            return name, {"error": str(e)}

    results = {}
    # Cap at 2 concurrent workers — Ollama queues requests anyway, and running
    # more than 2 LLMs simultaneously starves CPU/RAM making all of them slower.
    with ThreadPoolExecutor(max_workers=min(len(data.models), 2)) as pool:
        futures = {pool.submit(_run_one, m): m for m in data.models}
        for future in as_completed(futures):
            name, result = future.result()
            results[name] = result

    comparison = _generate_comparison(results)

    return {
        "results": results,
        "comparison": comparison
    }


def _generate_comparison(results: dict) -> dict:
    """
    Evaluates all model results and identifies the best performer across key metrics.

    Args:
        results (dict): Dictionary of model names mapped to their output and metrics.

    Returns:
        dict: Fastest model, most readable model, best keyword coverage, best ROUGE score,
              cosine similarity between model pairs, and a recommendation summary string.
    """
    valid_results = {k: v for k, v in results.items() if "error" not in v}

    if not valid_results:
        return {"error": "All models failed"}

    if len(valid_results) == 1:
        model = list(valid_results.keys())[0]
        return {"note": f"Only one model ran successfully: {model}"}

    fastest = min(valid_results, key=lambda m: valid_results[m].get("response_time", 999))

    most_readable = max(
        valid_results,
        key=lambda m: valid_results[m].get("metrics", {}).get("flesch_reading_ease", 0)
    )

    best_coverage = max(
        valid_results,
        key=lambda m: valid_results[m].get("metrics", {}).get("keyword_coverage_percent", 0)
    )

    best_rouge = max(
        valid_results,
        key=lambda m: valid_results[m].get("metrics", {}).get("rouge_1", 0)
    )

    similarity_scores = {}
    model_names = list(valid_results.keys())
    for i in range(len(model_names)):
        for j in range(i + 1, len(model_names)):
            m1, m2 = model_names[i], model_names[j]
            text1 = valid_results[m1].get("output", "")
            text2 = valid_results[m2].get("output", "")
            if text1 and text2:
                similarity_scores[f"{m1}_vs_{m2}"] = get_cosine_similarity(text1, text2)

    recommendation = (
        f"{fastest.upper()} was the fastest model. "
        f"{most_readable.upper()} produced the most readable output. "
        f"{best_coverage.upper()} had the best keyword coverage. "
        f"{best_rouge.upper()} preserved the most content from the original text."
    )

    return {
        "fastest_model": fastest,
        "most_readable_model": most_readable,
        "best_keyword_coverage_model": best_coverage,
        "best_rouge_score_model": best_rouge,
        "similarity_between_models": similarity_scores,
        "recommendation": recommendation
    }


class ChatInput(BaseModel):
    messages: list
    model: str
    local_model_name: str = "llama3"


@app.post("/chat")
def chat(data: ChatInput):
    """
    Multi-turn chat endpoint. Accepts a conversation history and returns the next assistant reply.

    Args:
        data (ChatInput): Contains 'messages' (list of role/content dicts), 'model', and optional 'local_model_name'.

    Returns:
        dict: Contains 'response' (the assistant reply) and 'model'.
    """
    model_name = data.model.lower()
    messages = data.messages  # list of {"role": "user"/"assistant", "content": "..."}

    try:
        if model_name == "openai":
            from openai import OpenAI
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            formatted = [{"role": "system", "content": "You are a helpful AI study assistant."}]
            formatted += [{"role": m["role"], "content": m["content"]} for m in messages]
            resp = client.chat.completions.create(model="gpt-4o-mini", messages=formatted)
            return {"response": resp.choices[0].message.content, "model": "openai"}

        elif model_name == "claude":
            from anthropic import Anthropic
            client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
            formatted = [{"role": m["role"], "content": m["content"]} for m in messages]
            resp = client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=1024,
                system="You are a helpful AI study assistant.",
                messages=formatted,
            )
            return {"response": resp.content[0].text, "model": "claude"}

        elif model_name == "gemini":
            from google import genai
            client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
            conversation = "\n".join(
                [f"{m['role'].capitalize()}: {m['content']}" for m in messages]
            )
            resp = client.models.generate_content(model="gemini-2.0-flash", contents=conversation)
            return {"response": resp.text, "model": "gemini"}

        elif model_name in _LOCAL_MODEL_NAMES or model_name == "local":
            local_model = model_name if model_name in _LOCAL_MODEL_NAMES else data.local_model_name
            prompt = "\n".join(
                f"{m['role'].capitalize()}: {m['content']}" for m in messages
            ) + "\nAssistant:"
            try:
                resp = _requests.post(
                    "http://localhost:11434/api/generate",
                    json={"model": local_model, "prompt": prompt, "stream": False},
                    timeout=300,
                )
            except _requests.exceptions.ConnectionError:
                return {"error": "Cannot connect to Ollama. Make sure it is running: ollama serve"}
            if resp.status_code == 404:
                return {"error": f"Model '{local_model}' not found. Run: ollama pull {local_model}"}
            resp.raise_for_status()
            return {"response": resp.json()["response"].strip(), "model": local_model}

        else:
            raise HTTPException(status_code=400, detail=f"Unknown model '{model_name}'")

    except HTTPException:
        raise
    except Exception as e:
        return {"error": str(e)}


class Evaluation(BaseModel):
    model: str
    clarity: int
    accuracy: int
    usefulness: int
    comments: str | None = None


@app.post("/evaluate")
def evaluate_model(data: Evaluation):
    """
    Receives and acknowledges a user evaluation submission for a model response.

    Args:
        data (Evaluation): Contains 'model', 'clarity', 'accuracy', 'usefulness', and optional 'comments'.

    Returns:
        dict: Confirmation message and submitted evaluation data.
    """
    return {
        "message": "Evaluation received",
        "data": data
    }