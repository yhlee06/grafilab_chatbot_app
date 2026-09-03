import os
import psycopg2
from psycopg2.extras import RealDictCursor
from services.ai_service import call_ai_model
from services.ocr_service import extract_text_using_glm_ocr

def get_db_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME", "chatbot_app"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432")
    )

async def route_and_process_request(model_name_or_url: str, user_message: str, file_or_image_url: str = None) -> str:
    """
    Model Router:
    Checks whether the selected model has vision/OCR capabilities (supports_ocr).
    - If model has eyes (supports_ocr == True): send file/image directly to vision model.
    - If model has NO eyes (supports_ocr == False): use GLM OCR to extract text first,
      then pass the extracted text into prompt for text model.
    """
    model_url = model_name_or_url
    supports_ocr = False
    
    # 1. Check capability in PostgreSQL
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT model_url, supports_ocr FROM models WHERE name = %s OR model_url = %s LIMIT 1;",
            (model_name_or_url, model_name_or_url)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()
        
        if row:
            model_url = row.get("model_url", model_name_or_url)
            supports_ocr = row.get("supports_ocr", False)
    except Exception as e:
        print(f"Model capability check failed in DB: {e}")

    print(f"[Model Router] Model: '{model_url}' | Supports Vision/OCR: {supports_ocr} | Has File: {bool(file_or_image_url)}")

    # 2. Case A: Model has native vision (supports_ocr == True)
    if file_or_image_url and supports_ocr:
        print("[Model Router] Case A: Model has native vision. Sending image directly to model.")
        return await call_ai_model(model_url=model_url, user_message=user_message, image_url=file_or_image_url)

    # 3. Case B: Model has NO vision (supports_ocr == False)
    elif file_or_image_url and not supports_ocr:
        print("[Model Router] Case B: Model has no vision. Calling GLM OCR first...")
        ocr_result_text = await extract_text_using_glm_ocr(file_or_image_url)
        
        # Merge OCR text into prompt for text model
        enriched_message = (
            f"{user_message}\n\n"
            f"--- [Extracted Content from File via GLM OCR] ---\n"
            f"{ocr_result_text}\n"
            f"------------------------------------------------"
        )
        print("[Model Router] Passing OCR text to text model for final answer.")
        return await call_ai_model(model_url=model_url, user_message=enriched_message)

    # 4. Standard text-only conversation
    else:
        return await call_ai_model(model_url=model_url, user_message=user_message)
