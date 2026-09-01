import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/model_selection_sheet.dart';
import '../widgets/model_selector.dart';
import '../widgets/chat_input.dart';

class ChatMessageData {
  final String text;
  final bool isUser;
  ChatMessageData(this.text, this.isUser);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _selectedModel = 'ILMU Mini v3.3'; // Set default to ILMU
  final List<ChatMessageData> _messages = [];
  bool _isWaitingForReply = false;

  void _openModelSelector() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ModelSelectionSheet(initialSelection: _selectedModel);
      },
    );

    if (result != null) {
      setState(() {
        _selectedModel = result;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    // 1. Add user message to UI
    setState(() {
      _messages.add(ChatMessageData(text, true));
      _isWaitingForReply = true;
    });

    // 2. Call FastAPI backend
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _selectedModel,
          'message': text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessageData(data['reply'], false));
          _isWaitingForReply = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add(ChatMessageData("Error: Server returned ${response.statusCode}", false));
          _isWaitingForReply = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageData("Error connecting to server: $e", false));
        _isWaitingForReply = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        onPressed: () {},
                      ),
                    ),
                  ),
                  // Model Selector
                  ModelSelector(
                    selectedModel: _selectedModel,
                    onTap: _openModelSelector,
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
                                  ? Text(
                                      msg.text,
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
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

