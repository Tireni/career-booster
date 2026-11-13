from io import BytesIO
from pathlib import Path
from docx import Document
from pypdf import PdfReader

MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_TEXT = 40000


class ResumeError(ValueError):
    pass


def extract_resume(filename: str, content: bytes) -> str:
    if len(content) > MAX_FILE_BYTES:
        raise ResumeError('The resume must be 2 MB or smaller.')
    if not content:
        raise ResumeError('The resume file is empty.')
    suffix = Path(filename).suffix.lower()
    try:
        if suffix == '.txt':
            text = content.decode('utf-8-sig')
        elif suffix == '.pdf':
            reader = PdfReader(BytesIO(content), strict=True)
            if reader.is_encrypted:
                raise ResumeError('Password-protected PDFs are not supported.')
            if len(reader.pages) > 20:
                raise ResumeError('The PDF must contain at most 20 pages.')
            text = '\n'.join(page.extract_text() or '' for page in reader.pages)
        elif suffix == '.docx':
            from zipfile import ZipFile
            with ZipFile(BytesIO(content)) as archive:
                if sum(item.file_size for item in archive.infolist()) > 10 * 1024 * 1024:
                    raise ResumeError('The document is too large when opened.')
            doc = Document(BytesIO(content))
            text = '\n'.join(p.text for p in doc.paragraphs)
            text += '\n' + '\n'.join(cell.text for table in doc.tables for row in table.rows for cell in row.cells)
        else:
            raise ResumeError('Use a PDF, DOCX, or UTF-8 TXT file.')
    except ResumeError:
        raise
    except Exception as exc:
        raise ResumeError('This file could not be read. Try another file or paste your resume.') from exc
    text = text.strip()
    if len(text) < 30:
        raise ResumeError('No readable resume text found. Scanned PDFs need OCR; paste the text instead.')
    if len(text) > MAX_TEXT:
        raise ResumeError('Resume text must be 40,000 characters or fewer.')
    return text
