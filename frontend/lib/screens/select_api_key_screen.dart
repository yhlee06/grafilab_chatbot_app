import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class SelectApiKeyScreen extends StatefulWidget {
  final List<dynamic>? apiKeys;

  const SelectApiKeyScreen({super.key, this.apiKeys});

  @override
  State<SelectApiKeyScreen> createState() => _SelectApiKeyScreenState();
}

class _SelectApiKeyScreenState extends State<SelectApiKeyScreen> {
  int _selectedIndex = 0;
  List<dynamic> _keys = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initKeys();
  }

  Future<void> _initKeys() async {
    if (widget.apiKeys != null && widget.apiKeys!.isNotEmpty) {
      setState(() {
        _keys = List.from(widget.apiKeys!);
        _syncSelectedIndex();
      });
      return;
    }

    if (AuthService.cachedApiKeys != null && AuthService.cachedApiKeys!.isNotEmpty) {
      setState(() {
        _keys = List.from(AuthService.cachedApiKeys!);
        _syncSelectedIndex();
      });
      return;
    }

    await _fetchKeys();
  }

  void _syncSelectedIndex() {
    final currentKey = AuthService.selectedApiKey;
    if (currentKey != null && currentKey.isNotEmpty) {
      final idx = _keys.indexWhere(
        (item) => (item['value'] ?? item['api_key'] ?? '').toString() == currentKey,
      );
      if (idx != -1) {
        _selectedIndex = idx;
        return;
      }
    }
    _selectedIndex = 0;
  }

  Future<void> _fetchKeys() async {
    final token = AuthService.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'Please sign in first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.apiKeysEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final keyData = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> fetchedKeys = [];
        if (keyData['data'] is Map && keyData['data']['keys'] is List) {
          fetchedKeys = keyData['data']['keys'];
        } else if (keyData['data'] is List) {
          fetchedKeys = keyData['data'];
        }

        AuthService.saveApiKeysList(fetchedKeys);

        if (!mounted) return;
        setState(() {
          _keys = fetchedKeys;
          _isLoading = false;
          _syncSelectedIndex();
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load API keys.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading API keys: $e';
      });
    }
  }

  String _formatMaskedKey(String rawKey) {
    if (rawKey.isEmpty) return 'sk-••••••••••';
    if (rawKey.length <= 8) return rawKey;
    final suffix = rawKey.substring(rawKey.length - 4);
    return 'sk-••••••••••$suffix';
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final str = rawDate.toString().trim();
    if (str.isEmpty) return '';
    if (str.contains('T')) {
      return str.split('T')[0];
    }
    return str;
  }

  void _handleContinue() {
    if (_keys.isEmpty) return;

    final selectedItem = _keys[_selectedIndex];
    final selectedName = (selectedItem['name'] ?? 'API Key ${_selectedIndex + 1}').toString();
    final selectedKey = (selectedItem['value'] ?? selectedItem['api_key'] ?? '').toString();

    // Print selected API key to terminal
    debugPrint('========================================');
    debugPrint('[Selected API Key]');
    debugPrint('Name: $selectedName');
    debugPrint('Key:  $selectedKey');
    debugPrint('========================================');

    // 1. Save selected key globally in AuthService
    AuthService.saveApiKey(selectedKey);

    // 2. Navigate: if opened from drawer/navigation stack, pop back to chat; otherwise replace to ChatScreen
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    }
  }

  IconData _getIconForIndex(int index) {
    switch (index % 4) {
      case 0:
        return Icons.cloud_outlined;
      case 1:
        return Icons.person_outline_rounded;
      case 2:
        return Icons.storage_rounded;
      case 3:
      default:
        return Icons.code_rounded;
    }
  }

  Color _getIconBgColor(int index) {
    switch (index % 4) {
      case 0:
        return const Color(0xFFE0EDFF);
      case 1:
        return const Color(0xFFE2F9EE);
      case 2:
        return const Color(0xFFF3E8FF);
      case 3:
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color _getIconColor(int index) {
    switch (index % 4) {
      case 0:
        return const Color(0xFF2563EB);
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFF9333EA);
      case 3:
      default:
        return const Color(0xFFF97316);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              const Text(
                'Select API Key',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an API key to continue.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Each API key is used to access different services.\nPlease select the key you want to use.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E40AF),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. API Key List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFEF4444)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _fetchKeys,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _keys.isEmpty
                            ? const Center(
                                child: Text(
                                  'No API keys found.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                ),
                              )
                            : ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                                child: ListView.builder(
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _keys.length,
                                  itemBuilder: (context, index) {
                                    final item = _keys[index];
                                    final isSelected = index == _selectedIndex;

                    final name = (item['name'] ?? 'API Key ${index + 1}').toString();
                    final rawValue = (item['value'] ?? item['api_key'] ?? '').toString();
                    final maskedKey = _formatMaskedKey(rawValue);
                    final createdAt = _formatDate(item['created_at']);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF9FBFF) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.6 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Icon Box
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _getIconBgColor(index),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getIconForIndex(index),
                                color: _getIconColor(index),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Key info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    maskedKey,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  if (createdAt.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Created: $createdAt',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Custom Radio circle
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 6.5 : 1.8,
                                ),
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

              // 4. Continue Button
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
