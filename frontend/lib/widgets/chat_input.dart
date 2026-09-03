import 'package:flutter/material.dart';
import 'attachment_sheet.dart';

class ChatInput extends StatefulWidget {
  final Function(String message, AttachedFileData? attachment) onSend;

  const ChatInput({super.key, required this.onSend});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  AttachedFileData? _attachment;

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty || _attachment != null) {
      widget.onSend(text.isEmpty ? 'Analyze this image/file' : text, _attachment);
      _controller.clear();
      setState(() {
        _attachment = null;
      });
    }
  }

  void _openAttachmentSheet() async {
    final result = await showModalBottomSheet<AttachedFileData>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const AttachmentSheet();
      },
    );

    if (result != null) {
      setState(() {
        _attachment = result;
      });
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment Preview Chip
            if (_attachment != null)
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 12.0, right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_attachment!.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            _attachment!.bytes,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        const Icon(Icons.description, size: 28, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _attachment!.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _attachment = null;
                          });
                        },
                        child: const Icon(Icons.close, size: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Text Input Field
            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 8.0),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                ),
                maxLines: null,
                onSubmitted: (_) => _handleSend(),
              ),
            ),

            // Bottom Buttons
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
                      onPressed: _openAttachmentSheet,
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
                      onPressed: _handleSend,
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
