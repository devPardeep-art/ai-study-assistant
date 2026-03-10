"""
nlp_metrics.py
--------------
Automatically scores any AI model output.
Called after every model response to add quality metrics.

Install libraries first:
    pip install textstat nltk keybert rouge-score scikit-learn
"""

import textstat
from rouge_score import rouge_scorer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from keybert import KeyBERT
import nltk

nltk.download("punkt", quiet=True)
nltk.download("stopwords", quiet=True)
nltk.download("punkt_tab", quiet=True)

from nltk.tokenize import sent_tokenize, word_tokenize
from nltk.corpus import stopwords

_keybert_model = None

def _get_keybert():
    global _keybert_model
    if _keybert_model is None:
        _keybert_model = KeyBERT()
    return _keybert_model


def get_readability(text: str) -> dict:
    """Flesch-Kincaid readability score. Higher = easier to read."""
    score = round(textstat.flesch_reading_ease(text), 2)
    if score >= 90:
        label = "Very Easy"
    elif score >= 70:
        label = "Easy"
    elif score >= 60:
        label = "Standard"
    elif score >= 50:
        label = "Fairly Difficult"
    elif score >= 30:
        label = "Difficult"
    else:
        label = "Very Difficult"
    return {"flesch_reading_ease": score, "readability_label": label}


def get_text_stats(text: str) -> dict:
    """Word count, sentence count, avg words per sentence."""
    sentences = sent_tokenize(text)
    words = [w for w in word_tokenize(text) if w.isalpha()]
    sentence_count = len(sentences)
    word_count = len(words)
    avg = round(word_count / sentence_count, 2) if sentence_count > 0 else 0
    return {
        "word_count": word_count,
        "sentence_count": sentence_count,
        "avg_words_per_sentence": avg
    }


def get_keywords(text: str, top_n: int = 10) -> list:
    """Extract top keywords using KeyBERT."""
    try:
        kw_model = _get_keybert()
        keywords = kw_model.extract_keywords(
            text,
            keyphrase_ngram_range=(1, 2),
            stop_words="english",
            top_n=top_n
        )
        return [kw[0] for kw in keywords]
    except Exception:
        stop_words = set(stopwords.words("english"))
        words = [w.lower() for w in word_tokenize(text) if w.isalpha() and w.lower() not in stop_words]
        freq = {}
        for word in words:
            freq[word] = freq.get(word, 0) + 1
        return sorted(freq, key=freq.get, reverse=True)[:top_n]


def get_keyword_coverage(original_text: str, model_output: str) -> dict:
    """What % of the original keywords appeared in the model output."""
    keywords = get_keywords(original_text, top_n=10)
    output_lower = model_output.lower()
    matched = [kw for kw in keywords if kw.lower() in output_lower]
    coverage = round((len(matched) / len(keywords)) * 100, 2) if keywords else 0
    return {
        "original_keywords": keywords,
        "keywords_found_in_output": matched,
        "keyword_coverage_percent": coverage
    }


def get_rouge_scores(original_text: str, model_output: str) -> dict:
    """ROUGE scores — how much original content was preserved."""
    try:
        scorer = rouge_scorer.RougeScorer(["rouge1", "rouge2", "rougeL"], use_stemmer=True)
        scores = scorer.score(original_text, model_output)
        return {
            "rouge_1": round(scores["rouge1"].fmeasure, 4),
            "rouge_2": round(scores["rouge2"].fmeasure, 4),
            "rouge_L": round(scores["rougeL"].fmeasure, 4)
        }
    except Exception as e:
        return {"rouge_error": str(e)}


def get_cosine_similarity(text_a: str, text_b: str) -> float:
    """How similar are two model outputs? 0 = different, 1 = identical."""
    try:
        vectorizer = TfidfVectorizer()
        tfidf_matrix = vectorizer.fit_transform([text_a, text_b])
        score = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])[0][0]
        return round(float(score), 4)
    except Exception:
        return 0.0


def analyse(original_text: str, model_output: str) -> dict:
    """
    Master function — runs ALL metrics in one call.
    Call this after every model response.

    Usage in main.py:
        from app.utils.nlp_metrics import analyse
        result["metrics"] = analyse(data.text, result["output"])
    """
    if not model_output or not original_text:
        return {"error": "Cannot analyse empty text"}

    readability = get_readability(model_output)
    stats = get_text_stats(model_output)
    keyword_coverage = get_keyword_coverage(original_text, model_output)
    rouge = get_rouge_scores(original_text, model_output)

    return {
        "flesch_reading_ease": readability["flesch_reading_ease"],
        "readability_label": readability["readability_label"],
        "word_count": stats["word_count"],
        "sentence_count": stats["sentence_count"],
        "avg_words_per_sentence": stats["avg_words_per_sentence"],
        "original_keywords": keyword_coverage["original_keywords"],
        "keywords_found_in_output": keyword_coverage["keywords_found_in_output"],
        "keyword_coverage_percent": keyword_coverage["keyword_coverage_percent"],
        "rouge_1": rouge.get("rouge_1"),
        "rouge_2": rouge.get("rouge_2"),
        "rouge_L": rouge.get("rouge_L"),
    }






