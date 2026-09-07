import os
import psycopg2
from psycopg2.extras import RealDictCursor
from services.ai_service import call_ai_model
from services.ocr_service import extract_text_using_glm_ocr
from services.document_parser import analyze_and_normalize_attachment

def get_db_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME", "chatbot_app"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432")
    )

async def route_and_process_request(
    model_name_or_url: str,
    user_message: str,
    file_or_image_url: str = None,
    history: list = None
) -> str:
    """
    Multimodal Agentic Router:
    1. Input Analyzer: Detects IMAGE vs PDF vs TEXT_DOC vs FILE vs TEXT using Magic Bytes.
    2. Model Router: Checks model capabilities (supports_vision) in PostgreSQL.
    3. Branching:
       - PDF / TEXT_DOC: Native document text extraction -> Context Builder -> Selected LLM
       - IMAGE + supports_vision=True: Direct Model
       - IMAGE + supports_vision=False: Qwen 3 VL Flash -> Context Builder -> Selected LLM
       - FILE + supports_vision=False: GLM OCR -> Context Builder -> Selected LLM
       - Dedicated GLM OCR: Direct OCR extraction or multi-turn chat
    """
    model_url = model_name_or_url
    supports_vision = False
    
    # 1. Phase 1: Input Analyzer with Magic Bytes & MIME Normalization
    input_type, normalized_uri, extracted_doc_text = analyze_and_normalize_attachment(file_or_image_url)
    print(f"\n[Input Analyzer] Detected Type: {input_type}")
    
    # 2. Phase 2: Model Capability Check from Database
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "SELECT model_url, supports_vision FROM models WHERE name = %s OR model_url = %s LIMIT 1;",
            (model_name_or_url, model_name_or_url)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()
        
        if row:
            model_url = row.get("model_url", model_name_or_url)
            supports_vision = row.get("supports_vision", False)
    except Exception as e:
        print(f"Model capability check failed in DB: {e}")

    print(f"[Model Router] Selected Model: '{model_url}' | Supports Vision: {supports_vision} | History Turns: {len(history) if history else 0}")

    # Case: User explicitly chose GLM OCR
    if model_url == "grafilab/glm-ocr" or model_name_or_url == "GLM OCR":
        if file_or_image_url:
            if input_type in ["PDF", "TEXT_DOC"] and extracted_doc_text:
                print("[Model Router] Dedicated GLM OCR on Document: returning parsed document text.")
                return extracted_doc_text
            print("[Model Router] Dedicated GLM OCR selected on image. Extracting text directly...")
            return await extract_text_using_glm_ocr(normalized_uri, user_prompt=user_message)
        else:
            if history and len(history) > 0:
                print("[Model Router] GLM OCR follow-up query with history. Answering...")
                return await call_ai_model(model_url=model_url, user_message=user_message, history=history)
            else:
                return "请上传图片或文件，GLM OCR 将直接为您提取其中的全部文字与表格。"

    # 3. Phase 3 & 4: Branching according to architecture flowchart

    # --- BRANCH 1: PDF / TEXT_DOC (Native parsed document) ---
    if input_type in ["PDF", "TEXT_DOC"] and extracted_doc_text:
        print(f"[Model Router] Branch: {input_type} -> Native Document Extraction -> Context Builder")
        enriched_message = (
            f"{user_message}\n\n"
            f"--- [Document Content Extracted via Document Parser] ---\n"
            f"{extracted_doc_text}\n"
            f"--------------------------------------------------------\n"
            f"请仔细阅读上述文档内容，回答用户的问题。"
        )
        print(f"[Selected LLM] Sending parsed document text to {model_url}...")
        return await call_ai_model(model_url=model_url, user_message=enriched_message, history=history)

    # --- BRANCH 2: IMAGE ---
    elif input_type == "IMAGE":
        if supports_vision:
            print("[Model Router] Branch: IMAGE -> supports_vision=True -> Direct Model")
            return await call_ai_model(model_url=model_url, user_message=user_message, image_url=normalized_uri, history=history)
        else:
            print("[Model Router] Branch: IMAGE -> supports_vision=False -> Qwen 3 VL Flash (Visual Proxy)")
            visual_query = f"请仔细观察这张图片，详细提取并描述与用户问题相关的画面、文字、数据与细节。用户问题：{user_message}"
            visual_description = await call_ai_model(
                model_url="qwen/qwen3-vl-flash",
                user_message=visual_query,
                image_url=normalized_uri
            )
            
            # Context Builder
            print(f"[Context Builder] Stitched visual analysis from Qwen 3 VL Flash into prompt for {model_url}")
            enriched_message = (
                f"{user_message}\n\n"
                f"--- [Visual Analysis from Image via Qwen 3 VL Flash] ---\n"
                f"{visual_description}\n"
                f"---------------------------------------------------------\n"
                f"请结合上述图片中的视觉与文字细节，准确回答用户的问题。"
            )
            print(f"[Selected LLM] Sending enriched prompt to {model_url}...")
            return await call_ai_model(model_url=model_url, user_message=enriched_message, history=history)

    # --- BRANCH 3: GENERIC FILE ---
    elif input_type == "FILE":
        if supports_vision:
            print("[Model Router] Branch: FILE -> supports_vision=True -> Direct Model")
            return await call_ai_model(model_url=model_url, user_message=user_message, image_url=normalized_uri, history=history)
        else:
            print("[Model Router] Branch: FILE -> supports_vision=False -> GLM OCR (Document Extraction)")
            ocr_text = await extract_text_using_glm_ocr(normalized_uri, user_prompt=user_message)
            
            # Context Builder
            print(f"[Context Builder] Stitched extracted OCR text into prompt for {model_url}")
            enriched_message = (
                f"{user_message}\n\n"
                f"--- [Extracted Content from File via GLM OCR] ---\n"
                f"{ocr_text}\n"
                f"------------------------------------------------\n"
                f"请仔细阅读上述提取的文档内容，回答用户的问题。"
            )
            print(f"[Selected LLM] Sending enriched prompt to {model_url}...")
            return await call_ai_model(model_url=model_url, user_message=enriched_message, history=history)

    # --- BRANCH 4: PURE TEXT ---
    else:
        print("[Model Router] Branch: PURE TEXT -> Direct Model")
        return await call_ai_model(model_url=model_url, user_message=user_message, history=history)
