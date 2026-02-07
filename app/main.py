from fastapi import FastAPI
from pydantic import BaseModel
from app.models.openai_model import OpenAIModel


app = FastAPI()

class TextInput(BaseModel):
    text: str

@app.get("/")
def home():
    return {"message": "Backend is running!"}

@app.post("/upload")
def upload_file():
    return {"message": "Upload endpoint placeholder"}

@app.post("/process")
def process_text(input: TextInput):
    model = OpenAIModel()

    summary = model.summarise(input.text)
    flashcards = model.generate_flashcards(input.text)
    quiz = model.generate_quiz(input.text)

    return {
        "status": "success",
        "gpt4": {
            "summary": summary,
            "flashcards": flashcards,
            "quiz": quiz
        }
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
