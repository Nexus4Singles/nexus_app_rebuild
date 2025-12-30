import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Premium Chat Detail Screen
/// Modern messaging interface
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatDetailScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Sample messages for UI preview
  final List<_Message> _messages = [
    _Message(
      id: '1',
      text: 'Hey! I saw your profile and loved your perspective on faith.',
      isMe: false,
      time: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    _Message(
      id: '2',
      text: 'Thank you! I really appreciate that. What drew your attention?',
      isMe: true,
      time: DateTime.now().subtract(const Duration(minutes: 28)),
    ),
    _Message(
      id: '3',
      text: 'The way you talked about family values and your vision for marriage. It resonated with me.',
      isMe: false,
      time: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    _Message(
      id: '4',
      text: 'That means a lot! I believe having a shared foundation is so important.',
      isMe: true,
      time: DateTime.now().subtract(const Duration(minutes: 20)),
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Messages
            Expanded(
              child: _buildMessagesList(),
            ),

            // Input
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceLight,
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Navigate to profile
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sarah Johnson',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Online now',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.phone_outlined, color: AppColors.primary),
          ),
          IconButton(
            onPressed: () => _showOptionsSheet(context),
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final showDate = index == _messages.length - 1 ||
            !_isSameDay(
              message.time,
              _messages[_messages.length - index].time,
            );

        return Column(
          children: [
            if (showDate) _buildDateDivider(message.time),
            _MessageBubble(message: message),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Attachment button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.add, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _messageController.text.trim().isEmpty
                  ? AppColors.surfaceLight
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _messageController.text.trim().isEmpty
                  ? null
                  : _sendMessage,
              icon: Icon(
                Icons.send,
                size: 20,
                color: _messageController.text.trim().isEmpty
                    ? AppColors.textMuted
                    : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    
    setState(() {
      _messages.add(_Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isMe: true,
        time: DateTime.now(),
      ));
    });

    _messageController.clear();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _OptionItem(
              icon: Icons.person_outline,
              title: 'View Profile',
              onTap: () {
                Navigator.pop(context);
                context.push('/profile/user_id');
              },
            ),
            _OptionItem(
              icon: Icons.notifications_off_outlined,
              title: 'Mute Notifications',
              onTap: () => Navigator.pop(context),
            ),
            _OptionItem(
              icon: Icons.block_outlined,
              title: 'Block User',
              color: AppColors.warning,
              onTap: () => Navigator.pop(context),
            ),
            _OptionItem(
              icon: Icons.flag_outlined,
              title: 'Report',
              color: AppColors.error,
              onTap: () => Navigator.pop(context),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================================
// MESSAGE MODEL
// ============================================================================

class _Message {
  final String id;
  final String text;
  final bool isMe;
  final DateTime time;

  _Message({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final _Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: message.isMe ? 60 : 0,
          right: message.isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isMe ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(message.isMe ? 20 : 6),
            bottomRight: Radius.circular(message.isMe ? 6 : 20),
          ),
          border: message.isMe ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: message.isMe ? Colors.white : AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.time),
                  style: TextStyle(
                    fontSize: 11,
                    color: message.isMe
                        ? Colors.white.withOpacity(0.7)
                        : AppColors.textMuted,
                  ),
                ),
                if (message.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ============================================================================
// OPTION ITEM
// ============================================================================

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _OptionItem({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: itemColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
