import time
import subprocess

# These are the local models you can use
# Make sure you've pulled them first with: ollama pull <model_name>
AVAILABLE_MODELS = ["llama3", "mistral", "phi3", "gemma"]


class LocalModel:

    def __init__(self, model: str = "llama3"):
        """
        You can choose which local model to use when creating this object.
        Example: LocalModel("mistral") or LocalModel("phi3")
        Defaults to llama3 if nothing is specified.
        """
        # If the model requested isn't in our list, fall back to llama3
        if model in AVAILABLE_MODELS:
            self.model = model
        else:
            self.model = "llama3"
            print(f"[Warning] Model '{model}' not in list. Defaulting to llama3.")

    def _run_ollama(self, prompt: str) -> dict:
        """
        Internal method that actually calls Ollama via command line.
        Returns the output text, model name, and how long it took.
        """
        start = time.time()

        cmd = ["ollama", "run", self.model, prompt]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)

        end = time.time()

        return {
            "model": self.model,
            "output": result.stdout.strip(),
            "response_time": round(end - start, 3),
        }

    def summarise(self, text: str) -> dict:
        prompt = f"Summarise this text clearly in 3-5 sentences:\n\n{text}"
        return self._run_ollama(prompt)

    def flashcards(self, text: str) -> dict:
        prompt = f"Create 5 flashcards in Q: A: format from this text:\n\n{text}"
        return self._run_ollama(prompt)

    def quiz(self, text: str) -> dict:
        prompt = f"Create 3 multiple choice questions (with 4 options and the correct answer) from this text:\n\n{text}"
        return self._run_ollama(prompt)

    def process_all(self, text: str) -> dict:
        """
        Runs all three tasks (summary, flashcards, quiz) in one go.
        This is useful for the /process endpoint to return everything at once.
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
        return self._run_ollama(prompt)