import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'select_api_key_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final resData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 &&
          resData['status'] == 200 &&
          resData['data'] != null &&
          resData['data']['token'] != null) {
        final token = resData['data']['token'].toString();

        // 1. Save the token globally in AuthService
        AuthService.saveToken(token);

        // 2. Fetch user's API Key list from Grafilab official API
        try {
          final keyResponse = await http.get(
            Uri.parse(ApiConfig.apiKeysEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': token,
            },
          ).timeout(const Duration(seconds: 15));

          if (keyResponse.statusCode == 200) {
            final keyData = json.decode(utf8.decode(keyResponse.bodyBytes));
            List<dynamic> keys = [];
            if (keyData['data'] is Map && keyData['data']['keys'] is List) {
              keys = keyData['data']['keys'];
            } else if (keyData['data'] is List) {
              keys = keyData['data'];
            }

            AuthService.saveApiKeysList(keys);

            if (!mounted) return;

            if (keys.length == 1) {
              // Case 1: Exactly 1 key -> Auto select and proceed directly to ChatScreen
              final singleKey = (keys[0]['value'] ?? keys[0]['api_key'] ?? '').toString();
              AuthService.saveApiKey(singleKey);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
              return;
            } else if (keys.length > 1) {
              // Case 2: Multiple keys -> Open SelectApiKeyScreen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => SelectApiKeyScreen(apiKeys: keys),
                ),
              );
              return;
            } else {
              // Case 3: 0 keys
              setState(() {
                _isLoading = false;
                _errorMessage = 'No API key found. Please create one on Grafilab Console.';
              });
              return;
            }
          }
        } catch (e) {
          // If checking keys fails, fallback to chat
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
        return;
      }

      // Login failed with server response
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = resData['msg'] ?? 'Login failed. Please check your credentials.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to connect to login server: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Center(
                  child: Text(
                    'WELCOME BACK!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1E2D),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Error message if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Email Label
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2B38),
                  ),
                ),
                const SizedBox(height: 8),

                // Email TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2DCF0),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1E1E2D),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: TextStyle(color: Color(0xFFA09CAD), fontSize: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Label
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2B38),
                  ),
                ),
                const SizedBox(height: 8),

                // Password TextField
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5FC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE2DCF0),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1E1E2D),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: const TextStyle(color: Color(0xFFA09CAD), fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xFF8E8A9C),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Sign In Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B2FC9), Color(0xFFA238E8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x668B2FC9),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
