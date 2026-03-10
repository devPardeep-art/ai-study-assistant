import time
import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

class OpenAIModel:

    def __init__(self):
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.model_name = "gpt-4o-mini"

    def _generate(self, prompt: str) -> dict:
        start = time.time()
        try:
            response = self.client.chat.completions.create(
                model=self.model_name,
                messages=[
                    {"role": "system", "content": "You are an AI study assistant."},
                    {"role": "user", "content": prompt}
                ]
            )
            end = time.time()
            return {
                "success": True,
                "text": response.choices[0].message.content,
                "input_tokens": response.usage.prompt_tokens,
                "output_tokens": response.usage.completion_tokens,
                "response_time": round(end - start, 3)
            }
        except Exception as e:
            return {"success": False, "error": str(e), "response_time": 0}

    def summarise(self, text: str) -> dict:
        result = self._generate(f"Summarise this clearly in 3-5 sentences:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "summary": result["text"],
            "response_time": result["response_time"],
            "token_usage": {
                "input": result["input_tokens"],
                "output": result["output_tokens"]
            }
        }

    def flashcards(self, text: str) -> dict:
        result = self._generate(f"Create 5 flashcards in Q: A: format from this text:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "flashcards": result["text"],
            "response_time": result["response_time"],
            "token_usage": {
                "input": result["input_tokens"],
                "output": result["output_tokens"]
            }
        }

    def quiz(self, text: str) -> dict:
        result = self._generate(f"Create 3 multiple choice questions with 4 options and correct answer from:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "quiz": result["text"],
            "response_time": result["response_time"],
            "token_usage": {
                "input": result["input_tokens"],
                "output": result["output_tokens"]
            }
        }

    def process_all(self, text: str) -> dict:
        """
        Runs summary + flashcards + quiz in one single API call.
        Saves tokens and is faster than 3 separate calls.
        """
        prompt = f"""
You are an AI study assistant. A student has given you the following text.

Your job is to produce THREE things:

1. SUMMARY: A clear 3-5 sentence summary
2. FLASHCARDS: 3 flashcards in Q: / A: format
3. QUIZ: 2 multiple choice questions with 4 options each and the correct answer marked

Text:
{text}
"""
        result = self._generate(prompt)
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "output": result["text"],
            "response_time": result["response_time"],
            "token_usage": {
                "input": result["input_tokens"],
                "output": result["output_tokens"]
            }
        }