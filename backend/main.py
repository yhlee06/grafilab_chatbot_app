import os
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

from fastapi import FastAPI
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor

from services.llm_service import get_ai_chat_response

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
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM models WHERE name != 'GLM OCR' ORDER BY id ASC;")
        models = cur.fetchall();
        
        cur.close()
        conn.close()
        
        return {"models": models}
    except Exception as e:
        return {"error": str(e)}

class ChatRequest(BaseModel):
    model: str
    message: str

@app.post("/api/chat")
async def chat_with_ai(request: ChatRequest):
    # 1. Dynamically retrieve the model_url from PostgreSQL by name
    model_url = request.model
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT model_url FROM models WHERE name = %s LIMIT 1;", (request.model,))
        result = cur.fetchone()
        cur.close()
        conn.close()
        
        if result and result.get('model_url'):
            model_url = result['model_url']
    except Exception as e:
        print("Database model lookup error:", e)

    # 2. Call LLM service (Tool Calling + Tavily Search)
    reply_text = await get_ai_chat_response(model_url=model_url, user_message=request.message)
    return {"reply": reply_text}
