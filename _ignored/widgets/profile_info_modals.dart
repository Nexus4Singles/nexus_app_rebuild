import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/models/user_model.dart';

// ============================================================================
// COMPATIBILITY DATA MODAL
// ============================================================================

/// Beautiful modal to display compatibility data with human-readable sentences
class CompatibilityDataModal extends StatelessWidget {
  final UserModel user;

  const CompatibilityDataModal({super.key, required this.user});

  /// Show the modal
  static Future<void> show(BuildContext context, UserModel user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompatibilityDataModal(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentences = _generateCompatibilitySentences(user);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.psychology,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compatibility Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Get to know ${user.displayName} better',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: sentences.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: sentences.map((sentence) {
                        return _CompatibilityItem(
                          sentence: sentence,
                          isLast: sentences.last == sentence,
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.help_outline,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            '${user.displayName} hasn\'t completed their compatibility quiz yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate human-readable sentences from compatibility data
  List<String> _generateCompatibilitySentences(UserModel user) {
    final sentences = <String>[];
    final data = user.compatibility;
    final name = user.displayName;
    final gender = user.gender?.toLowerCase() ?? 'male';
    
    // Pronouns based on gender
    final heSheCap = gender == 'female' ? 'She' : 'He';
    final hisHer = gender == 'female' ? 'her' : 'his';

    if (data == null) return sentences;

    // 1. Marital Status
    final maritalStatus = data['maritalStatus'] as String?;
    if (maritalStatus != null) {
      if (maritalStatus.toLowerCase().contains('never')) {
        sentences.add('$name has never been married');
      } else if (maritalStatus.toLowerCase().contains('divorced')) {
        sentences.add('$name is divorced');
      } else if (maritalStatus.toLowerCase().contains('widow')) {
        sentences.add('$name is a ${gender == 'female' ? 'widow' : 'widower'}');
      }
    }

    // 2. Kids
    final haveKids = data['haveKids'] as String?;
    if (haveKids != null) {
      if (haveKids.toLowerCase() == 'yes') {
        sentences.add('$name has kids');
      } else {
        sentences.add('$name doesn\'t have kids');
      }
    }

    // 3. Genotype
    final genotype = data['genotype'] as String?;
    if (genotype != null) {
      sentences.add('$name has an $genotype Genotype');
    }

    // 4. Personality Type
    final personality = data['personalityType'] as String?;
    if (personality != null) {
      sentences.add('$name is ${_getArticle(personality)} $personality');
    }

    // 5. Regular Income
    final hasIncome = data['regularSourceOfIncome'] as String?;
    if (hasIncome != null) {
      if (hasIncome.toLowerCase() == 'yes') {
        sentences.add('$name has a regular source of income');
      } else {
        sentences.add('$name doesn\'t have a regular source of income yet');
      }
    }

    // 6. Marry someone not financially stable
    final marrySomeoneNotFS = data['marrySomeoneNotFS'] as String?;
    if (marrySomeoneNotFS != null) {
      if (marrySomeoneNotFS.toLowerCase().contains('yes')) {
        sentences.add('$name can date or marry someone who is not yet financially stable');
      } else {
        sentences.add('$name prefers to date someone who is financially stable');
      }
    }

    // 7. Long Distance
    final longDistance = data['longDistance'] as String?;
    if (longDistance != null) {
      if (longDistance.toLowerCase() == 'yes') {
        sentences.add('$name is open to a long distance relationship');
      } else {
        sentences.add('$name prefers not to have a long distance relationship');
      }
    }

    // 8. Mental Readiness (if available)
    // sentences.add('$name is mentally ready for marriage');

    // 9. Cohabiting
    final cohabiting = data['believeInCohabiting'] as String?;
    if (cohabiting != null) {
      if (cohabiting.toLowerCase().contains('yes')) {
        sentences.add('$name believes in cohabiting before marriage');
      } else {
        sentences.add('$name doesn\'t believe in cohabiting before marriage');
      }
    }

    // 10. Speaking in Tongues
    final tongues = data['shouldChristianSpeakInTongue'] as String?;
    if (tongues != null) {
      if (tongues.toLowerCase() == 'yes') {
        sentences.add('$name believes every Christian should desire to speak in tongues');
      } else if (tongues.toLowerCase() == 'no') {
        sentences.add('$name doesn\'t think speaking in tongues is necessary');
      } else {
        sentences.add('$name is not sure about the gift of tongues');
      }
    }

    // 11. Tithing
    final tithing = data['believeInTithing'] as String?;
    if (tithing != null) {
      if (tithing.toLowerCase() == 'yes') {
        sentences.add('$name believes in tithing');
      } else {
        sentences.add('$name doesn\'t believe in tithing');
      }
    }

    return sentences;
  }

  String _getArticle(String word) {
    final firstLetter = word.toLowerCase()[0];
    return ['a', 'e', 'i', 'o', 'u'].contains(firstLetter) ? 'an' : 'a';
  }
}

class _CompatibilityItem extends StatelessWidget {
  final String sentence;
  final bool isLast;

  const _CompatibilityItem({
    required this.sentence,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              sentence,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CONTACT INFO MODAL
// ============================================================================

/// Modal to display user's contact information
class ContactInfoModal extends StatelessWidget {
  final UserModel user;

  const ContactInfoModal({super.key, required this.user});

  /// Show the modal
  static Future<void> show(BuildContext context, UserModel user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContactInfoModal(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _getAvailableContacts(user);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.contact_page,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Info',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Connect with ${user.displayName}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          contacts.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: contacts.map((contact) {
                      return _ContactItem(
                        contact: contact,
                        isLast: contacts.last == contact,
                      );
                    }).toList(),
                  ),
                ),

          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.contact_mail_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            '${user.displayName} hasn\'t added any contact info yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Get all available contact information
  List<_ContactData> _getAvailableContacts(UserModel user) {
    final contacts = <_ContactData>[];

    if (user.instagramUsername != null && user.instagramUsername!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.instagram,
        value: user.instagramUsername!,
        displayValue: '@${user.instagramUsername!.replaceAll('@', '')}',
      ));
    }

    if (user.twitterUsername != null && user.twitterUsername!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.twitter,
        value: user.twitterUsername!,
        displayValue: '@${user.twitterUsername!.replaceAll('@', '')}',
      ));
    }

    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.whatsapp,
        value: user.phoneNumber!,
        displayValue: user.phoneNumber!,
      ));
    }

    if (user.facebookUsername != null && user.facebookUsername!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.facebook,
        value: user.facebookUsername!,
        displayValue: user.facebookUsername!,
      ));
    }

    if (user.telegramUsername != null && user.telegramUsername!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.telegram,
        value: user.telegramUsername!,
        displayValue: '@${user.telegramUsername!.replaceAll('@', '')}',
      ));
    }

    if (user.snapchatUsername != null && user.snapchatUsername!.isNotEmpty) {
      contacts.add(_ContactData(
        type: ContactType.snapchat,
        value: user.snapchatUsername!,
        displayValue: user.snapchatUsername!,
      ));
    }

    return contacts;
  }
}

