import time
import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class OpenAIModel:

    def summarise(self, text: str):
        return self._generate(text, task="summary")

    def generate_flashcards(self, text: str):
        return self._generate(text, task="flashcards")

    def generate_quiz(self, text: str):
        return self._generate(text, task="quiz")

    def _generate(self, text: str, task: str):
        start = time.time()

        # TASK-BASED PROMPTS
        if task == "summary":
            prompt = f"Summarize this text in simple, clear language:\n\n{text}"

        elif task == "flashcards":
            prompt = f"Create 5 flashcards in 'Q: ... A: ...' format based on this text:\n\n{text}"

        elif task == "quiz":
            prompt = f"Create 5 multiple-choice quiz questions (A, B, C, D) with correct answers:\n\n{text}"

        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": "You are an AI study assistant."},
                    {"role": "user", "content": prompt}
                ]
            )

            content = response.choices[0].message.content
            end = time.time()

            return {
                "task": task,
                "model": "GPT-4o-mini",
                "output": content,
                "response_time": round(end - start, 3),
                "token_usage": response.usage.total_tokens if hasattr(response, "usage") else None,
            }

        except Exception as e:
            return {
                "task": task,
                "model": "GPT-4o-mini",
                "error": str(e)
            }
