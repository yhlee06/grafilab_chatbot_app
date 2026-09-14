class AuthService {
  static String? _token;
  static String? _selectedApiKey;
  static List<dynamic>? _cachedApiKeys;

  /// Retrieves the saved authentication token
  static String? get token => _token;

  /// Saves the authentication token globally
  static void saveToken(String token) {
    _token = token;
  }

  /// Retrieves the selected API key
  static String? get selectedApiKey => _selectedApiKey;

  /// Saves the selected API key globally
  static void saveApiKey(String apiKey) {
    _selectedApiKey = apiKey;
  }

  /// Retrieves the cached API keys list
  static List<dynamic>? get cachedApiKeys => _cachedApiKeys;

  /// Saves the API keys list globally
  static void saveApiKeysList(List<dynamic> keys) {
    _cachedApiKeys = keys;
  }

  /// Checks if the user is currently logged in
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Clears the token and apiKey upon logout
  static void clear() {
    _token = null;
    _selectedApiKey = null;
    _cachedApiKeys = null;
  }
}
