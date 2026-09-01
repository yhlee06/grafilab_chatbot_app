# Tool schema definition for LLM (OpenAI Standard Tool Schema)

WEB_SEARCH_TOOL = {
    "type": "function",
    "function": {
        "name": "web_search",
        "description": "Search the internet for real-time, up-to-date information, news, current events, locations, weather, restaurants, etc.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "The search query string to look up on the web"
                }
            },
            "required": ["query"]
        }
    }
}
