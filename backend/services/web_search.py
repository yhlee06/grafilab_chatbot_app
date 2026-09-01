import os
from tavily import TavilyClient

def perform_web_search(query: str) -> dict:
    """
    Executes a web search using the Tavily search engine and returns structured data for logging and LLM ingestion.
    """
    api_key = os.getenv("TAVILY_API_KEY", "")
    
    if not api_key or api_key == "your_tavily_api_key_here":
        mock_msg = f"[Mock Search Result] TAVILY_API_KEY is not configured. Search query: '{query}'. Please configure a valid Tavily API Key in your .env file."
        return {
            "engine": "Tavily",
            "search_depth": "basic",
            "max_results": 5,
            "count": 0,
            "results": [],
            "raw_text": mock_msg,
            "error": "TAVILY_API_KEY not configured"
        }
    
    try:
        tavily = TavilyClient(api_key=api_key)
        response = tavily.search(query=query, max_results=5, search_depth="basic")
        
        results_list = []
        raw_text_parts = []
        
        for item in response.get("results", []):
            title = item.get("title", "No Title")
            content = item.get("content", "")
            url = item.get("url", "")
            
            results_list.append({
                "title": title,
                "url": url,
                "snippet": content
            })
            raw_text_parts.append(f"Title: {title}\nURL: {url}\nSnippet: {content}\n")
            
        return {
            "engine": "Tavily",
            "search_depth": "basic",
            "max_results": 5,
            "count": len(results_list),
            "results": results_list,
            "raw_text": "\n---\n".join(raw_text_parts) if raw_text_parts else "No relevant search results found.",
            "error": None
        }
    except Exception as e:
        err_msg = f"Error executing web search: {str(e)}"
        return {
            "engine": "Tavily",
            "search_depth": "basic",
            "max_results": 5,
            "count": 0,
            "results": [],
            "raw_text": err_msg,
            "error": str(e)
        }
