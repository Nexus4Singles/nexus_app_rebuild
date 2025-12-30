import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../services/subscription_service.dart';

/// Modal shown when user needs premium to send messages
class PremiumPaywallModal extends ConsumerWidget {
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;

  const PremiumPaywallModal({
    super.key,
    this.onUpgrade,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumPaywallModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Premium icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.orange.shade400,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Upgrade to Premium',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'You\'ve used your free message. Upgrade to Premium for unlimited messaging and more features!',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Features list
              _buildFeatureRow(Icons.message, 'Unlimited messaging'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.favorite, 'See who likes you'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.bolt, 'Profile boost'),
              const SizedBox(height: 12),
              _buildFeatureRow(Icons.filter_list, 'Advanced filters'),
              const SizedBox(height: 32),

              // Upgrade button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onUpgrade != null) {
                      onUpgrade!();
                    } else {
                      context.push('/subscription');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Upgrade Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Maybe later
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDismiss?.call();
                },
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Icon(Icons.check, color: AppColors.signalStrong, size: 20),
      ],
    );
  }
}

/// Free chat alert shown before using free message
class FreeChatAlert extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const FreeChatAlert({
    super.key,
    required this.onContinue,
    required this.onCancel,
  });

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FreeChatAlert(
        onContinue: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          const Text('Free Message'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This is your one free conversation! After this, you\'ll need Premium to start new chats.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Make it count! Write something meaningful.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
