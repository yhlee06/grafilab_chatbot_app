import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../screens/select_api_key_screen.dart';
import '../services/auth_service.dart';

class ChatDrawer extends StatefulWidget {
  final VoidCallback? onNewChat;
  final Function(String conversationId, String? modelSlug)? onSelectConversation;
  final String? currentConversationId;

  const ChatDrawer({
    super.key,
    this.onNewChat,
    this.onSelectConversation,
    this.currentConversationId,
  });

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final apiKey = (AuthService.selectedApiKey != null && AuthService.selectedApiKey!.isNotEmpty)
          ? AuthService.selectedApiKey!
          : (AuthService.token ?? '');
      final authHeader = apiKey.startsWith('Bearer ') ? apiKey : 'Bearer $apiKey';

      final response = await http.get(
        Uri.parse(ApiConfig.conversationsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _conversations = data['conversations'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      final apiKey = (AuthService.selectedApiKey != null && AuthService.selectedApiKey!.isNotEmpty)
          ? AuthService.selectedApiKey!
          : (AuthService.token ?? '');
      final authHeader = apiKey.startsWith('Bearer ') ? apiKey : 'Bearer $apiKey';

      await http.delete(
        Uri.parse(ApiConfig.deleteConversationEndpoint(id)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
      );

      if (mounted) {
        setState(() {
          _conversations.removeWhere((c) => c['id'] == id);
        });
      }

      if (widget.currentConversationId == id) {
        widget.onNewChat?.call();
      }
    } catch (_) {
      // Ignore network deletion errors gracefully
    }
  }

  String _formatTimestamp(String? timestampStr) {
    if (timestampStr == null || timestampStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestampStr).toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final yesterday = now.subtract(const Duration(days: 1));
      final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      if (isToday) {
        return 'Today $hour:$minute';
      } else if (isYesterday) {
        return 'Yesterday $hour:$minute';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final monthStr = months[dt.month - 1];
        return '$monthStr ${dt.day}, $hour:$minute';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.78;
    final bool isNewChatActive = widget.currentConversationId == null;

    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7FAFD),
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF2F7FE),
              Color(0xFFF9FBFF),
              Color(0xFFEDF4FE),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header: Logo + Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5B96FD), Color(0xFF2563EB)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x332563EB),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Chat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chat with AI, get more done',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Primary Button: New Chat (when active)
              if (isNewChatActive) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNewChat?.call();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F83F5), Color(0xFF2C6EF5)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x402563EB),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'New Chat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 3. Navigation Group: New Chat (when inactive) & API Key
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    if (!isNewChatActive) ...[
                      _buildNavItem(
                        icon: Icons.add,
                        iconBg: const Color(0xFFE2EDFE),
                        iconColor: const Color(0xFF2563EB),
                        title: 'New Chat',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNewChat?.call();
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                    _buildNavItem(
                      icon: Icons.vpn_key_rounded,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF9333EA),
                      title: 'API Key',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SelectApiKeyScreen(
                              apiKeys: AuthService.cachedApiKeys,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Section: Recent Chats Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    const Text(
                      'Recent Chats',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      color: Colors.grey.shade400,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: _fetchConversations,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 5. Scrollable Recent Chats List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      )
                    : _conversations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 36,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No recent chats',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade400,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final item = _conversations[index];
                              final String id = item['id'].toString();
                              final String title = item['title']?.toString() ?? 'New Chat';
                              final String time = _formatTimestamp(item['updated_at']?.toString());
                              final String? modelSlug = item['model_slug']?.toString();
                              final bool isSelected = widget.currentConversationId == id;

                              return _buildRecentItem(
                                icon: Icons.chat_bubble_outline_rounded,
                                iconBg: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2EDFE),
                                iconColor: isSelected ? Colors.white : const Color(0xFF2563EB),
                                title: title,
                                time: time,
                                isSelected: isSelected,
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onSelectConversation?.call(id, modelSlug);
                                },
                                onDelete: () => _deleteConversation(id),
                              );
                            },
                          ),
              ),

              // 6. Settings Card Button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF2FD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: Color(0xFF475569),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF94A3B8),
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 7. Decorative Footer Illustration
              SizedBox(
                height: 90,
                child: CustomPaint(
                  painter: _FooterIllustrationPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildNavItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFCBD5E1),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String time,
    required VoidCallback onTap,
    required VoidCallback onDelete,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                color: const Color(0xFF94A3B8),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Painter for wavy soft hills and floating leaves with text
class _FooterIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Back hill
    final hillPaint1 = Paint()
      ..color = const Color(0xFFDEEBFC)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.65);
    path1.quadraticBezierTo(size.width * 0.45, size.height * 0.25, size.width, size.height * 0.55);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, hillPaint1);

    // 2. Front hill
    final hillPaint2 = Paint()
      ..color = const Color(0xFFD3E4FC)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.82);
    path2.quadraticBezierTo(size.width * 0.35, size.height * 0.50, size.width, size.height * 0.70);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, hillPaint2);

    // 3. Two cute soft blue leaves
    final leafPaint = Paint()
      ..color = const Color(0xFF86B3F9)
      ..style = PaintingStyle.fill;

    // Leaf 1
    final leaf1 = Path();
    leaf1.moveTo(35, size.height * 0.52);
    leaf1.quadraticBezierTo(30, size.height * 0.30, 42, size.height * 0.22);
    leaf1.quadraticBezierTo(48, size.height * 0.38, 35, size.height * 0.52);
    canvas.drawPath(leaf1, leafPaint);

    // Leaf 2
    final leaf2 = Path();
    leaf2.moveTo(42, size.height * 0.52);
    leaf2.quadraticBezierTo(56, size.height * 0.36, 68, size.height * 0.38);
    leaf2.quadraticBezierTo(56, size.height * 0.52, 42, size.height * 0.52);
    canvas.drawPath(leaf2, leafPaint);

    // 4. Elegant text: "Better questions\nbrighter answers"
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Better questions\n  brighter answers',
        style: TextStyle(
          fontFamily: 'cursive',
          fontStyle: FontStyle.italic,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B9DE8),
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    canvas.save();
    canvas.translate(size.width * 0.34, size.height * 0.18);
    canvas.rotate(-0.06);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
