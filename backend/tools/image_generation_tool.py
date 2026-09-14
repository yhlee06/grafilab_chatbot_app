# Tool schema definition for Image Generation (OpenAI Standard Function Calling Schema)

IMAGE_GENERATION_TOOL = {
    "type": "function",
    "function": {
        "name": "image_generation",
        "description": (
            "Generate, draw, paint, create, or illustrate an image, picture, artwork, or scene. "
            "Call this tool whenever the user explicitly or implicitly asks to draw, generate, visualize, "
            "or create a visual image or picture."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "prompt": {
                    "type": "string",
                    "description": (
                        "A concise, vivid visual description of the image to generate in English. "
                        "Keep under 40 words, focusing on the core subject, setting, art style, and lighting."
                    )
                }
            },
            "required": ["prompt"]
        }
    }
}
