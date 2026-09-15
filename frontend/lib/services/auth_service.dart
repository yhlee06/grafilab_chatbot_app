import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static String? _token;
  static String? _selectedApiKey;
  static List<dynamic>? _cachedApiKeys;
  static SharedPreferences? _prefs;

  static const String _keyToken = 'auth_token';
  static const String _keyApiKey = 'selected_api_key';
  static const String _keyCachedKeys = 'cached_api_keys';

  /// Initializes SharedPreferences and loads saved credentials from local storage
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _token = _prefs?.getString(_keyToken);
      _selectedApiKey = _prefs?.getString(_keyApiKey);
      final rawKeys = _prefs?.getString(_keyCachedKeys);
      if (rawKeys != null && rawKeys.isNotEmpty) {
        _cachedApiKeys = json.decode(rawKeys) as List<dynamic>?;
      }
    } catch (_) {
      // Graceful fallback if local read fails
    }
  }

  /// Retrieves the saved authentication token
  static String? get token => _token;

  /// Saves the authentication token globally and writes to local storage
  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  /// Retrieves the selected API key
  static String? get selectedApiKey => _selectedApiKey;

  /// Saves the selected API key globally and writes to local storage
  static Future<void> saveApiKey(String apiKey) async {
    _selectedApiKey = apiKey;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
  }

  /// Retrieves the cached API keys list
  static List<dynamic>? get cachedApiKeys => _cachedApiKeys;

  /// Saves the API keys list globally and writes to local storage
  static Future<void> saveApiKeysList(List<dynamic> keys) async {
    _cachedApiKeys = keys;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedKeys, json.encode(keys));
    } catch (_) {}
  }

  /// Checks if the user is currently logged in
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Clears the token and apiKey upon logout and wipes local storage
  static Future<void> clear() async {
    _token = null;
    _selectedApiKey = null;
    _cachedApiKeys = null;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyCachedKeys);
  }
}

