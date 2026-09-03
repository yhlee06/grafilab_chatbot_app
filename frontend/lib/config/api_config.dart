class ApiConfig {
  // Wireless Wi-Fi IP of your computer
  static const String baseUrl = 'http://192.168.100.168:8000';

  static String get chatEndpoint => '$baseUrl/api/chat';
  static String get modelsEndpoint => '$baseUrl/api/models';
}
