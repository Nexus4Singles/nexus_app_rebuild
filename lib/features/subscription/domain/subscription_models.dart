import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ============================================================================
// SUBSCRIPTION MODELS
// ============================================================================

/// Subscription tier/plan
enum SubscriptionTier {
  free('free', 'Free', 0),
  monthly('monthly_premium', 'Monthly Premium', 2999),
  quarterly('quarterly_premium', 'Quarterly Premium', 7999),
  yearly('yearly_premium', 'Yearly Premium', 24999);

  final String id;
  final String displayName;
  final int priceNGN;

  const SubscriptionTier(this.id, this.displayName, this.priceNGN);

  static SubscriptionTier fromId(String id) {
    return SubscriptionTier.values.firstWhere(
      (tier) => tier.id == id,
      orElse: () => SubscriptionTier.free,
    );
  }
}

/// User's active subscription details
class SubscriptionStatus extends Equatable {
  final bool isActive;
  final SubscriptionTier tier;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final bool autoRenew;
  final String? revenueCatCustomerId;
  final String? revenueCatSubscriptionId;

  const SubscriptionStatus({
    required this.isActive,
    required this.tier,
    this.startDate,
    this.expiryDate,
    this.autoRenew = true,
    this.revenueCatCustomerId,
    this.revenueCatSubscriptionId,
  });

  factory SubscriptionStatus.free() {
    return const SubscriptionStatus(
      isActive: false,
      tier: SubscriptionTier.free,
    );
  }

  factory SubscriptionStatus.fromFirestore(Map<String, dynamic> data) {
    final tierId = data['tier'] as String? ?? 'free';
    final tier = SubscriptionTier.fromId(tierId);

    DateTime? startDate;
    if (data['startDate'] != null) {
      if (data['startDate'] is Timestamp) {
        startDate = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is String) {
        startDate = DateTime.tryParse(data['startDate']);
      }
    }

    DateTime? expiryDate;
    if (data['expiryDate'] != null) {
      if (data['expiryDate'] is Timestamp) {
        expiryDate = (data['expiryDate'] as Timestamp).toDate();
      } else if (data['expiryDate'] is String) {
        expiryDate = DateTime.tryParse(data['expiryDate']);
      }
    }

    return SubscriptionStatus(
      isActive: data['isActive'] as bool? ?? false,
      tier: tier,
      startDate: startDate,
      expiryDate: expiryDate,
      autoRenew: data['autoRenew'] as bool? ?? true,
      revenueCatCustomerId: data['revenueCatCustomerId'] as String?,
      revenueCatSubscriptionId: data['revenueCatSubscriptionId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'isActive': isActive,
      'tier': tier.id,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'autoRenew': autoRenew,
      if (revenueCatCustomerId != null)
        'revenueCatCustomerId': revenueCatCustomerId,
      if (revenueCatSubscriptionId != null)
        'revenueCatSubscriptionId': revenueCatSubscriptionId,
    };
  }

  bool get isExpired {
    if (!isActive || expiryDate == null) return true;
    return DateTime.now().isAfter(expiryDate!);
  }

  int get daysUntilExpiry {
    if (expiryDate == null) return 0;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  @override
  List<Object?> get props => [
    isActive,
    tier,
    startDate,
    expiryDate,
    autoRenew,
    revenueCatCustomerId,
    revenueCatSubscriptionId,
  ];
}

/// Purchased journey/course
class PurchasedJourney extends Equatable {
  final String journeyId;
  final String journeyTitle;
  final DateTime purchaseDate;
  final double pricePaid;
  final String currency;
  final String? revenueCatTransactionId;
  final bool isActive;

  const PurchasedJourney({
    required this.journeyId,
    required this.journeyTitle,
    required this.purchaseDate,
    required this.pricePaid,
    this.currency = 'NGN',
    this.revenueCatTransactionId,
    this.isActive = true,
  });

  factory PurchasedJourney.fromFirestore(Map<String, dynamic> data) {
    DateTime purchaseDate;
    if (data['purchaseDate'] is Timestamp) {
      purchaseDate = (data['purchaseDate'] as Timestamp).toDate();
    } else if (data['purchaseDate'] is String) {
      purchaseDate = DateTime.parse(data['purchaseDate']);
    } else {
      purchaseDate = DateTime.now();
    }

    return PurchasedJourney(
      journeyId: data['journeyId'] as String? ?? '',
      journeyTitle: data['journeyTitle'] as String? ?? 'Unknown Journey',
      purchaseDate: purchaseDate,
      pricePaid: (data['pricePaid'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'NGN',
      revenueCatTransactionId: data['revenueCatTransactionId'] as String?,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'journeyId': journeyId,
      'journeyTitle': journeyTitle,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'pricePaid': pricePaid,
      'currency': currency,
      if (revenueCatTransactionId != null)
        'revenueCatTransactionId': revenueCatTransactionId,
      'isActive': isActive,
    };
  }

  @override
  List<Object?> get props => [
    journeyId,
    journeyTitle,
    purchaseDate,
    pricePaid,
    currency,
    revenueCatTransactionId,
    isActive,
  ];
}

/// Premium features available to subscribers
class PremiumFeatures {
  /// Unlimited chat conversations (free users limited to 3)
  static const String unlimitedMessaging = 'unlimited_messaging';

  /// View compatibility data on user profiles
  static const String viewCompatibilityData = 'view_compatibility_data';

  /// View contact information on user profiles
  static const String viewContactInfo = 'view_contact_info';

  /// All premium features
  static const List<PremiumFeature> allFeatures = [
    PremiumFeature(
      id: unlimitedMessaging,
      title: 'Unlimited Messaging',
      description: 'Chat with unlimited users in the dating section',
      icon: 'chat_bubble_outline',
    ),
    PremiumFeature(
      id: viewCompatibilityData,
      title: 'Access Compatibility Data',
      description: 'View detailed compatibility insights for potential matches',
      icon: 'favorite',
    ),
    PremiumFeature(
      id: viewContactInfo,
      title: 'View Contact Information',
      description: 'Access phone numbers and social media handles',
      icon: 'contact_page',
    ),
  ];
}

/// Individual premium feature
class PremiumFeature extends Equatable {
  final String id;
  final String title;
  final String description;
  final String icon;

  const PremiumFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  List<Object?> get props => [id, title, description, icon];
}
