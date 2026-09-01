import os
import json
import httpx
from tools.web_search_tool import WEB_SEARCH_TOOL
from services.web_search import perform_web_search

async def get_ai_chat_response(model_url: str, user_message: str) -> str:
    """
    Handles conversation with the LLM and triggers Tool Calling when needed.
    """
    api_key = os.getenv("GRAFILAB_API_KEY", "")
    base_url = os.getenv("GRAFILAB_BASE_URL", "https://console-api.grafilab.ai/api/oai/v1")
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    messages = [
        {"role": "user", "content": user_message}
    ]
    
    # 1st Request: Send user question along with available tools to the AI
    payload = {
        "model": model_url,
        "messages": messages,
        "tools": [WEB_SEARCH_TOOL],
        "tool_choice": "auto"
    }
    
    async with httpx.AsyncClient() as client:
        try:
            # 1. Send the first round request
            response = await client.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=payload,
                timeout=45.0
            )
            response.raise_for_status()
            data = response.json()
            
            choice = data["choices"][0]
            message_data = choice["message"]
            
            # 2. Check if the AI decided to call a tool (Tool Calling)
            tool_calls = message_data.get("tool_calls")
            
            if not tool_calls:
                # Direct reply without calling any tool
                return message_data.get("content") or "No reply received from AI."
            
            # 3. If AI decided to call tools
            # Append AI's assistant message (with tool_calls intent) to conversation history
            messages.append(message_data)
            
            for tool_call in tool_calls:
                function_info = tool_call.get("function", {})
                function_name = function_info.get("name")
                
                # Parse tool arguments
                arguments_str = function_info.get("arguments", "{}")
                try:
                    args = json.loads(arguments_str)
                except Exception:
                    args = {}
                
                tool_result = ""
                # Execute the corresponding Python tool
                if function_name == "web_search":
                    query = args.get("query", user_message)
                    print(f"🔍 [Tool Calling] AI triggered web search for query: '{query}'")
                    tool_result = perform_web_search(query)
                else:
                    tool_result = f"Unknown tool: {function_name}"
                
                # Append tool execution result with role: 'tool'
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.get("id"),
                    "name": function_name,
                    "content": tool_result
                })
            
            # 4. Send 2nd Request: Pass the tool results back to AI for the final answer
            second_payload = {
                "model": model_url,
                "messages": messages
            }
            
            second_response = await client.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=second_payload,
                timeout=45.0
            )
            second_response.raise_for_status()
            second_data = second_response.json()
            
            return second_data["choices"][0]["message"].get("content") or "AI failed to generate a response."
            
        except Exception as e:
            return f"Error processing request: {str(e)}"
