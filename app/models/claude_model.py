import os
import time
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()


class ClaudeModel:

    def __init__(self):
        """
        Initialises the ClaudeModel with an Anthropic client and the designated model version.
        """
        self.client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
        self.model_name = "claude-3-haiku-20240307"

    def _generate(self, prompt: str, max_tokens: int = 1024) -> dict:
        """
        Sends a prompt to the Claude API and returns the generated response.

        Args:
            prompt (str): The input prompt to send to the model.
            max_tokens (int): Maximum number of tokens in the response. Defaults to 1024.

        Returns:
            dict: Contains 'success' flag, 'text', 'input_tokens', 'output_tokens',
                  and 'response_time'. On failure, contains 'success', 'error', and 'response_time'.
        """
        start = time.time()
        try:
            response = self.client.messages.create(
                model=self.model_name,
                max_tokens=max_tokens,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            end = time.time()
            return {
                "success": True,
                "text": response.content[0].text,
                "input_tokens": response.usage.input_tokens,
                "output_tokens": response.usage.output_tokens,
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
            dict: Contains 'model', 'summary', 'response_time', and 'token_usage'.
                  Returns an error dict if the API call fails.
        """
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
        """
        Generates study flashcards in Q/A format from the provided text.

        Args:
            text (str): The input text to generate flashcards from.

        Returns:
            dict: Contains 'model', 'flashcards', 'response_time', and 'token_usage'.
                  Returns an error dict if the API call fails.
        """
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
        """
        Generates multiple choice quiz questions from the provided text.

        Args:
            text (str): The input text to generate quiz questions from.

        Returns:
            dict: Contains 'model', 'quiz', 'response_time', and 'token_usage'.
                  Returns an error dict if the API call fails.
        """
        result = self._generate(f"Create 5 multiple choice questions with 4 options and correct answer from:\n\n{text}")
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
        Executes summary, flashcard, and quiz generation in a single API call.

        Args:
            text (str): The input text to process.

        Returns:
            dict: Contains 'model', 'output', 'response_time', and 'token_usage'.
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
            "response_time": result["response_time"],
            "token_usage": {
                "input": result["input_tokens"],
                "output": result["output_tokens"]
            }
        }