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
import uuid

import database
from services.model_router import route_and_process_request

app = FastAPI(title="Grafilab Chatbot API")

# Ensure conversations and messages tables exist on startup
database.init_db()

def extract_api_key(authorization: Optional[str]) -> Optional[str]:
    if not authorization:
        return None
    if authorization.startswith("Bearer "):
        return authorization.replace("Bearer ", "").strip()
    return authorization.strip()

def generate_title(message: str, max_len: int = 24) -> str:
    cleaned = " ".join(message.strip().split())
    if not cleaned:
        return "New Chat"
    if len(cleaned) <= max_len:
        return cleaned
    return cleaned[:max_len].rstrip() + "..."

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
    conversation_id: Optional[str] = None

@app.post("/api/chat")
async def chat_with_ai(
    request: ChatRequest,
    authorization: Optional[str] = Header(None)
):
    try:
        # Extract user API key from Authorization header
        user_api_key = extract_api_key(authorization)

        # Defend against missing or empty API key
        if not user_api_key:
            return {
                "type": "text",
                "content": "Error: 未检测到有效的 Grafilab API Key。请先在前端登录或在设置中选择您的 API Key。",
                "reply": "Error: 未检测到有效的 Grafilab API Key。请先在前端登录或在设置中选择您的 API Key。"
            }

        # 1. Manage Conversation Session
        conv_id = request.conversation_id
        if not conv_id:
            conv_id = str(uuid.uuid4())
            conv_title = generate_title(request.message)
            database.create_conversation(conv_id, user_api_key, conv_title, request.model)
        else:
            existing_conv = database.get_conversation_by_id(conv_id)
            if not existing_conv:
                conv_title = generate_title(request.message)
                database.create_conversation(conv_id, user_api_key, conv_title, request.model)

        # 2. Record User Message in Database
        user_img = request.image_url or request.file_url
        database.add_message(
            conv_id=conv_id,
            role="user",
            content=request.message,
            msg_type="text",
            image_url=user_img
        )

        file_or_img = request.image_url or request.file_url
        reply_result = await route_and_process_request(
            model_name_or_url=request.model,
            user_message=request.message,
            file_or_image_url=file_or_img,
            history=request.history,
            api_key=user_api_key
        )

        if isinstance(reply_result, dict):
            if "content" in reply_result and "reply" not in reply_result:
                reply_result["reply"] = reply_result["content"]
            elif "reply" in reply_result and "content" not in reply_result:
                reply_result["content"] = reply_result["reply"]
            if "type" not in reply_result:
                reply_result["type"] = "text"
        else:
            reply_result = {
                "type": "text",
                "content": str(reply_result),
                "reply": str(reply_result)
            }

        # 3. Record Assistant Response in Database
        if reply_result.get("type") == "image":
            database.add_message(
                conv_id=conv_id,
                role="assistant",
                content=reply_result.get("content", "") or "",
                msg_type="image",
                image_url=reply_result.get("image_url")
            )
        else:
            database.add_message(
                conv_id=conv_id,
                role="assistant",
                content=reply_result.get("content") or reply_result.get("reply") or "",
                msg_type="text",
                image_url=None
            )

        # Attach conversation_id so frontend can maintain conversation state
        reply_result["conversation_id"] = conv_id
        return reply_result

    except Exception as e:
        import traceback
        print("\n" + "="*50)
        print("[BACKEND SERVER ERROR]")
        print(f"Exception Type: {type(e).__name__}")
        print(f"Message: {e}")
        traceback.print_exc()
        print("="*50 + "\n")
        return {
            "type": "text",
            "content": f"Backend Error: {str(e)}",
            "reply": f"Backend Error: {str(e)}"
        }

@app.get("/api/conversations")
def get_user_conversations(authorization: Optional[str] = Header(None)):
    """
    Returns list of conversations for the current user.
    """
    user_api_key = extract_api_key(authorization)
    if not user_api_key:
        return {"conversations": []}
    rows = database.get_conversations(user_api_key)
    results = []
    for r in rows:
        results.append({
            "id": r["id"],
            "title": r["title"],
            "model_slug": r["model_slug"],
            "created_at": r["created_at"].isoformat() if r["created_at"] else None,
            "updated_at": r["updated_at"].isoformat() if r["updated_at"] else None,
        })
    return {"conversations": results}

@app.get("/api/conversations/{conversation_id}/messages")
def get_conversation_messages(conversation_id: str, authorization: Optional[str] = Header(None)):
    """
    Returns all messages for a specific conversation.
    """
    user_api_key = extract_api_key(authorization)
    conv = database.get_conversation_by_id(conversation_id)
    if not conv:
        return {"error": "Conversation not found", "messages": []}
    if user_api_key and conv.get("user_key") != user_api_key:
        return {"error": "Unauthorized", "messages": []}
    
    rows = database.get_messages(conversation_id)
    msgs = []
    for m in rows:
        msgs.append({
            "id": m["id"],
            "role": m["role"],
            "type": m["type"],
            "content": m["content"],
            "image_url": m["image_url"],
            "created_at": m["created_at"].isoformat() if m["created_at"] else None,
        })
    return {
        "conversation_id": conversation_id,
        "title": conv["title"],
        "model_slug": conv["model_slug"],
        "messages": msgs
    }

@app.delete("/api/conversations/{conversation_id}")
def remove_conversation(conversation_id: str, authorization: Optional[str] = Header(None)):
    """
    Deletes a conversation and its messages.
    """
    user_api_key = extract_api_key(authorization)
    database.delete_conversation(conversation_id, user_key=user_api_key)
    return {"status": "success", "message": "Conversation deleted"}
