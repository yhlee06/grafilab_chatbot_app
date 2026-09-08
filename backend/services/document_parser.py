import base64
import io
import zipfile
import xml.etree.ElementTree as ET
import pypdf

def extract_docx_text(docx_bytes: bytes) -> str:
    """Extracts text content from a .docx file using built-in zipfile and XML parser."""
    try:
        with zipfile.ZipFile(io.BytesIO(docx_bytes)) as z:
            if "word/document.xml" not in z.namelist():
                return ""
            xml_content = z.read("word/document.xml")
            tree = ET.fromstring(xml_content)
            namespaces = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
            texts = [node.text for node in tree.iterfind(".//w:t", namespaces) if node.text]
            return "\n".join(texts).strip()
    except Exception as e:
        return f"[Failed to extract DOCX text: {str(e)}]"

def analyze_and_normalize_attachment(file_or_image_url: str):
    """
    Input Analyzer & Format Validator:
    Inspects MIME header and Magic Bytes (file signature) against a strict whitelist.
    
    Supported categories:
      - "IMAGE": JPG, JPEG, PNG, WEBP, GIF
      - "PDF": PDF documents
      - "TEXT_DOC": TXT, CSV, DOCX documents
      - "TEXT": Pure text queries (no attachment)
      - "UNSUPPORTED": All other file types (immediately rejected)
      
    Returns:
      (detected_type: "IMAGE" | "PDF" | "TEXT_DOC" | "TEXT" | "UNSUPPORTED",
       normalized_data_uri: str,
       extracted_text: str | None)
    """
    if not file_or_image_url or not file_or_image_url.strip():
        return "TEXT", file_or_image_url, None

    data = file_or_image_url.strip()
    
    if not data.startswith("data:"):
        # Plain web URL without data URI scheme (assume IMAGE if image extension)
        lower_url = data.lower()
        if any(lower_url.endswith(ext) for ext in [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"]):
            return "IMAGE", data, None
        return "UNSUPPORTED", data, None

    try:
        header, encoded = data.split(',', 1)
        raw_prefix = base64.b64decode(encoded[:128])
        header_lower = header.lower()
        
        # 1. Validate IMAGE (JPG, PNG, GIF, WEBP)
        if raw_prefix.startswith(b'\xff\xd8\xff'):
            # Valid JPEG image
            normalized_uri = f"data:image/jpeg;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'\x89PNG\r\n\x1a\n'):
            # Valid PNG image
            normalized_uri = f"data:image/png;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'GIF87a') or raw_prefix.startswith(b'GIF89a'):
            # Valid GIF image
            normalized_uri = f"data:image/gif;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'RIFF') and b'WEBP' in raw_prefix[:16]:
            # Valid WEBP image
            normalized_uri = f"data:image/webp;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif "image/jpeg" in header_lower or "image/png" in header_lower or "image/webp" in header_lower:
            # Explicit image header
            return "IMAGE", data, None
            
        # 2. Validate PDF Document
        elif raw_prefix.startswith(b'%PDF-') or "application/pdf" in header_lower:
            pdf_bytes = base64.b64decode(encoded)
            try:
                reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
                text_list = []
                for i, page in enumerate(reader.pages, 1):
                    extracted = page.extract_text()
                    if extracted and extracted.strip():
                        text_list.append(f"--- [Page {i}] ---\n{extracted.strip()}")
                full_pdf_text = "\n\n".join(text_list)
                if not full_pdf_text.strip():
                    full_pdf_text = "[PDF Document contains no selectable text (scanned image inside PDF).]"
                return "PDF", data, full_pdf_text
            except Exception as e:
                return "PDF", data, f"[Failed to parse PDF document: {str(e)}]"

        # 3. Validate TEXT_DOC (Plain text, CSV, DOCX)
        elif "text/plain" in header_lower or "text/csv" in header_lower:
            doc_bytes = base64.b64decode(encoded)
            try:
                txt_content = doc_bytes.decode('utf-8', errors='replace')
                return "TEXT_DOC", data, txt_content
            except Exception:
                return "UNSUPPORTED", data, None
                
        elif "wordprocessingml.document" in header_lower or (raw_prefix.startswith(b'PK\x03\x04')):
            docx_bytes = base64.b64decode(encoded)
            docx_text = extract_docx_text(docx_bytes)
            if docx_text:
                return "TEXT_DOC", data, docx_text
            else:
                return "UNSUPPORTED", data, None

        # 4. Any other format is UNSUPPORTED
        return "UNSUPPORTED", data, None
            
    except Exception as e:
        print(f"[Input Analyzer Validation Error]: {e}")
        return "UNSUPPORTED", file_or_image_url, None
