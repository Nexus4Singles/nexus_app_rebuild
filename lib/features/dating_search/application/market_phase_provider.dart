import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

/// Market phase enumeration
enum MarketPhase { prelaunch, active, closed }

/// Market data model
class MarketData {
  final String country;
  final MarketPhase phase;
  final DateTime? launchDate;
  final int approvedProfileCount;
  final int maleCount;
  final int femaleCount;

  MarketData({
    required this.country,
    required this.phase,
    this.launchDate,
    required this.approvedProfileCount,
    required this.maleCount,
    required this.femaleCount,
  });

  /// Parse phase string to enum
  static MarketPhase _parsePhase(String? phase) {
    switch (phase?.toLowerCase()) {
      case 'active':
        return MarketPhase.active;
      case 'closed':
        return MarketPhase.closed;
      case 'prelaunch':
      default:
        return MarketPhase.prelaunch;
    }
  }
}

class UkMarketProfileCounts {
  final int total;
  final int male;
  final int female;

  const UkMarketProfileCounts({
    required this.total,
    required this.male,
    required this.female,
  });
}

UkMarketProfileCounts countVerifiedUkProfiles(
  Iterable<Map<String, dynamic>> profiles,
) {
  var male = 0;
  var female = 0;

  for (final profile in profiles) {
    final dating = profile['dating'] is Map
        ? Map<String, dynamic>.from(profile['dating'] as Map)
        : const <String, dynamic>{};
    final datingProfile = dating['profile'] is Map
        ? Map<String, dynamic>.from(dating['profile'] as Map)
        : const <String, dynamic>{};

    final verificationStatus = (dating['verificationStatus'] ??
            profile['verificationStatus'])
        ?.toString()
        .trim()
        .toLowerCase();
    final country = (profile['countryOfResidence'] ??
            profile['country'] ??
            dating['countryOfResidence'] ??
            datingProfile['country'])
        ?.toString()
        .trim()
        .toLowerCase();
    final gender = (dating['gender'] ??
            profile['gender'] ??
            datingProfile['gender'])
        ?.toString()
        .trim()
        .toLowerCase();

    if (verificationStatus != 'verified' ||
        (country != 'united kingdom' && country != 'uk')) {
      continue;
    }

    if (gender == 'male') {
      male++;
    } else if (gender == 'female') {
      female++;
    }
  }

  return UkMarketProfileCounts(
    total: male + female,
    male: male,
    female: female,
  );
}

const String ukLaunchBypassAdminEmail = 'nexus4singles@gmail.com';

bool shouldBypassUkLaunchGate(String? userEmail) {
  final normalizedEmail = userEmail?.trim().toLowerCase();
  return normalizedEmail == ukLaunchBypassAdminEmail;
}

/// Returns true only when the UK market launch date has passed.
///
/// This intentionally ignores the stored phase value when the launch date is
/// configured and still pending. If the launch date has not been reached, the
/// UK market stays on waitlist regardless of phase.
bool shouldShowProfilesForUkMarket(
  MarketData? market, {
  DateTime? nowUtc,
}) {
  final now = (nowUtc ?? DateTime.now()).toUtc();
  final launchDateUtc = market?.launchDate?.toUtc();
  return launchDateUtc != null && !launchDateUtc.isAfter(now);
}

/// Provider for market phase (real-time stream)
final marketPhaseProvider = StreamProvider.family<MarketData?, String>((
  ref,
  market,
) async* {
  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    yield null;
    return;
  }

  try {
    await for (final doc in fs.collection('markets').doc(market).snapshots()) {
      if (!doc.exists) {
        yield null;
        continue;
      }

      final data = doc.data() ?? {};
      final marketData = MarketData(
        country: data['country'] as String? ?? '',
        phase: MarketData._parsePhase(data['phase'] as String?),
        launchDate:
            data['launchDate'] != null
                ? (data['launchDate'] as Timestamp).toDate()
                : null,
        approvedProfileCount: (data['approvedProfileCount'] as int?) ?? 0,
        maleCount: (data['gender']?['male'] as int?) ?? 0,
        femaleCount: (data['gender']?['female'] as int?) ?? 0,
      );

      yield marketData;
    }
  } catch (e) {
    yield null;
  }
});

/// Convenience provider for UK market phase
final ukMarketPhaseProvider = StreamProvider<MarketData?>((ref) async* {
  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    print('[ukMarketPhaseProvider] ❌ Firestore instance is null');
    yield null;
    return;
  }

  try {
    await for (final doc in fs.collection('markets').doc('uk').snapshots()) {
      if (!doc.exists) {
        print('[ukMarketPhaseProvider] ⚠️ Market document does not exist');
        yield null;
        continue;
      }

      final data = doc.data() ?? {};
      final phaseStr = data['phase'] as String?;
      final parsedPhase = MarketData._parsePhase(phaseStr);

      print('[ukMarketPhaseProvider] 📊 UK Market Data:');
      print('  Raw phase value: $phaseStr');
      print('  Parsed phase: $parsedPhase');
      print('  Approved profiles: ${data['approvedProfileCount']}');
      print(
        '  Male: ${data['gender']?['male']}, Female: ${data['gender']?['female']}',
      );

      final marketData = MarketData(
        country: data['country'] as String? ?? '',
        phase: parsedPhase,
        launchDate:
            data['launchDate'] != null
                ? (data['launchDate'] as Timestamp).toDate()
                : null,
        approvedProfileCount: (data['approvedProfileCount'] as int?) ?? 0,
        maleCount: (data['gender']?['male'] as int?) ?? 0,
        femaleCount: (data['gender']?['female'] as int?) ?? 0,
      );

      yield marketData;
    }
  } catch (e) {
    print('[ukMarketPhaseProvider] ❌ Error: $e');
    yield null;
  }
});
