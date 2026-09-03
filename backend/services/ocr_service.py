import os
import httpx

async def extract_text_using_glm_ocr(file_url_or_base64: str) -> str:
    """
    Calls dedicated GLM OCR (grafilab/glm-ocr) to extract text, tables, and documents accurately.
    Prints detailed errors to terminal if any step fails.
    """
    api_key = os.getenv("GRAFILAB_API_KEY", "")
    base_url = os.getenv("GRAFILAB_BASE_URL", "https://console-api.grafilab.ai/api/oai/v1")
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "grafilab/glm-ocr",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Please extract all text, tables, and content accurately from this file/image."},
                    {
                        "type": "image_url",
                        "image_url": {"url": file_url_or_base64}
                    }
                ]
            }
        ]
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
            return data["choices"][0]["message"].get("content") or "No text could be extracted by GLM OCR."
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
