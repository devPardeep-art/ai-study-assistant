"""
file_handler.py
---------------
Handles file uploads and extracts plain text from:
- PDF files
- DOCX (Word) files
- TXT files

Install required libraries:
    pip install pypdf2 python-docx python-multipart
"""

import os
from fastapi import UploadFile
import PyPDF2
import docx
import io


ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt"}
MAX_FILE_SIZE_MB = 10  # Maximum allowed file size


def get_file_extension(filename: str) -> str:
    """Returns the file extension in lowercase e.g. '.pdf'"""
    return os.path.splitext(filename)[1].lower()


def is_allowed_file(filename: str) -> bool:
    """Check if the file type is supported."""
    return get_file_extension(filename) in ALLOWED_EXTENSIONS


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """
    Extracts all text from a PDF file.
    Works with most text-based PDFs (not scanned images).
    """
    try:
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_bytes))
        text = ""
        for page in pdf_reader.pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
        return text.strip()
    except Exception as e:
        raise ValueError(f"Could not read PDF: {str(e)}")


def extract_text_from_docx(file_bytes: bytes) -> str:
    """
    Extracts all text from a Word (.docx) file.
    """
    try:
        doc = docx.Document(io.BytesIO(file_bytes))
        text = "\n".join([paragraph.text for paragraph in doc.paragraphs if paragraph.text.strip()])
        return text.strip()
    except Exception as e:
        raise ValueError(f"Could not read DOCX: {str(e)}")


def extract_text_from_txt(file_bytes: bytes) -> str:
    """
    Extracts text from a plain .txt file.
    """
    try:
        return file_bytes.decode("utf-8").strip()
    except UnicodeDecodeError:
        # Try a different encoding if UTF-8 fails
        return file_bytes.decode("latin-1").strip()


def extract_text(filename: str, file_bytes: bytes) -> str:
    """
    Master function — detects file type and extracts text automatically.
    Call this from the /upload endpoint.
    """
    ext = get_file_extension(filename)

    if ext == ".pdf":
        return extract_text_from_pdf(file_bytes)
    elif ext == ".docx":
        return extract_text_from_docx(file_bytes)
    elif ext == ".txt":
        return extract_text_from_txt(file_bytes)
    else:
        raise ValueError(f"Unsupported file type: {ext}. Please upload PDF, DOCX, or TXT.")






