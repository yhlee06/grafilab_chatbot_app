from fastapi import FastAPI
import psycopg2
from psycopg2.extras import RealDictCursor

app = FastAPI(title="Grafilab Chatbot API")

DB_CONFIG = {
    "dbname": "chatbot_app",
    "user": "postgres",
    "password": "postgres",
    "host": "localhost",
    "port": "5432"
}

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

@app.get("/")
def read_root():
    return {"message": "Welcome to Grafilab Backend API!"}

@app.get("/api/models")
def get_models():
    try:
        conn = get_db_connection()
        # 使用 RealDictCursor 可以直接把查出来的数据变成 JSON 格式（字典）
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        cur.execute("SELECT * FROM models ORDER BY id ASC;")
        models = cur.fetchall()
        
        cur.close()
        conn.close()
        
        # 组装成 API 需要的格式返回
        return {"models": models}
        
    except Exception as e:
        return {"error": str(e)}

from pydantic import BaseModel
import httpx

class ChatRequest(BaseModel):
    model: str
    message: str

@app.post("/api/chat")
async def chat_with_ai(request: ChatRequest):
    # 这是你刚才截图里的 API Key
    api_key = "sk-grafilab-1e70776bdf63df074f52904f34fec41491bc35f1fac74dc3"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # 动态查库：根据前端传来的模型名字（例如 "ILMU Mini v3.3"），去数据库里找出它的 model_url
    model_id = request.model # 默认 fallback
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT model_url FROM models WHERE name = %s LIMIT 1;", (request.model,))
        result = cur.fetchone()
        cur.close()
        conn.close()
        
        if result and result['model_url']:
            model_id = result['model_url'] # 真正拿到了数据库里的 ilmu/ilmu-mini-v3.3 等等
    except Exception as e:
        print("查库失败:", e)

    payload = {
        "model": model_id,
        "messages": [
            {"role": "user", "content": request.message}
        ]
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                "https://console-api.grafilab.ai/api/oai/v1/chat/completions",
                headers=headers,
                json=payload,
                timeout=30.0
            )
            response.raise_for_status()
            data = response.json()
            
            ai_message = data["choices"][0]["message"]["content"]
            return {"reply": ai_message}
            
        except Exception as e:
            return {"reply": f"抱歉，连接 AI 服务器时出错了: {str(e)}"}
