import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';

/// Notifications Screen
/// Shows:
/// - Messages: "username messaged you" 
/// - System notifications (announcements, updates, etc.)
/// 
/// NO likes or matches - this is not a swipe-based app
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            _buildHeader(),
            
            // Tab Bar
            _buildTabBar(),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MessagesTab(),
                  _SystemTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: 'Messages'),
          Tab(text: 'System'),
        ],
      ),
    );
  }

  void _markAllAsRead() {
    HapticFeedback.lightImpact();
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    // Mark all notifications as read
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get()
        .then((snapshot) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      batch.commit();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All notifications marked as read'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ============================================================================
// MESSAGES TAB
// ============================================================================

class _MessagesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Center(child: Text('Please sign in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'message')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No messages yet',
            subtitle: 'When someone messages you, it will appear here',
          );
        }

        final notifications = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final data = notifications[index].data() as Map<String, dynamic>;
            return _MessageNotificationTile(
              notificationId: notifications[index].id,
              data: data,
              onTap: () => _handleMessageTap(context, ref, userId, notifications[index].id, data),
            );
          },
        );
      },
    );
  }

  void _handleMessageTap(BuildContext context, WidgetRef ref, String userId, String notificationId, Map<String, dynamic> data) {
    HapticFeedback.lightImpact();
    
    // Mark as read
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});

    // Navigate to chat
    final senderId = data['senderId'] as String?;
    if (senderId != null) {
      context.push('/chat/$senderId');
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SYSTEM TAB
// ============================================================================

class _SystemTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Center(child: Text('Please sign in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'system')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_outlined,
            title: 'No notifications',
            subtitle: 'System updates and announcements will appear here',
          );
        }

        final notifications = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final data = notifications[index].data() as Map<String, dynamic>;
            return _SystemNotificationTile(
              notificationId: notifications[index].id,
              data: data,
              onTap: () => _handleSystemTap(context, ref, userId, notifications[index].id, data),
            );
          },
        );
      },
    );
  }

  void _handleSystemTap(BuildContext context, WidgetRef ref, String userId, String notificationId, Map<String, dynamic> data) {
    HapticFeedback.lightImpact();
    
    // Mark as read
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});

    // Handle action if any
    final action = data['action'] as String?;
    final actionTarget = data['actionTarget'] as String?;
    
    if (action != null && actionTarget != null) {
      switch (action) {
        case 'navigate':
          context.push(actionTarget);
          break;
        case 'openUrl':
          final uri = Uri.tryParse(actionTarget);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          break;
      }
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NOTIFICATION TILES
// ============================================================================

class _MessageNotificationTile extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _MessageNotificationTile({
    required this.notificationId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = data['senderName'] as String? ?? 'Someone';
    final senderPhoto = data['senderPhoto'] as String?;
    final isRead = data['read'] as bool? ?? false;
    final createdAt = data['createdAt'] as Timestamp?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? AppColors.surface : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.border : AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
                image: senderPhoto != null
                    ? DecorationImage(
                        image: NetworkImage(senderPhoto),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: senderPhoto == null
                  ? Icon(Icons.person, color: AppColors.textMuted, size: 24)
                  : null,
            ),
            const SizedBox(width: 14),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: senderName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' messaged you'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Unread indicator
            if (!isRead)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            
            // Arrow
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return DateFormat('MMM d').format(date);
  }
}

class _SystemNotificationTile extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _SystemNotificationTile({
    required this.notificationId,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final isRead = data['read'] as bool? ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final iconName = data['icon'] as String? ?? 'info';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? AppColors.surface : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconColor(iconName).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(iconName),
                color: _getIconColor(iconName),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            
            // Unread indicator
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'info':
        return Icons.info_outline;
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'update':
        return Icons.system_update;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'premium':
        return Icons.workspace_premium;
      case 'profile':
        return Icons.person_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String name) {
    switch (name) {
      case 'success':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      case 'premium':
        return Colors.amber;
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return DateFormat('MMM d').format(date);
  }
}
