import time
import requests

# Supported local models available for selection via Ollama runtime.
AVAILABLE_MODELS = ["llama3", "mistral", "phi3", "gemma"]

# Ollama REST API endpoint for text generation.
OLLAMA_URL = "http://localhost:11434/api/generate"


class LocalModel:

    def __init__(self, model: str = "llama3"):
        """
        Initialises the LocalModel with the specified Ollama model.

        Args:
            model (str): Name of the model to use. Defaults to 'llama3'.
                         Falls back to 'llama3' if the requested model is not supported.
        """
        if model in AVAILABLE_MODELS:
            self.model = model
        else:
            self.model = "llama3"
            print(f"[Warning] Model '{model}' not in list. Defaulting to llama3.")

    def _run_ollama(self, prompt: str) -> dict:
        """
        Sends a prompt to the Ollama REST API and returns the generated response.

        Args:
            prompt (str): The input prompt to be processed by the model.

        Returns:
            dict: Contains 'model' name, 'output' text, and 'response_time' in seconds.
        """
        start = time.time()
        try:
            response = requests.post(OLLAMA_URL, json={
                "model": self.model,
                "prompt": prompt,
                "stream": False
            }, timeout=300)
        except requests.exceptions.ConnectionError:
            raise RuntimeError(
                "Cannot connect to Ollama. Make sure it is running: ollama serve"
            )
        except requests.exceptions.Timeout:
            raise RuntimeError("Ollama timed out. The model may be too large for your machine.")

        if response.status_code == 404:
            raise RuntimeError(
                f"Model '{self.model}' not found in Ollama. Pull it first: ollama pull {self.model}"
            )
        response.raise_for_status()

        end = time.time()
        return {
            "model": self.model,
            "output": response.json()["response"].strip(),
            "response_time": round(end - start, 3),
        }

    def summarise(self, text: str) -> dict:
        """
        Generates a concise summary of the provided text.

        Args:
            text (str): The input text to summarise.

        Returns:
            dict: Model response containing the generated summary.
        """
        prompt = f"Summarise this text clearly in 3-5 sentences:\n\n{text}"
        return self._run_ollama(prompt)

    def flashcards(self, text: str) -> dict:
        """
        Generates study flashcards in Q/A format from the provided text.

        Args:
            text (str): The input text to generate flashcards from.

        Returns:
            dict: Model response containing the generated flashcards.
        """
        prompt = f"Create 5 flashcards in Q: A: format from this text:\n\n{text}"
        return self._run_ollama(prompt)

    def quiz(self, text: str) -> dict:
        """
        Generates multiple choice quiz questions from the provided text.

        Args:
            text (str): The input text to generate quiz questions from.

        Returns:
            dict: Model response containing the generated quiz questions.
        """
        prompt = f"Create 5 multiple choice questions (with 4 options and the correct answer) from this text:\n\n{text}"
        return self._run_ollama(prompt)

    def process_all(self, text: str) -> dict:
        """
        Executes all generation tasks — summary, flashcards, and quiz — in a single API call.

        Args:
            text (str): The input text to process.

        Returns:
            dict: Model response containing summary, flashcards, and quiz output.
        """
        prompt = f"""
You are an AI study assistant. A student has given you the following text.

Your job is to produce THREE things:

1. SUMMARY: A clear 3-5 sentence summary
2. FLASHCARDS: 3 flashcards in Q: / A: format
3. QUIZ: 5 multiple choice questions with 4 options each and the correct answer marked

Text:
{text}
"""
        return self._run_ollama(prompt)