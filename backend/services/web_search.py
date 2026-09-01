import os
from tavily import TavilyClient

def perform_web_search(query: str) -> str:
    """
    Executes a web search using the Tavily search engine.
    """
    api_key = os.getenv("TAVILY_API_KEY", "")
    
    if not api_key or api_key == "your_tavily_api_key_here":
        return f"[Mock Search Result] TAVILY_API_KEY is not configured. Search query: '{query}'. Please configure a valid Tavily API Key in your .env file."
    
    try:
        tavily = TavilyClient(api_key=api_key)
        response = tavily.search(query=query, max_results=5, search_depth="basic")
        
        results = []
        for result in response.get("results", []):
            title = result.get("title", "No Title")
            content = result.get("content", "")
            url = result.get("url", "")
            results.append(f"Title: {title}\nURL: {url}\nSnippet: {content}\n")
            
        if not results:
            return "No relevant search results found."
            
        return "\n---\n".join(results)
    except Exception as e:
        return f"Error executing web search: {str(e)}"
