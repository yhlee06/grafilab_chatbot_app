import os
import sys
from typing import Optional
from dotenv import load_dotenv

# Ensure UTF-8 output in Windows terminal for Chinese characters
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# Load environment variables from .env
load_dotenv()

from fastapi import FastAPI, Header
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

from services.model_router import route_and_process_request

app = FastAPI(title="Grafilab Chatbot API")

def get_db_connection():
    return psycopg2.connect(
        dbname=os.getenv("DB_NAME", "chatbot_app"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", "postgres"),
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432")
    )

@app.get("/")
def read_root():
    return {"message": "Welcome to Grafilab Backend API!"}

@app.get("/api/models")
def get_models():
    """
    Returns AI models list, safely excluding GLM OCR from frontend UI.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM models ORDER BY id ASC;")
        models = cur.fetchall()
        
        cur.close()
        conn.close()
        
        return {"models": models}
    except Exception as e:
        return {"error": str(e)}

class ChatRequest(BaseModel):
    model: str
    message: str
    image_url: Optional[str] = None
    file_url: Optional[str] = None
    history: Optional[list] = None

@app.post("/api/chat")
async def chat_with_ai(
    request: ChatRequest,
    authorization: Optional[str] = Header(None)
):
    try:
        # Extract user API key from Authorization header
        user_api_key = None
        if authorization and authorization.startswith("Bearer "):
            user_api_key = authorization.replace("Bearer ", "").strip()
        elif authorization:
            user_api_key = authorization.strip()

        # Defend against missing or empty API key
        if not user_api_key:
            return {"reply": "Error: 未检测到有效的 Grafilab API Key。请先在前端登录或在设置中选择您的 API Key。"}

        file_or_img = request.image_url or request.file_url
        reply_text = await route_and_process_request(
            model_name_or_url=request.model,
            user_message=request.message,
            file_or_image_url=file_or_img,
            history=request.history,
            api_key=user_api_key
        )
        return {"reply": reply_text}
    except Exception as e:
        import traceback
        print("\n" + "="*50)
        print("[BACKEND SERVER ERROR]")
        print(f"Exception Type: {type(e).__name__}")
        print(f"Message: {e}")
        traceback.print_exc()
        print("="*50 + "\n")
        return {"reply": f"Backend Error: {str(e)}"}
