"""
file_handler.py
---------------
Handles file uploads and extracts plain text from:
- PDF files
- DOCX (Word) files
- TXT files

Install required libraries:
    pip install pypdf python-docx python-multipart
"""

import os
import pypdf
import docx
import io


ALLOWED_EXTENSIONS = {".pdf", ".docx", ".txt"}
MAX_FILE_SIZE_MB = 10


def get_file_extension(filename: str) -> str:
    """Returns the lowercase file extension of the given filename (e.g. '.pdf')."""
    return os.path.splitext(filename)[1].lower()


def is_allowed_file(filename: str) -> bool:
    """Returns True if the file extension is among the supported types."""
    return get_file_extension(filename) in ALLOWED_EXTENSIONS


def extract_text_from_pdf(file_bytes: bytes) -> str:
    """
    Extracts and concatenates text from all pages of a PDF file.

    Args:
        file_bytes (bytes): Raw bytes of the uploaded PDF file.

    Returns:
        str: Extracted plain text content.

    Raises:
        ValueError: If the PDF cannot be read or parsed.
    """
    try:
        pdf_reader = pypdf.PdfReader(io.BytesIO(file_bytes))
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
    Extracts and concatenates text from all paragraphs of a DOCX file.

    Args:
        file_bytes (bytes): Raw bytes of the uploaded DOCX file.

    Returns:
        str: Extracted plain text content.

    Raises:
        ValueError: If the DOCX file cannot be read or parsed.
    """
    try:
        doc = docx.Document(io.BytesIO(file_bytes))
        text = "\n".join([paragraph.text for paragraph in doc.paragraphs if paragraph.text.strip()])
        return text.strip()
    except Exception as e:
        raise ValueError(f"Could not read DOCX: {str(e)}")


def extract_text_from_txt(file_bytes: bytes) -> str:
    """
    Decodes and returns the text content of a plain TXT file.
    Falls back to latin-1 encoding if UTF-8 decoding fails.

    Args:
        file_bytes (bytes): Raw bytes of the uploaded TXT file.

    Returns:
        str: Decoded plain text content.
    """
    try:
        return file_bytes.decode("utf-8").strip()
    except UnicodeDecodeError:
        return file_bytes.decode("latin-1").strip()


def extract_text(filename: str, file_bytes: bytes) -> str:
    """
    Detects the file type by extension and delegates to the appropriate extraction function.

    Args:
        filename (str): Original filename including extension.
        file_bytes (bytes): Raw bytes of the uploaded file.

    Returns:
        str: Extracted plain text content.

    Raises:
        ValueError: If the file type is not supported.
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