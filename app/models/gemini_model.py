from google import genai
from dotenv import load_dotenv
import os
import time

load_dotenv()


class GeminiModel:

    def __init__(self):
        """
        Initialises the GeminiModel with a Gemini client and the designated model version.
        """
        api_key = os.getenv("GEMINI_API_KEY")
        self.client = genai.Client(api_key=api_key)
        self.model_name = "gemini-2.0-flash"

    def _generate(self, prompt: str) -> dict:
        """
        Sends a prompt to the Gemini API and returns the generated response.

        Args:
            prompt (str): The input prompt to send to the model.

        Returns:
            dict: Contains 'success' flag, 'text', and 'response_time'.
                  On failure, contains 'success', 'error', and 'response_time'.
        """
        start = time.time()
        try:
            response = self.client.models.generate_content(
                model=self.model_name,
                contents=prompt
            )
            end = time.time()
            return {
                "success": True,
                "text": response.text,
                "response_time": round(end - start, 3)
            }
        except Exception as e:
            return {"success": False, "error": str(e), "response_time": 0}

    def summarise(self, text: str) -> dict:
        """
        Generates a concise summary of the provided text.

        Args:
            text (str): The input text to summarise.

        Returns:
            dict: Contains 'model', 'summary', and 'response_time'.
                  Returns an error dict if the API call fails.
        """
        result = self._generate(f"Summarise this clearly in 3-5 sentences:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "summary": result["text"],
            "response_time": result["response_time"]
        }

    def flashcards(self, text: str) -> dict:
        """
        Generates study flashcards in Q/A format from the provided text.

        Args:
            text (str): The input text to generate flashcards from.

        Returns:
            dict: Contains 'model', 'flashcards', and 'response_time'.
                  Returns an error dict if the API call fails.
        """
        result = self._generate(f"Create 5 flashcards in Q: A: format from this text:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "flashcards": result["text"],
            "response_time": result["response_time"]
        }

    def quiz(self, text: str) -> dict:
        """
        Generates multiple choice quiz questions from the provided text.

        Args:
            text (str): The input text to generate quiz questions from.

        Returns:
            dict: Contains 'model', 'quiz', and 'response_time'.
                  Returns an error dict if the API call fails.
        """
        result = self._generate(f"Create 5 multiple choice questions with 4 options and correct answer from:\n\n{text}")
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "quiz": result["text"],
            "response_time": result["response_time"]
        }

    def process_all(self, text: str) -> dict:
        """
        Executes summary, flashcard, and quiz generation in a single API call.

        Args:
            text (str): The input text to process.

        Returns:
            dict: Contains 'model', 'output', and 'response_time'.
                  Returns an error dict if the API call fails.
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
        result = self._generate(prompt)
        if not result["success"]:
            return {"error": result["error"]}
        return {
            "model": self.model_name,
            "output": result["text"],
            "response_time": result["response_time"]
        }