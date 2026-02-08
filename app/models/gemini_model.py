import google.generativeai as genai
from dotenv import load_dotenv
import os
import time

load_dotenv()

class GeminiModel:

    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        genai.configure(api_key=api_key)

        self.model = genai.GenerativeModel("gemini-1.5-flash")

    def summarise(self, text: str):
        start = time.time()
        try:
            response = self.model.generate_content(f"Summarise this:\n{text}")
            end = time.time()

            return {
                "model": "gemini-1.5-flash",
                "summary": response.text,
                "response_time": round(end - start, 3)
            }
        except Exception as e:
            return {"error": str(e)}
