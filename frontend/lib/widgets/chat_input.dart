import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;

  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                ),
                maxLines: null,
                onSubmitted: (_) => _handleSend(), // Support pressing Enter on keyboard
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add, color: Colors.black87),
                      iconSize: 20,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.tune, color: Colors.black87),
                      iconSize: 20,
                      onPressed: () {},
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.mic_none, color: Colors.black87),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                      iconSize: 20,
                      onPressed: _handleSend, // Call _handleSend when pressed
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

