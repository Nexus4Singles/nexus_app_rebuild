import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

/// Help Center Screen - Premium Design with FAQs and Support
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help Center',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find answers and get support',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search for help...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: Icon(Icons.clear, color: AppColors.textMuted),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.email_outlined,
                        label: 'Email Us',
                        onTap: () => _launchEmail(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Live Chat',
                        onTap: () => _showComingSoon(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.bug_report_outlined,
                        label: 'Report Bug',
                        onTap: () => _showBugReport(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // FAQ Categories
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Account & Profile
                _buildFaqCategory(
                  'Account & Profile',
                  Icons.person_outline,
                  [
                    _FaqItem(
                      'How do I edit my profile?',
                      'Go to your Profile tab, tap the Edit button. You can update your photos, bio, and preferences from there.',
                    ),
                    _FaqItem(
                      'Can I change my audio recordings?',
                      'Audio recordings cannot be changed after profile creation to maintain authenticity. This ensures genuine connections.',
                    ),
                    _FaqItem(
                      'How do I delete my account?',
                      'Go to Settings > Account > Delete Account. Your data will be permanently removed within 30 days.',
                    ),
                    _FaqItem(
                      'Why was my photo rejected?',
                      'Photos must clearly show your face. Group photos, celebrities, or inappropriate content will be rejected.',
                    ),
                  ],
                ),

                // Matching & Connections
                _buildFaqCategory(
                  'Matching & Connections',
                  Icons.favorite_border,
                  [
                    _FaqItem(
                      'How does matching work?',
                      'Nexus uses your compatibility quiz results, preferences, and values to suggest compatible Christian singles.',
                    ),
                    _FaqItem(
                      'Why am I not getting matches?',
                      'Ensure your profile is complete with quality photos and authentic audio responses. Also check your filter settings.',
                    ),
                    _FaqItem(
                      'How do I unmatch with someone?',
                      'Go to your chat with them, tap the menu icon, and select "Unmatch". This will remove the connection.',
                    ),
                  ],
                ),

                // Subscription & Billing
                _buildFaqCategory(
                  'Subscription & Billing',
                  Icons.credit_card_outlined,
                  [
                    _FaqItem(
                      'What are the subscription plans?',
                      'We offer monthly, quarterly, and annual plans with different features. View plans in Settings > Subscription.',
                    ),
                    _FaqItem(
                      'How do I cancel my subscription?',
                      'You can cancel anytime in your device\'s app store settings. Your premium features remain until the period ends.',
                    ),
                    _FaqItem(
                      'Can I get a refund?',
                      'Refunds are handled through the App Store or Play Store based on their policies. Contact us if you have issues.',
                    ),
                  ],
                ),

                // Safety & Privacy
                _buildFaqCategory(
                  'Safety & Privacy',
                  Icons.shield_outlined,
                  [
                    _FaqItem(
                      'How do I report a user?',
                      'Tap the menu on their profile and select "Report". Our team reviews all reports within 24 hours.',
                    ),
                    _FaqItem(
                      'How do I block someone?',
                      'Go to their profile, tap the menu icon, and select "Block". They won\'t be able to see you or contact you.',
                    ),
                    _FaqItem(
                      'Is my data secure?',
                      'Yes, we use industry-standard encryption and security measures. Read our Privacy Policy for details.',
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Still need help?
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primarySoft,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.help_center, color: AppColors.primary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Still need help?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Our support team is here to help you',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _launchEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Contact Support',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCategory(String title, IconData icon, List<_FaqItem> items) {
    // Filter items based on search
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((item) =>
            item.question.toLowerCase().contains(_searchQuery) ||
            item.answer.toLowerCase().contains(_searchQuery)).toList();

    if (_searchQuery.isNotEmpty && filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          children: filteredItems.map((item) => _buildFaqItem(item)).toList(),
        ),
      ),
    );
  }

  Widget _buildFaqItem(_FaqItem item) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            item.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                item.answer,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@nexusapp.com',
      queryParameters: {
        'subject': 'Nexus App Support',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app')),
        );
      }
    }
  }

  void _showComingSoon() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Live chat coming soon!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBugReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BugReportSheet(),
    );
  }
}

// =============================================================================
// QUICK ACTION CARD
// =============================================================================

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FAQ ITEM MODEL
// =============================================================================

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}

// =============================================================================
// BUG REPORT SHEET
// =============================================================================

class _BugReportSheet extends StatefulWidget {
  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'General';

  final _categories = ['General', 'Login/Signup', 'Profile', 'Matching', 'Chat', 'Payments', 'Other'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Report a Bug',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us improve by reporting issues you encounter',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Category dropdown
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                borderRadius: BorderRadius.circular(12),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value!),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe the issue in detail...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Bug report submitted. Thank you!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
