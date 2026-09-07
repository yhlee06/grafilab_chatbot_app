import base64
import io
import pypdf

def analyze_and_normalize_attachment(file_or_image_url: str):
    """
    Analyzes the attachment by MIME header and Magic Bytes (file signature).
    Returns:
      (detected_type: "IMAGE" | "PDF" | "TEXT_DOC" | "FILE" | "TEXT",
       normalized_data_uri: str,
       extracted_text: str | None)
    """
    if not file_or_image_url or not file_or_image_url.strip():
        return "TEXT", file_or_image_url, None

    data = file_or_image_url.strip()
    
    if not data.startswith("data:"):
        # Plain URL
        return "IMAGE", data, None

    try:
        header, encoded = data.split(',', 1)
        raw_prefix = base64.b64decode(encoded[:128])
        
        # 1. Check Magic Bytes for Images
        if raw_prefix.startswith(b'\xff\xd8\xff'):
            # JPEG image
            normalized_uri = f"data:image/jpeg;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'\x89PNG\r\n\x1a\n'):
            # PNG image
            normalized_uri = f"data:image/png;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'GIF87a') or raw_prefix.startswith(b'GIF89a'):
            # GIF image
            normalized_uri = f"data:image/gif;base64,{encoded}"
            return "IMAGE", normalized_uri, None
        elif raw_prefix.startswith(b'RIFF') and b'WEBP' in raw_prefix[:16]:
            # WEBP image
            normalized_uri = f"data:image/webp;base64,{encoded}"
            return "IMAGE", normalized_uri, None
            
        # 2. Check Magic Bytes for PDF
        elif raw_prefix.startswith(b'%PDF-'):
            # True PDF Document
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

        # 3. Check for Plain Text / CSV
        elif "text/plain" in header or "text/csv" in header:
            doc_bytes = base64.b64decode(encoded)
            try:
                txt_content = doc_bytes.decode('utf-8', errors='replace')
                return "TEXT_DOC", data, txt_content
            except Exception:
                pass
                
        # 4. Fallback based on header
        if "image/" in header:
            return "IMAGE", data, None
        else:
            return "FILE", data, None
            
    except Exception as e:
        print(f"[Document Parser Error]: {e}")
        return "IMAGE", file_or_image_url, None
