import os
import re
import httpx

def clean_and_format_ocr_output(raw_text: str) -> str:
    """
    Cleans up GLM OCR raw output, converting HTML tables/tags into human-readable Markdown/text.
    Ensures text is fully visible in Flutter MarkdownBody without invisible HTML tags.
    """
    if not raw_text or not raw_text.strip():
        return "GLM OCR 未能在此图片中识别到清晰的文字或表格，请尝试重新拍照或调整角度。"
    
    text = raw_text.strip()
    
    # Remove leading "Markdown:" if present
    if text.startswith("Markdown:"):
        text = text[len("Markdown:"):].strip()
        
    # If HTML table tags are present, convert to clean readable text
    if any(tag in text.lower() for tag in ["<table", "<tr", "<td", "<th", "<thead", "<tbody"]):
        # Replace <br>, <br/> with newline
        text = re.sub(r'<br\s*/?>', '\n', text, flags=re.IGNORECASE)
        
        # Replace closing </th> and </td> with a clean separator
        text = re.sub(r'</t[dh]>', ' | ', text, flags=re.IGNORECASE)
        
        # Replace closing </tr> with newline
        text = re.sub(r'</tr>', '\n', text, flags=re.IGNORECASE)
        
        # Strip all other remaining HTML tags
        text = re.sub(r'<[^>]+>', '', text)
        
        # Clean up lines and duplicate separators
        lines = []
        for line in text.split('\n'):
            cleaned = re.sub(r'\s*\|\s*$', '', line.strip()) # remove trailing pipe
            cleaned = re.sub(r'^\s*\|\s*', '', cleaned)      # remove leading pipe
            cleaned = re.sub(r'(\|\s*){2,}', '| ', cleaned)  # normalize multiple pipes
            if cleaned:
                lines.append(cleaned)
        text = '\n'.join(lines)
        
    return text if text.strip() else "GLM OCR 未能在此图片中识别到清晰的文字或表格，请尝试重新拍照或调整角度。"

async def extract_text_using_glm_ocr(file_url_or_base64: str, user_prompt: str = None) -> str:
    """
    Calls dedicated GLM OCR (grafilab/glm-ocr) to extract text, tables, and documents accurately.
    Accepts user prompt and converts raw HTML tables to clean Markdown.
    """
    api_key = os.getenv("GRAFILAB_API_KEY", "")
    base_url = os.getenv("GRAFILAB_BASE_URL", "https://console-api.grafilab.ai/api/oai/v1")
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    prompt_text = user_prompt.strip() if (user_prompt and user_prompt.strip()) else "analyze"
    
    payload = {
        "model": "grafilab/glm-ocr",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {"url": file_url_or_base64}
                    }
                ]
            }
        ],
        "temperature": 0.7,
        "top_p": 0.9
    }
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=payload
            )
            response.raise_for_status()
            data = response.json()
            choice = data.get("choices", [{}])[0]
            message_data = choice.get("message", {})
            raw_content = message_data.get("content") or choice.get("text") or ""
            
            # Format and convert any HTML table tags to human-readable markdown
            formatted_result = clean_and_format_ocr_output(raw_content)
            return formatted_result
            
        except httpx.HTTPStatusError as e:
            detail = e.response.text if hasattr(e, 'response') and e.response is not None else str(e)
            status_code = e.response.status_code if hasattr(e, 'response') and e.response is not None else "Unknown"
            print("\n" + "="*50)
            print(f"[GLM OCR HTTP ERROR {status_code}]")
            print(f"Detail: {detail}")
            print("="*50 + "\n")
            return f"[GLM OCR Failed ({status_code})]: {detail}"
        except Exception as e:
            print("\n" + "="*50)
            print(f"[GLM OCR SYSTEM ERROR]: {e}")
            print("="*50 + "\n")
            return f"[OCR Extraction Failed]: {str(e)}"
