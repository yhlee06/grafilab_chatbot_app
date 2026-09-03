import os
import sys
import json
import time
import uuid

# Ensure UTF-8 output in Windows terminal for Chinese characters
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
from datetime import datetime
import httpx
from tools.web_search_tool import WEB_SEARCH_TOOL
from services.web_search import perform_web_search

LOG_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs", "chat_history.log")

def get_iso_timestamp() -> str:
    return datetime.now().astimezone().isoformat(timespec='seconds')

def append_json_log(event_data: dict):
    try:
        os.makedirs(os.path.dirname(LOG_FILE_PATH), exist_ok=True)
        with open(LOG_FILE_PATH, "a", encoding="utf-8") as f:
            f.write(json.dumps(event_data, ensure_ascii=False) + "\n")
    except Exception as e:
        print(f"Error writing to log file: {e}")

async def call_ai_model(model_url: str, user_message: str, image_url: str = None) -> str:
    """
    Invokes the AI model.
    Supports multimodal input (when image_url is provided) or standard text chat with Tool Calling.
    """
    request_start_time = time.time()
    req_id = f"req_{uuid.uuid4().hex[:6]}"
    
    append_json_log({
        "timestamp": get_iso_timestamp(),
        "level": "INFO",
        "event": "request_started",
        "request_id": req_id,
        "model": model_url,
        "user_message": user_message,
        "has_image": bool(image_url)
    })
    
    api_key = os.getenv("GRAFILAB_API_KEY", "")
    base_url = os.getenv("GRAFILAB_BASE_URL", "https://console-api.grafilab.ai/api/oai/v1")
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # Multimodal or text content
    if image_url:
        user_content = [
            {"type": "text", "text": f"{user_message}\n\n(Please answer in the same language as the question above, e.g. in Chinese if the question is in Chinese)."},
            {"type": "image_url", "image_url": {"url": image_url}}
        ]
    else:
        user_content = user_message
        
    system_instruction = (
        "You are a helpful and intelligent AI assistant. "
        "Strict rule: Always respond in the exact same language that the user uses in their question. "
        "If the user asks in Chinese, you must reply entirely in natural, fluent Chinese."
    )
    
    messages = [
        {"role": "system", "content": system_instruction},
        {"role": "user", "content": user_content}
    ]
    
    max_tool_turns = 3
    turn = 0
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            while turn < max_tool_turns:
                turn += 1
                llm_turn_start = time.time()
                
                payload = {
                    "model": model_url,
                    "messages": messages
                }
                
                # Only provide search tool if not a direct vision request
                if not image_url:
                    payload["tools"] = [WEB_SEARCH_TOOL]
                    payload["tool_choice"] = "auto"
                
                response = await client.post(
                    f"{base_url}/chat/completions",
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                data = response.json()
                
                choice = data["choices"][0]
                message_data = choice.get("message", {})
                tool_calls = message_data.get("tool_calls")
                
                # Direct answer from model
                if not tool_calls:
                    llm_duration_ms = int((time.time() - llm_turn_start) * 1000)
                    
                    final_content = message_data.get("content")
                    if not final_content and message_data.get("reasoning_content"):
                        final_content = message_data.get("reasoning_content")
                    if not final_content:
                        final_content = choice.get("text") or "No content returned from AI model."
                    
                    append_json_log({
                        "timestamp": get_iso_timestamp(),
                        "level": "INFO",
                        "event": "llm_response",
                        "request_id": req_id,
                        "model": model_url,
                        "status": "success",
                        "duration_ms": llm_duration_ms
                    })
                    
                    total_duration_ms = int((time.time() - request_start_time) * 1000)
                    append_json_log({
                        "timestamp": get_iso_timestamp(),
                        "level": "INFO",
                        "event": "request_completed",
                        "request_id": req_id,
                        "total_duration_ms": total_duration_ms
                    })
                    
                    print(f"\n[Final AI Response]\n{final_content}\n")
                    return final_content
                
                # Tool Call request
                messages.append(message_data)
                
                for tool_call in tool_calls:
                    call_id = tool_call.get("id") or f"call_{uuid.uuid4().hex[:6]}"
                    function_info = tool_call.get("function", {})
                    function_name = function_info.get("name", "web_search")
                    
                    arguments_str = function_info.get("arguments", "{}")
                    try:
                        args = json.loads(arguments_str) if isinstance(arguments_str, str) else arguments_str
                    except Exception:
                        args = {}
                    
                    query_val = args.get("query", user_message)
                    
                    append_json_log({
                        "timestamp": get_iso_timestamp(),
                        "level": "INFO",
                        "event": "tool_call",
                        "request_id": req_id,
                        "tool_call_id": call_id,
                        "tool": function_name,
                        "query": query_val
                    })
                    
                    print(f"\n[Tool Call]\nQuery: {query_val}\n")
                    
                    tool_exec_start = time.time()
                    search_data = perform_web_search(query_val)
                    tool_duration_ms = int((time.time() - tool_exec_start) * 1000)
                    
                    results_list = search_data.get("results", [])
                    result_count = search_data.get("count", 0)
                    
                    append_json_log({
                        "timestamp": get_iso_timestamp(),
                        "level": "INFO",
                        "event": "tool_result",
                        "request_id": req_id,
                        "tool_call_id": call_id,
                        "tool": function_name,
                        "result_count": result_count,
                        "duration_ms": tool_duration_ms
                    })
                    
                    print("[Tool Result]")
                    if results_list:
                        for i, res in enumerate(results_list, 1):
                            print(f"{i}. {res['title']}\n   URL: {res['url']}\n   Snippet: {res['snippet']}\n")
                    else:
                        print(f"{search_data.get('raw_text', 'No results found.')}\n")
                    
                    messages.append({
                        "role": "tool",
                        "tool_call_id": call_id,
                        "name": function_name,
                        "content": search_data.get("raw_text", "")
                    })
            
            # Max tool turns reached
            final_turn_start = time.time()
            final_payload = {"model": model_url, "messages": messages}
            
            final_response = await client.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=final_payload,
                timeout=60.0
            )
            final_response.raise_for_status()
            final_data = final_response.json()
            
            choice = final_data["choices"][0]
            final_msg = choice.get("message", {})
            final_reply = final_msg.get("content") or final_msg.get("reasoning_content") or choice.get("text") or "No content available."
            
            final_duration_ms = int((time.time() - final_turn_start) * 1000)
            total_duration_ms = int((time.time() - request_start_time) * 1000)
            
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "INFO",
                "event": "llm_response",
                "request_id": req_id,
                "model": model_url,
                "status": "success",
                "duration_ms": final_duration_ms
            })
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "INFO",
                "event": "request_completed",
                "request_id": req_id,
                "total_duration_ms": total_duration_ms
            })
            
            print(f"\n[Final AI Response]\n{final_reply}\n")
            return final_reply
            
        except httpx.HTTPStatusError as e:
            total_duration_ms = int((time.time() - request_start_time) * 1000)
            status_code = e.response.status_code if hasattr(e, 'response') and e.response is not None else "Unknown"
            detail = e.response.text if hasattr(e, 'response') and e.response is not None else str(e)
            error_msg = f"API Error ({status_code}): {detail}"
            
            print("\n" + "="*50)
            print(f"[AI MODEL API HTTP ERROR {status_code}]")
            print(f"Model: {model_url}")
            print(f"Error Detail: {detail}")
            print("="*50 + "\n")
            
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "ERROR",
                "event": "llm_response",
                "request_id": req_id,
                "model": model_url,
                "status": "failed",
                "error": error_msg,
                "duration_ms": total_duration_ms
            })
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "ERROR",
                "event": "request_completed",
                "request_id": req_id,
                "total_duration_ms": total_duration_ms
            })
            return error_msg
            
        except Exception as e:
            import traceback
            total_duration_ms = int((time.time() - request_start_time) * 1000)
            error_msg = f"Error processing request: {str(e)}"
            
            print("\n" + "="*50)
            print("[UNEXPECTED SYSTEM ERROR]")
            print(f"Model: {model_url}")
            print(f"Exception Type: {type(e).__name__}")
            print(f"Message: {e}")
            traceback.print_exc()
            print("="*50 + "\n")
            
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "ERROR",
                "event": "llm_response",
                "request_id": req_id,
                "model": model_url,
                "status": "failed",
                "error": str(e),
                "duration_ms": total_duration_ms
            })
            append_json_log({
                "timestamp": get_iso_timestamp(),
                "level": "ERROR",
                "event": "request_completed",
                "request_id": req_id,
                "total_duration_ms": total_duration_ms
            })
            return error_msg