enum ContactType {
  instagram,
  twitter,
  whatsapp,
  facebook,
  telegram,
  snapchat,
}

class _ContactData {
  final ContactType type;
  final String value;
  final String displayValue;

  _ContactData({
    required this.type,
    required this.value,
    required this.displayValue,
  });

  String get label {
    switch (type) {
      case ContactType.instagram:
        return 'Instagram';
      case ContactType.twitter:
        return 'Twitter / X';
      case ContactType.whatsapp:
        return 'WhatsApp';
      case ContactType.facebook:
        return 'Facebook';
      case ContactType.telegram:
        return 'Telegram';
      case ContactType.snapchat:
        return 'Snapchat';
    }
  }

  IconData get icon {
    switch (type) {
      case ContactType.instagram:
        return Icons.camera_alt;
      case ContactType.twitter:
        return Icons.alternate_email;
      case ContactType.whatsapp:
        return Icons.phone;
      case ContactType.facebook:
        return Icons.facebook;
      case ContactType.telegram:
        return Icons.send;
      case ContactType.snapchat:
        return Icons.snapchat;
    }
  }

  Color get color {
    switch (type) {
      case ContactType.instagram:
        return const Color(0xFFE4405F);
      case ContactType.twitter:
        return const Color(0xFF1DA1F2);
      case ContactType.whatsapp:
        return const Color(0xFF25D366);
      case ContactType.facebook:
        return const Color(0xFF1877F2);
      case ContactType.telegram:
        return const Color(0xFF0088CC);
      case ContactType.snapchat:
        return const Color(0xFFFFFC00);
    }
  }

  String? get url {
    switch (type) {
      case ContactType.instagram:
        return 'https://instagram.com/${value.replaceAll('@', '')}';
      case ContactType.twitter:
        return 'https://twitter.com/${value.replaceAll('@', '')}';
      case ContactType.whatsapp:
        final cleanNumber = value.replaceAll(RegExp(r'[^\d+]'), '');
        return 'https://wa.me/$cleanNumber';
      case ContactType.facebook:
        return 'https://facebook.com/$value';
      case ContactType.telegram:
        return 'https://t.me/${value.replaceAll('@', '')}';
      case ContactType.snapchat:
        return 'https://snapchat.com/add/$value';
    }
  }
}

class _ContactItem extends StatelessWidget {
  final _ContactData contact;
  final bool isLast;

  const _ContactItem({
    required this.contact,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: contact.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            contact.icon,
            color: contact.color == const Color(0xFFFFFC00) 
                ? Colors.black 
                : contact.color,
          ),
        ),
        title: Text(
          contact.label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          contact.displayValue,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy button
            IconButton(
              onPressed: () => _copyToClipboard(context, contact.displayValue),
              icon: Icon(
                Icons.copy,
                color: AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Copy',
            ),
            // Open button
            IconButton(
              onPressed: () => _openLink(contact.url),
              icon: Icon(
                Icons.open_in_new,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Open',
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openLink(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ============================================================================
// ACTION BUTTONS
// ============================================================================

/// Button to view compatibility data
class ViewCompatibilityDataButton extends StatelessWidget {
  final UserModel user;

  const ViewCompatibilityDataButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      icon: Icons.psychology,
      label: 'Compatibility Data',
      color: AppColors.secondary,
      onTap: () => CompatibilityDataModal.show(context, user),
    );
  }
}

/// Button to view contact info
class ViewContactInfoButton extends StatelessWidget {
  final UserModel user;

  const ViewContactInfoButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      icon: Icons.contact_page,
      label: 'Contact Info',
      color: AppColors.primary,
      onTap: () => ContactInfoModal.show(context, user),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
