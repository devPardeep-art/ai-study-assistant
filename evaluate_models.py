"""
Run this script with the backend running to collect real evaluation metrics.
Usage:
    python evaluate_models.py

Make sure uvicorn is running first:
    uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

# A realistic study document — replace with your own if preferred
TEST_TEXT = """
Machine learning is a subset of artificial intelligence that enables systems to learn
and improve from experience without being explicitly programmed. It focuses on developing
computer programs that can access data and use it to learn for themselves.

The process begins with observations or data, such as examples, direct experience, or
instruction. Machine learning algorithms build a mathematical model based on sample data,
known as training data, in order to make predictions or decisions without being explicitly
programmed to perform the task.

Supervised learning is the most common type, where the algorithm learns from labelled
training data. Unsupervised learning finds hidden patterns in data without labels.
Reinforcement learning trains agents to make decisions by rewarding desired behaviours.

Deep learning, a subtype of machine learning, uses neural networks with many layers to
model complex patterns in data. Convolutional neural networks excel at image recognition,
while recurrent neural networks are suited to sequential data such as language.

Applications of machine learning include image recognition, natural language processing,
recommendation systems, fraud detection, medical diagnosis, and autonomous vehicles.
The field continues to advance rapidly, with new architectures and training techniques
emerging regularly.
"""

MODELS = ["openai", "claude", "gemini", "local"]


def test_model(model_name):
    print(f"\n{'='*50}")
    print(f"Testing: {model_name.upper()}")
    print(f"{'='*50}")

    payload = {
        "text": TEST_TEXT,
        "model": model_name,
        "local_model_name": "llama3"
    }

    start = time.time()
    try:
        response = requests.post(f"{BASE_URL}/process", json=payload, timeout=360)
        elapsed = round(time.time() - start, 2)

        if response.status_code != 200:
            print(f"  ERROR {response.status_code}: {response.text}")
            return None

        data = response.json()

        if "error" in data:
            print(f"  MODEL ERROR: {data['error']}")
            return None

        metrics = data.get("metrics", {})
        result = {
            "model": model_name,
            "response_time_sec": data.get("response_time", elapsed),
            "word_count": metrics.get("word_count", "N/A"),
            "sentence_count": metrics.get("sentence_count", "N/A"),
            "avg_words_per_sentence": metrics.get("avg_words_per_sentence", "N/A"),
            "flesch_reading_ease": metrics.get("flesch_reading_ease", "N/A"),
            "readability_label": metrics.get("readability_label", "N/A"),
            "rouge_1": metrics.get("rouge_1", "N/A"),
            "rouge_2": metrics.get("rouge_2", "N/A"),
            "rouge_L": metrics.get("rouge_L", "N/A"),
            "keyword_coverage_percent": metrics.get("keyword_coverage_percent", "N/A"),
            "keywords_found": metrics.get("keywords_found_in_output", []),
            "output_preview": data.get("output", "")[:200] + "..."
        }

        print(f"  Response Time:       {result['response_time_sec']}s")
        print(f"  Word Count:          {result['word_count']}")
        print(f"  Sentence Count:      {result['sentence_count']}")
        print(f"  Avg Words/Sentence:  {result['avg_words_per_sentence']}")
        print(f"  Flesch Score:        {result['flesch_reading_ease']} ({result['readability_label']})")
        print(f"  ROUGE-1:             {result['rouge_1']}")
        print(f"  ROUGE-2:             {result['rouge_2']}")
        print(f"  ROUGE-L:             {result['rouge_L']}")
        print(f"  Keyword Coverage:    {result['keyword_coverage_percent']}%")
        print(f"  Keywords Found:      {result['keywords_found']}")
        print(f"  Output Preview:      {result['output_preview']}")

        return result

    except requests.exceptions.ConnectionError:
        print("  FAILED: Cannot connect to server. Is uvicorn running?")
        return None
    except Exception as e:
        print(f"  FAILED: {e}")
        return None


def test_compare(models):
    print(f"\n{'='*50}")
    print("Testing COMPARE endpoint (cosine similarity)")
    print(f"{'='*50}")

    payload = {
        "text": TEST_TEXT,
        "models": models,
        "local_model_name": "llama3"
    }

    try:
        response = requests.post(f"{BASE_URL}/compare", json=payload, timeout=720)
        if response.status_code != 200:
            print(f"  ERROR: {response.status_code}")
            return

        data = response.json()
        comparison = data.get("comparison", {})
        similarity = comparison.get("similarity_between_models", {})

        print(f"\n  Fastest Model:           {comparison.get('fastest_model', 'N/A').upper()}")
        print(f"  Most Readable Model:     {comparison.get('most_readable_model', 'N/A').upper()}")
        print(f"  Best Keyword Coverage:   {comparison.get('best_keyword_coverage_model', 'N/A').upper()}")
        print(f"  Best ROUGE Score:        {comparison.get('best_rouge_score_model', 'N/A').upper()}")
        print(f"\n  Cosine Similarity Between Models:")
        for pair, score in similarity.items():
            print(f"    {pair}: {score}")

        print(f"\n  Recommendation: {comparison.get('recommendation', 'N/A')}")

    except Exception as e:
        print(f"  FAILED: {e}")


def print_summary_table(results):
    valid = [r for r in results if r is not None]
    if not valid:
        print("\nNo valid results to display.")
        return

    print("\n" + "="*90)
    print("SUMMARY TABLE (copy these numbers into your report)")
    print("="*90)
    print(f"{'Model':<10} {'Time(s)':<10} {'Words':<8} {'Flesch':<10} {'ROUGE-1':<10} {'ROUGE-2':<10} {'ROUGE-L':<10} {'KW%':<8}")
    print("-"*90)
    for r in valid:
        print(
            f"{r['model'].upper():<10} "
            f"{str(r['response_time_sec']):<10} "
            f"{str(r['word_count']):<8} "
            f"{str(r['flesch_reading_ease']):<10} "
            f"{str(r['rouge_1']):<10} "
            f"{str(r['rouge_2']):<10} "
            f"{str(r['rouge_L']):<10} "
            f"{str(r['keyword_coverage_percent']):<8}"
        )
    print("="*90)

    with open("evaluation_results.json", "w") as f:
        json.dump(valid, f, indent=2)
    print("\nFull results saved to: evaluation_results.json")


if __name__ == "__main__":
    print("Study Companion — Model Evaluation Script")
    print("Make sure uvicorn is running before proceeding.\n")

    results = []
    for model in MODELS:
        result = test_model(model)
        results.append(result)
        if model != MODELS[-1]:
            time.sleep(2)

    print_summary_table(results)

    valid_models = [r["model"] for r in results if r is not None]
    if len(valid_models) >= 2:
        test_compare(valid_models[:2])
