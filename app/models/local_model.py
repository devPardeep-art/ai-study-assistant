import time
import subprocess
import json

class LocalModel:
    def _run_ollama(self, model: str, prompt: str):
        start = time.time()

        cmd = ["ollama", "run", model, prompt]

        result = subprocess.run(cmd, capture_output=True, text=True)

        end = time.time()

        return {
            "model": model,
            "output": result.stdout.strip(),
            "response_time": round(end - start, 3),
        }

    def summarise(self, text: str):
        prompt = f"Summarise this clearly:\n{text}"
        return self._run_ollama("llama3", prompt)

    def flashcards(self, text: str):
        prompt = f"Create 5 flashcards (Q: A:) from this text:\n{text}"
        return self._run_ollama("mistral", prompt)

    def quiz(self, text: str):
        prompt = f"Create 5 MCQ questions with answers:\n{text}"
        return self._run_ollama("mistral", prompt)
