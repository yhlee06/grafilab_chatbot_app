class ApiConfig {
  // Wireless Wi-Fi IP of your computer
  static const String baseUrl = 'http://192.168.100.168:8000';

  static String get chatEndpoint => '$baseUrl/api/chat';
  static String get modelsEndpoint => '$baseUrl/api/models';
  static String get conversationsEndpoint => '$baseUrl/api/conversations';
  static String conversationMessagesEndpoint(String id) => '$baseUrl/api/conversations/$id/messages';
  static String deleteConversationEndpoint(String id) => '$baseUrl/api/conversations/$id';
  static const String loginEndpoint = 'https://console-api.grafilab.ai/api/auth/login';
  static const String apiKeysEndpoint = 'https://console-api.grafilab.ai/api/inference/api-key';
  static const String chatCompletionsEndpoint = 'https://console-api.grafilab.ai/api/oai/v1/chat/completions';
}
