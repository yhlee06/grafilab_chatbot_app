import os
import json
import httpx

# Default image generation model (Seedream)
DEFAULT_IMAGE_MODEL = "byteplus/seedream-5-0-lite-260128"

def resolve_image_model(model_override: str = None) -> str:
    """
    Image Model Router:
    Decoupled from Chat Model intent classification.
    Maps image generation tasks to backend models without requiring Chat Model to specify model slug.
    """
    if model_override and model_override.strip():
        return model_override.strip()
    return DEFAULT_IMAGE_MODEL

async def generate_image(
    prompt: str,
    api_key: str = None,
    model: str = None
) -> dict:
    """
    Calls Grafilab OpenAI-compatible Image Generation API:
    POST https://console-api.grafilab.ai/api/oai/v1/images/generations
    """
    effective_key = api_key or os.getenv("GRAFILAB_API_KEY", "")
    if not effective_key:
        return {
            "success": False,
            "error": "Missing Grafilab API Key for image generation."
        }

    base_url = os.getenv("GRAFILAB_BASE_URL", "https://console-api.grafilab.ai/api/oai/v1")
    endpoint = f"{base_url}/images/generations"
    target_model = resolve_image_model(model)

    clean_prompt = prompt.strip() if prompt else ""
    if not clean_prompt:
        return {
            "success": False,
            "error": "Image prompt cannot be empty."
        }

    headers = {
        "Authorization": f"Bearer {effective_key}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": target_model,
        "prompt": clean_prompt,
        "n": 1
    }

    print("\n" + "="*50)
    print("[IMAGE GENERATION REQUEST]")
    print(f"Model: {target_model}")
    print(f"Prompt: {clean_prompt}")
    print("="*50 + "\n")

    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            response = await client.post(endpoint, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()

            items = data.get("data", [])
            if not items or not isinstance(items, list):
                return {
                    "success": False,
                    "error": "No image data returned from image generation API."
                }

            first_item = items[0]
            image_url = first_item.get("url")

            # Fallback if returned as base64
            if not image_url and first_item.get("b64_json"):
                image_url = f"data:image/png;base64,{first_item['b64_json']}"

            if not image_url:
                return {
                    "success": False,
                    "error": "No valid image URL or image data found in response."
                }

            print(f"[Image Generation Success] URL: {image_url[:80]}...")
            return {
                "success": True,
                "image_url": image_url,
                "prompt": clean_prompt,
                "model": target_model
            }

    except httpx.HTTPStatusError as e:
        status_code = e.response.status_code if hasattr(e, 'response') and e.response is not None else "Unknown"
        detail = "Image generation service error"
        try:
            err_json = e.response.json()
            if isinstance(err_json, dict) and "error" in err_json:
                err_obj = err_json["error"]
                if isinstance(err_obj, dict) and "message" in err_obj:
                    detail = err_obj["message"]
                elif isinstance(err_obj, str):
                    detail = err_obj
        except Exception:
            detail = e.response.text[:200] if hasattr(e, 'response') and e.response is not None else str(e)

        print(f"[IMAGE GENERATION HTTP ERROR {status_code}]: {detail}")
        return {
            "success": False,
            "error": f"Image Generation Error ({status_code}): {detail}"
        }

    except Exception as e:
        print(f"[IMAGE GENERATION UNEXPECTED ERROR]: {e}")
        return {
            "success": False,
            "error": f"Failed to generate image: {str(e)}"
        }
