import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/model_selection_sheet.dart';
import '../widgets/model_selector.dart';
import '../widgets/chat_input.dart';
import '../widgets/attachment_sheet.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../models/ai_model.dart';
import '../widgets/chat_drawer.dart';
import 'login_screen.dart';

class ChatMessageData {
  final String text;
  final bool isUser;
  final AttachedFileData? attachment;
  final String? imageUrl;
  final String type; // 'text' or 'image'

  ChatMessageData(
    this.text,
    this.isUser, {
    this.attachment,
    this.imageUrl,
    this.type = 'text',
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedModel = 'ILMU Mini v3.3';
  String _selectedModelSlug = 'ilmu/ilmu-mini-v3.3';
  final List<ChatMessageData> _messages = [];
  bool _isWaitingForReply = false;

  void _handleNewChat() {
    setState(() {
      _messages.clear();
      _isWaitingForReply = false;
    });
  }

  void _openModelSelector() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ModelSelectionSheet(
          initialSelection: _selectedModel,
        );
      },
    );

    if (result != null) {
      final String modelName = (result is AiModel) ? result.name : result.toString();
      final String modelSlug = (result is AiModel && result.modelUrl != null && result.modelUrl!.isNotEmpty)
          ? result.modelUrl!
          : modelName;

      final isDifferentModel = modelName != _selectedModel || modelSlug != _selectedModelSlug;

      setState(() {
        _selectedModel = modelName;
        _selectedModelSlug = modelSlug;

        // Auto-clear prior chat history to avoid cross-model persona contamination
        if (isDifferentModel) {
          _messages.clear();
          _isWaitingForReply = false;
        }
      });
    }
  }

  Future<void> _sendMessage(String text, AttachedFileData? attachment) async {
    // 1. Snapshot prior conversation history for multi-turn context
    final List<Map<String, dynamic>> messagesPayload = [];
    for (final m in _messages) {
      messagesPayload.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      });
    }

    // 2. Add current user message with attachment or text
    if (attachment != null && attachment.base64DataUri.isNotEmpty) {
      messagesPayload.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': text},
          {
            'type': 'image_url',
            'image_url': {'url': attachment.base64DataUri},
          },
        ],
      });
    } else {
      messagesPayload.add({
        'role': 'user',
        'content': text,
      });
    }

    // 3. Add user message with attachment to UI
    setState(() {
      _messages.add(ChatMessageData(text, true, attachment: attachment));
      _isWaitingForReply = true;
    });

    // 4. Call Grafilab official chat completions API directly
    try {
      final apiKey = (AuthService.selectedApiKey != null && AuthService.selectedApiKey!.isNotEmpty)
          ? AuthService.selectedApiKey!
          : (AuthService.token ?? '');

      if (apiKey.isEmpty) {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessageData("Error: No API key or token found. Please log in again.", false));
          _isWaitingForReply = false;
        });
        return;
      }

      final authHeader = apiKey.startsWith('Bearer ') ? apiKey : 'Bearer $apiKey';

      final response = await http.post(
        Uri.parse(ApiConfig.chatEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: json.encode({
          'model': _selectedModelSlug,
          'message': text,
          'history': messagesPayload,
          'image_url': (attachment != null && attachment.isImage) ? attachment.base64DataUri : null,
          'file_url': (attachment != null && !attachment.isImage) ? attachment.base64DataUri : null,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final msgType = (data['type'] ?? 'text').toString();

        if (msgType == 'image' && data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
          final imageUrl = data['image_url'].toString();
          final prompt = (data['prompt'] ?? data['reply'] ?? text).toString();

          if (!mounted) return;
          setState(() {
            _messages.add(ChatMessageData(
              prompt,
              false,
              imageUrl: imageUrl,
              type: 'image',
            ));
            _isWaitingForReply = false;
          });
        } else {
          String reply = (data['content'] ?? data['reply'] ?? '').toString().trim();
          if (reply.isEmpty) {
            reply = 'No response content returned from AI model.';
          }

          if (!mounted) return;
          setState(() {
            _messages.add(ChatMessageData(reply, false, type: 'text'));
            _isWaitingForReply = false;
          });
        }
      } else {
        if (!mounted) return;
        String errorDetail = 'Server returned ${response.statusCode}';
        try {
          final errData = json.decode(utf8.decode(response.bodyBytes));
          if (errData['reply'] != null) {
            errorDetail = errData['reply'].toString();
          } else if (errData['error'] != null && errData['error']['message'] != null) {
            errorDetail = errData['error']['message'].toString();
          } else if (errData['detail'] != null) {
            errorDetail = errData['detail'].toString();
          }
        } catch (_) {}

        debugPrint('\n================ [AI ERROR] ================');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Error: $errorDetail');
        debugPrint('============================================\n');

        setState(() {
          _messages.add(ChatMessageData("Error: $errorDetail", false));
          _isWaitingForReply = false;
        });
      }
    } catch (e) {
      debugPrint('\n==================================================');
      debugPrint('[FLUTTER CHAT COMPLETION ERROR]: $e');
      debugPrint('==================================================\n');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageData("Error connecting to server: $e", false));
        _isWaitingForReply = false;
      });
    }
  }

  void _handleLogout() {
    AuthService.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: ChatDrawer(
        onNewChat: _handleNewChat,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Menu Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.black87),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                    ),
                  ),
                  // Model Selector
                  ModelSelector(
                    selectedModel: _selectedModel,
                    onTap: _openModelSelector,
                  ),
                  // Logout Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.black87),
                      onPressed: _handleLogout,
                      tooltip: 'Log Out',
                    ),
                  ),
                ],
              ),
            ),

            // Chat Area
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'What can I help with?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    )
                  : ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(overscroll: false),
                      child: ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return Align(
                            alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: msg.isUser ? Colors.grey.shade100 : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: msg.isUser
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        // Display attached image / file in chat bubble
                                        if (msg.attachment != null) ...[
                                          if (msg.attachment!.isImage)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(
                                                  msg.attachment!.bytes,
                                                  width: 180,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.description, size: 20, color: Colors.blueAccent),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        msg.attachment!.name,
                                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                        Text(
                                          msg.text,
                                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                                        ),
                                      ],
                                    )
                                  : msg.type == 'image' && msg.imageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(
                                            msg.imageUrl!,
                                            width: MediaQuery.of(context).size.width * 0.75,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Container(
                                                width: MediaQuery.of(context).size.width * 0.75,
                                                height: 240,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                            loadingProgress.expectedTotalBytes!
                                                        : null,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: MediaQuery.of(context).size.width * 0.75,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Failed to load generated image.',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : MarkdownBody(
                                          data: msg.text,
                                          styleSheet: MarkdownStyleSheet(
                                            p: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                                            strong: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                            h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                                            h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87),
                                            h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                                            listBullet: const TextStyle(fontSize: 16, color: Colors.black87),
                                          ),
                                        ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // Loading indicator while waiting
            if (_isWaitingForReply)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: CircularProgressIndicator(color: Colors.black),
              ),

            // Bottom Input Area
            ChatInput(onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}
