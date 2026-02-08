import os
import time
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

class ClaudeModel:
    def __init__(self):
        self.client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

    def summarise(self, text: str):
        start = time.time()

        response = self.client.messages.create(
            model="claude-3-haiku-20240307",
            max_tokens=300,
            messages=[
                {"role": "user", "content": f"Summarise this clearly:\n{text}"}
            ]
        )

        summary = response.content[0].text
        end = time.time()

        return {
            "model": "claude-3-haiku",
            "summary": summary,
            "response_time": round(end - start, 3),
        }
