# Technical Implementation Guide: Nexus Dating Discovery System

## Overview

This guide details the technical architecture for implementing the world-class dating UX strategy. It covers database schema, API design, algorithm implementation, and frontend integration.

---

## 1. Database Schema Additions

### Collections & Documents

#### `users/{uid}/dating_preferences`
```json
{
  "uid": "user123",
  "relationship_goal": "marriage-minded",
  "timeline": "within_1_year",
  "pref_age_min": 21,
  "pref_age_max": 60,
  "pref_countries": ["Nigeria", "USA"],
  "pref_long_distance": "maybe",
  "pref_marital_status": "never_married",
  "pref_has_kids": "open",
  "pref_genotype": "any",
  
  // System fields
  "last_updated": "2026-02-01T10:30:00Z",
  "last_preferences_refined": "2026-02-01T10:30:00Z"
}
```

#### `users/{uid}/compatibility_quiz` (Existing, Enhanced)
```json
{
  "uid": "user123",
  "marital_status": "never_married",
  "have_kids": "no",
  "want_kids": "yes",
  "genotype": "AA",
  "personality_type": "ENFJ",  // NEW
  "regular_source_of_income": "yes",
  "marry_someone_not_fs": "no",
  "long_distance": "maybe",
  "believe_in_cohabiting": "no",
  "should_christian_speak_in_tongue": "yes",
  "believe_in_tithing": "yes",
  
  // NEW: Weights for algorithm
  "priority_dimensions": {
    "faith": 0.95,
    "life_stage": 0.80,
    "values": 0.90
  },
  
  "completed_at": "2026-01-15T14:22:00Z",
  "version": 2
}
```

#### `dating/daily_matches/{uid}` (NEW)
```json
{
  "uid": "user123",
  "date": "2026-02-01",
  "generated_at": "2026-02-01T00:00:00Z",
  "matches": [
    {
      "profile_uid": "profile_456",
      "compatibility_score": 97,
      "score_breakdown": {
        "core_values": 95,
        "lifestyle": 94,
        "life_stage": 102  // capped at 100
      },
      "match_reasons": [
        "Same faith commitment (Tithing believer)",
        "Compatible timeline",
        "Open to kids"
      ],
      "match_warnings": [
        "Different on: Long distance (she: Yes, you: No)"
      ],
      "viewed_at": "2026-02-01T08:15:00Z",
      "action": "saved",
      "action_at": "2026-02-01T08:20:00Z"
    }
  ],
  "total_profiles_available": 143,
  "algorithm_version": "v2.1"
}
```

#### `dating/interactions/{uid}` (NEW - User Behavior Tracking)
```json
{
  "uid": "user123",
  "date": "2026-02-01",
  "interactions": [
    {
      "profile_uid": "profile_456",
      "action": "view",
      "timestamp": "2026-02-01T08:00:00Z",
      "duration_sec": 25,
      "listened_audio": true,
      "viewed_photos": true,
      "photos_viewed_count": 2
    },
    {
      "profile_uid": "profile_456",
      "action": "save",
      "timestamp": "2026-02-01T08:20:00Z"
    },
    {
      "profile_uid": "profile_789",
      "action": "pass",
      "timestamp": "2026-02-01T08:35:00Z",
      "pass_reason": "different_values",
      "profile_score": 56
    }
  ],
  "last_updated": "2026-02-01T09:00:00Z"
}
```

#### `dating/compatibility_scores/{uid1}_{uid2}` (NEW - Cache)
```json
{
  "uid_pair": "user123_profile456",
  "score": 97,
  "calculated_at": "2026-02-01T00:15:00Z",
  "ttl": 86400000,  // 24 hours in ms
  "breakdown": {
    "core_values": {
      "score": 95,
      "matches": ["tithing", "no_cohabiting"],
      "mismatches": ["tongues"]
    },
    "lifestyle": {
      "score": 94,
      "matches": ["marital_status", "kids_preference"],
      "mismatches": ["long_distance"]
    },
    "life_stage": {
      "score": 102,
      "matches": ["age", "location", "timeline"],
      "mismatches": []
    }
  }
}
```

---

## 2. Core Algorithm: Compatibility Scoring

### Implementation (Dart/Flutter Backend)

```dart
// File: lib/core/services/compatibility_scoring_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/compatibility_data.dart';

class CompatibilityScoringService {
  static const int CACHE_DURATION_MS = 86400000; // 24 hours
  static const int MIN_SCORE_THRESHOLD = 50; // Don't show below 50%
  
  final FirebaseFirestore _firestore;

  CompatibilityScoringService(this._firestore);

  /// Calculate compatibility between two users
  /// Returns score 0-100 and detailed breakdown
  Future<CompatibilityResult> calculateCompatibility(
    UserModel userA,
    UserModel userB,
  ) async {
    // Check cache first
    final cached = await _getCachedScore(userA.id, userB.id);
    if (cached != null) {
      return cached;
    }

    // Calculate fresh score
    final coreValuesScore = _scoreCoreValues(userA, userB);
    final lifestyleScore = _scoreLifestyle(userA, userB);
    final lifeStageScore = _scoreLifeStage(userA, userB);

    // Weighted average
    final totalScore = (
      (coreValuesScore * 0.40) +
      (lifestyleScore * 0.35) +
      (lifeStageScore * 0.25)
    ).round();

    final result = CompatibilityResult(
      score: totalScore,
      coreValuesScore: coreValuesScore,
      lifestyleScore: lifestyleScore,
      lifeStageScore: lifeStageScore,
      matchReasons: _generateMatchReasons(
        userA, 
        userB, 
        coreValuesScore, 
        lifestyleScore, 
        lifeStageScore
      ),
      matchWarnings: _generateMatchWarnings(userA, userB),
    );

    // Cache result
    await _cacheScore(userA.id, userB.id, result);

    return result;
  }

  /// Score core values alignment (40% weight)
  int _scoreCoreValues(UserModel userA, UserModel userB) {
    double points = 0;
    const maxPoints = 5.0;

    // Get compatibility data
    final compatA = userA.compatibility;
    final compatB = userB.compatibility;

    if (compatA == null || compatB == null) {
      return 50; // Default if incomplete
    }

    // Tithing beliefs (most important - 1.0 point)
    if (compatA.believeInTithing == compatB.believeInTithing) {
      points += 1.0;
    }

    // Speaking in tongues (0.8 points)
    if (compatA.shouldChristianSpeakInTongue == 
        compatB.shouldChristianSpeakInTongue) {
      points += 0.8;
    }

    // Cohabitation stance (0.8 points)
    if (compatA.believeInCohabiting == compatB.believeInCohabiting) {
      points += 0.8;
    }

    // Marrying someone not Faith-Strong (0.7 points)
    if (compatA.marrySomeoneNotFS == compatB.marrySomeoneNotFS) {
      points += 0.7;
    }

    // Income stability (0.7 points)
    if (compatA.regularSourceOfIncome == compatB.regularSourceOfIncome) {
      points += 0.7;
    }

    return ((points / maxPoints) * 100).round();
  }

  /// Score lifestyle compatibility (35% weight)
  int _scoreLifestyle(UserModel userA, UserModel userB) {
    double points = 0;
    const maxPoints = 4.0;

    final compatA = userA.compatibility;
    final compatB = userB.compatibility;

    if (compatA == null || compatB == null) {
      return 50;
    }

    // Marital status (1.0 point)
    if (compatA.maritalStatus == compatB.maritalStatus) {
      points += 1.0;
    } else if (compatA.maritalStatus == 'Never Married') {
      points += 0.7; // Prefer never married
    }

    // Kids preference (1.0 point)
    if (compatA.haveKids == compatB.haveKids) {
      points += 1.0;
    }

    // Long distance willingness (1.0 point)
    if (compatA.longDistance == compatB.longDistance) {
      points += 1.0;
    } else if (compatA.longDistance == 'Yes' || 
               compatB.longDistance == 'Yes') {
      points += 0.5; // One is open
    }

    // Genotype compatibility (1.0 point)
    if (compatA.genotype != null && compatB.genotype != null) {
      if (_isCompatibleGenotype(compatA.genotype!, compatB.genotype!)) {
        points += 1.0;
      }
    } else {
      points += 0.5; // Assume compatible if not set
    }

    return ((points / maxPoints) * 100).round();
  }

  /// Score life stage alignment (25% weight)
  int _scoreLifeStage(UserModel userA, UserModel userB) {
    double points = 0;
    const maxPoints = 3.0;

    // Age proximity (1.0 point)
    final ageDiff = (userA.age ?? 0) - (userB.age ?? 0);
    if (ageDiff.abs() <= 5) {
      points += 1.0;
    } else if (ageDiff.abs() <= 10) {
      points += 0.6;
    } else {
      points += 0.2;
    }

    // Location/Country (1.0 point)
    if (userA.country == userB.country) {
      points += 1.0;
    } else if ((userA.country?.toLowerCase().contains('diaspora') ?? false) ||
               (userB.country?.toLowerCase().contains('diaspora') ?? false)) {
      points += 0.5;
    }

    // Relationship timeline alignment (1.0 point)
    // TODO: Add relationship_timeline field to UserModel
    points += 1.0; // Default for now

    return ((points / maxPoints) * 100).round();
  }

  /// Check if two genotypes are compatible
  bool _isCompatibleGenotype(String genoA, String genoB) {
    // AA × AA = Safe
    if (genoA == 'AA' && genoB == 'AA') return true;
    
    // AA × AS = Safe
    if ((genoA == 'AA' && genoB == 'AS') ||
        (genoA == 'AS' && genoB == 'AA')) {
      return true;
    }
    
    // AS × AS = Risk (not recommended)
    // AS × SS, SS × SS = Risk (not recommended)
    return false;
  }

  /// Generate human-readable match reasons
  List<String> _generateMatchReasons(
    UserModel userA,
    UserModel userB,
    int coreValuesScore,
    int lifestyleScore,
    int lifeStageScore,
  ) {
    final reasons = <String>[];

    final compatA = userA.compatibility;
    final compatB = userB.compatibility;

    if (compatA != null && compatB != null) {
      // Core values reasons
      if (compatA.believeInTithing == compatB.believeInTithing &&
          compatA.believeInTithing == 'Yes') {
        reasons.add('Same faith commitment (Tithing believer)');
      }

      if (compatA.maritalStatus == 'Never Married' &&
          compatB.maritalStatus == 'Never Married') {
        reasons.add('Both never married');
      }

      if (compatA.haveKids == compatB.haveKids) {
        if (compatA.haveKids == 'No') {
          reasons.add('Same preference on kids');
        }
      }

      // Lifestyle reasons
      if (compatA.longDistance == compatB.longDistance) {
        if (compatA.longDistance == 'Yes') {
          reasons.add('Both open to long distance');
        }
      }
    }

    // Life stage reasons
    if ((userA.age ?? 0) - (userB.age ?? 0).abs() <= 5) {
      reasons.add('Similar age');
    }

    if (userA.country == userB.country) {
      reasons.add('Same country');
    }

    // Ensure we have at least 2-3 reasons
    while (reasons.length < 2) {
      reasons.add('Potential compatibility');
    }

    return reasons.take(3).toList();
  }

  /// Generate match warnings
  List<String> _generateMatchWarnings(UserModel userA, UserModel userB) {
    final warnings = <String>[];

    final compatA = userA.compatibility;
    final compatB = userB.compatibility;

    if (compatA != null && compatB != null) {
      if (compatA.longDistance != compatB.longDistance) {
        final preferenceA = compatA.longDistance ?? 'No';
        final preferenceB = compatB.longDistance ?? 'No';
        warnings.add(
          'Different on long distance (${userA.displayName}: $preferenceA, '
          '${userB.displayName}: $preferenceB)',
        );
      }

      if (compatA.haveKids != compatB.haveKids) {
        warnings.add('Different on kids preference');
      }

      if (compatA.shouldChristianSpeakInTongue != 
          compatB.shouldChristianSpeakInTongue) {
        warnings.add('Different on tongues theology');
      }
    }

    return warnings;
  }

  /// Get cached compatibility score
  Future<CompatibilityResult?> _getCachedScore(
    String uidA,
    String uidB,
  ) async {
    try {
      final docId = _generateDocId(uidA, uidB);
      final doc = await _firestore
          .collection('dating/compatibility_scores')
          .doc(docId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final createdAt = (data['calculated_at'] as Timestamp).toDate();

      // Check if cache expired
      if (DateTime.now().difference(createdAt).inMilliseconds > 
          CACHE_DURATION_MS) {
        return null;
      }

      return CompatibilityResult.fromMap(data);
    } catch (e) {
      print('Error getting cached score: $e');
      return null;
    }
  }

  /// Cache compatibility score
  Future<void> _cacheScore(
    String uidA,
    String uidB,
    CompatibilityResult result,
  ) async {
    try {
      final docId = _generateDocId(uidA, uidB);
      await _firestore
          .collection('dating/compatibility_scores')
          .doc(docId)
          .set({
        'uid_pair': docId,
        'score': result.score,
        'calculated_at': FieldValue.serverTimestamp(),
        'ttl': CACHE_DURATION_MS,
        'core_values_score': result.coreValuesScore,
        'lifestyle_score': result.lifestyleScore,
        'life_stage_score': result.lifeStageScore,
      });
    } catch (e) {
      print('Error caching score: $e');
    }
  }

  /// Generate consistent document ID
  String _generateDocId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

/// Result of compatibility calculation
class CompatibilityResult {
  final int score; // 0-100
  final int coreValuesScore;
  final int lifestyleScore;
  final int lifeStageScore;
  final List<String> matchReasons;
  final List<String> matchWarnings;

  CompatibilityResult({
    required this.score,
    required this.coreValuesScore,
    required this.lifestyleScore,
    required this.lifeStageScore,
    required this.matchReasons,
    required this.matchWarnings,
  });

  bool get isHighMatch => score >= 80;
  bool get isGoodMatch => score >= 70;
  bool get isPotentialMatch => score >= 50;

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'core_values_score': coreValuesScore,
      'lifestyle_score': lifestyleScore,
      'life_stage_score': lifeStageScore,
      'match_reasons': matchReasons,
      'match_warnings': matchWarnings,
    };
  }

  factory CompatibilityResult.fromMap(Map<String, dynamic> map) {
    return CompatibilityResult(
      score: map['score'] as int? ?? 0,
      coreValuesScore: map['core_values_score'] as int? ?? 0,
      lifestyleScore: map['lifestyle_score'] as int? ?? 0,
      lifeStageScore: map['life_stage_score'] as int? ?? 0,
      matchReasons: List<String>.from(map['match_reasons'] as List? ?? []),
      matchWarnings: List<String>.from(map['match_warnings'] as List? ?? []),
    );
  }
}
```

---

## 3. Daily Matching Algorithm

### Cloud Function (Node.js)

```javascript
// File: functions/src/dating/dailyMatchingJob.ts

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { CompatibilityCalculator } from './compatibilityCalculator';

const db = admin.firestore();

/**
 * Scheduled function: Runs daily at 00:00 UTC
 * Generates fresh matches for all dating users
 */
export const generateDailyMatches = functions
  .runWith({ timeoutSeconds: 540, memory: '2GB' })
  .pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting daily match generation at:', new Date().toISOString());

    try {
      const snapshot = await db
        .collection('users')
        .where('dating_opt_in', '==', true)
        .where('dating_profile_complete', '==', true)
        .get();

      console.log(`Processing ${snapshot.docs.length} dating users`);

      const batch = db.batch();
      let batchCount = 0;
      const BATCH_LIMIT = 500;

      for (const userDoc of snapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        try {
          // Calculate matches for this user
          const matches = await calculateMatchesForUser(userId, userData);

          // Store matches in daily collection
          const todayStr = new Date().toISOString().split('T')[0];
          const matchDocRef = db
            .collection('dating/daily_matches')
            .doc(`${userId}_${todayStr}`);

          batch.set(matchDocRef, {
            uid: userId,
            date: todayStr,
            generated_at: admin.firestore.FieldValue.serverTimestamp(),
            matches: matches.map(m => ({
              profile_uid: m.profileId,
              compatibility_score: m.score,
              score_breakdown: {
                core_values: m.coreValuesScore,
                lifestyle: m.lifestyleScore,
                life_stage: m.lifeStageScore,
              },
              match_reasons: m.reasons,
              match_warnings: m.warnings,
            })),
            total_profiles_available: matches.length,
            algorithm_version: 'v2.1',
          });

          batchCount++;
          if (batchCount === BATCH_LIMIT) {
            await batch.commit();
            console.log(`Committed ${BATCH_LIMIT} matches`);
            batchCount = 0;
          }
        } catch (err) {
          console.error(`Error processing user ${userId}:`, err);
        }
      }

      // Commit remaining
      if (batchCount > 0) {
        await batch.commit();
        console.log(`Committed final ${batchCount} matches`);
      }

      console.log('Daily match generation completed');
    } catch (err) {
      console.error('Error in daily match generation:', err);
      throw err;
    }
  });

/**
 * Calculate best matches for a user
 */
async function calculateMatchesForUser(
  userId: string,
  userData: any,
): Promise<any[]> {
  const preferences = userData.dating_preferences || {};
  const userGender = userData.gender;

  // Get opposite gender candidates
  const targetGender = userGender === 'Male' ? 'Female' : 'Male';

  let candidateQuery = db
    .collection('users')
    .where('gender', '==', targetGender)
    .where('dating_opt_in', '==', true)
    .where('dating_profile_complete', '==', true);

  // Apply hard filters
  if (preferences.pref_countries?.length > 0) {
    candidateQuery = candidateQuery.where(
      'country',
      'in',
      preferences.pref_countries,
    );
  }

  const candidates = await candidateQuery
    .limit(500) // Sample from top 500
    .get();

  // Calculate compatibility for all
  const calculator = new CompatibilityCalculator();
  const scored = [];

  for (const candidateDoc of candidates.docs) {
    try {
      const score = await calculator.calculateCompatibility(
        userData,
        candidateDoc.data(),
      );

      if (score.total >= 50) {
        // Only include if above minimum
        scored.push({
          profileId: candidateDoc.id,
          score: score.total,
          coreValuesScore: score.coreValues,
          lifestyleScore: score.lifestyle,
          lifeStageScore: score.lifeStage,
          reasons: score.reasons,
          warnings: score.warnings,
        });
      }
    } catch (err) {
      console.warn(`Error scoring ${candidateDoc.id}:`, err);
    }
  }

  // Sort by score
  scored.sort((a, b) => b.score - a.score);

  // Diversify: 40% top, 30% mid, 30% exploratory
  const topTier = scored.filter(s => s.score >= 80);
  const midTier = scored.filter(s => s.score >= 60 && s.score < 80);
  const exploratory = scored.filter(s => s.score < 60);

  const diversified = [
    ...topTier.slice(0, 3),
    ...shuffle(midTier).slice(0, 2),
    ...shuffle(exploratory).slice(0, 3),
  ].slice(0, 8); // Limit to 8 per day

  return diversified;
}

function shuffle<T>(array: T[]): T[] {
  const shuffled = [...array];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return shuffled;
}
```

---

## 4. Frontend Integration

### Provider for Daily Matches

```dart
// File: lib/features/dating_search/application/daily_matches_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../domain/dating_profile.dart';

/// Provider for today's curated matches
final dailyMatchesProvider = FutureProvider<List<DailyMatchCard>>((ref) async {
  final auth = ref.watch(authProvider);
  final user = auth.valueOrNull;

  if (user == null) return [];

  final firestore = FirebaseFirestore.instance;
  final today = DateTime.now().toIso8601String().split('T')[0];

  try {
    final doc = await firestore
        .collection('dating/daily_matches')
        .doc('${user.uid}_$today')
        .get();

    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;
    final matches = (data['matches'] as List?)?.map((m) {
      return DailyMatchCard.fromMap(m as Map<String, dynamic>);
    }).toList() ?? [];

    return matches;
  } catch (e) {
    print('Error fetching daily matches: $e');
    return [];
  }
});

/// Single match card data
class DailyMatchCard {
  final String profileUid;
  final int compatibilityScore;
  final int coreValuesScore;
  final int lifestyleScore;
  final int lifeStageScore;
  final List<String> matchReasons;
  final List<String> matchWarnings;
  
  DailyMatchCard({
    required this.profileUid,
    required this.compatibilityScore,
    required this.coreValuesScore,
    required this.lifestyleScore,
    required this.lifeStageScore,
    required this.matchReasons,
    required this.matchWarnings,
  });

  factory DailyMatchCard.fromMap(Map<String, dynamic> map) {
    return DailyMatchCard(
      profileUid: map['profile_uid'] as String,
      compatibilityScore: map['compatibility_score'] as int? ?? 0,
      coreValuesScore: 
          map['score_breakdown']?['core_values'] as int? ?? 0,
      lifestyleScore: 
          map['score_breakdown']?['lifestyle'] as int? ?? 0,
      lifeStageScore: 
          map['score_breakdown']?['life_stage'] as int? ?? 0,
      matchReasons: 
          List<String>.from(map['match_reasons'] as List? ?? []),
      matchWarnings: 
          List<String>.from(map['match_warnings'] as List? ?? []),
    );
  }

  String get compatibilityLabel {
    if (compatibilityScore >= 80) return 'Excellent Match';
    if (compatibilityScore >= 70) return 'Good Match';
    return 'Potential Match';
  }

  Color get compatibilityColor {
    if (compatibilityScore >= 80) return Colors.green;
    if (compatibilityScore >= 70) return Colors.amber;
    return Colors.grey;
  }
}
```

### Discovery Screen Widget

```dart
// File: lib/features/dating_search/presentation/screens/discovery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/daily_matches_provider.dart';
import '../../domain/dating_profile.dart';
import '../../../../core/theme/theme.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  int _currentMatchIndex = 0;

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(dailyMatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Today's Matches",
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.refresh(dailyMatchesProvider);
            },
          ),
        ],
      ),
      body: matchesAsync.when(
        data: (matches) {
          if (matches.isEmpty) {
            return _buildEmptyState(context);
          }

          return SafeArea(
            child: PageView.builder(
              onPageChanged: (index) {
                setState(() {
                  _currentMatchIndex = index;
                });
              },
              itemCount: matches.length,
              itemBuilder: (context, index) {
                return _buildMatchCard(context, ref, matches[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err'),
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    WidgetRef ref,
    DailyMatchCard match,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Compatibility Score Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: match.compatibilityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: match.compatibilityColor,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${match.compatibilityScore}% ${match.compatibilityLabel}',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: match.compatibilityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Match Reasons
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why You Match',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...match.matchReasons.map((reason) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (match.matchWarnings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Things to Discuss',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...match.matchWarnings.map((warning) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning,
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.thumb_down),
                label: const Text('Next'),
                onPressed: () {
                  // Log pass interaction
                  _logInteraction(match, 'pass');
                  // Move to next (PageView handles this)
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.favorite),
                label: const Text('Save'),
                onPressed: () {
                  _logInteraction(match, 'save');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Profile saved')),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.message),
                label: const Text('Connect'),
                onPressed: () {
                  // Navigate to message composer
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: AppColors.getTextSecondary(context),
          ),
          const SizedBox(height: 16),
          Text(
            'All today\'s matches viewed',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Fresh matches available tomorrow at 8 AM',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to saved profiles
            },
            child: const Text('View Saved Profiles'),
          ),
        ],
      ),
    );
  }

  void _logInteraction(DailyMatchCard match, String action) {
    // Log to analytics and database
    ref.read(dailyMatchesProvider).whenData((matches) {
      // Store interaction
    });
  }
}
```

---

## 5. Performance Optimization

### Caching Strategy

```dart
// File: lib/core/services/cache_service.dart

class DatingCacheService {
  static const Duration SCORE_CACHE_DURATION = Duration(hours: 24);
  static const Duration PROFILE_CACHE_DURATION = Duration(hours: 12);

  final Map<String, CachedItem> _memoryCache = {};

  Future<T?> getOrCompute<T>(
    String key,
    Future<T> Function() compute, {
    Duration? duration,
  }) async {
    final cached = _memoryCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.value as T?;
    }

    try {
      final result = await compute();
      _memoryCache[key] = CachedItem(
        value: result,
        expiresAt: DateTime.now().add(duration ?? Duration(hours: 1)),
      );
      return result;
    } catch (e) {
      print('Error computing cached value: $e');
      return null;
    }
  }

  void invalidate(String key) {
    _memoryCache.remove(key);
  }

  void clear() {
    _memoryCache.clear();
  }
}

class CachedItem {
  final dynamic value;
  final DateTime expiresAt;

  CachedItem({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
```

### Firestore Query Optimization

```dart
// Create indexes in firestore.indexes.json

{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "Collection",
      "fields": [
        {"fieldPath": "gender", "order": "ASCENDING"},
        {"fieldPath": "dating_opt_in", "order": "ASCENDING"},
        {"fieldPath": "dating_profile_complete", "order": "ASCENDING"},
        {"fieldPath": "country", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "dating/compatibility_scores",
      "queryScope": "Collection",
      "fields": [
        {"fieldPath": "calculated_at", "order": "DESCENDING"}
      ]
    }
  ]
}
```

---

## 6. Testing Strategy

### Unit Tests

```dart
// File: test/core/services/compatibility_scoring_service_test.dart

void main() {
  group('CompatibilityScoringService', () {
    late CompatibilityScoringService service;

    setUp(() {
      service = CompatibilityScoringService(mockFirestore);
    });

    test('calculates compatibility score correctly', () async {
      final userA = createMockUser(
        compatibilityData: const CompatibilityData(
          believeInTithing: 'Yes',
          maritalStatus: 'Never Married',
          genotype: 'AA',
        ),
      );

      final userB = createMockUser(
        compatibilityData: const CompatibilityData(
          believeInTithing: 'Yes',
          maritalStatus: 'Never Married',
          genotype: 'AA',
        ),
      );

      final result = await service.calculateCompatibility(userA, userB);

      expect(result.score, greaterThanOrEqualTo(80));
      expect(result.matchReasons, isNotEmpty);
    });

    test('genotype compatibility check works', () {
      expect(service.isCompatibleGenotype('AA', 'AA'), true);
      expect(service.isCompatibleGenotype('AA', 'AS'), true);
      expect(service.isCompatibleGenotype('AS', 'AS'), false);
    });
  });
}
```

---

## 7. Deployment Checklist

- [ ] Create Firestore indexes
- [ ] Deploy cloud functions (daily matching job)
- [ ] Migrate user data (compatibility quiz, preferences)
- [ ] Implement compatibility scoring service
- [ ] Build frontend screens (discovery, match cards)
- [ ] Add analytics tracking
- [ ] Performance testing (load test with 10k users)
- [ ] Beta testing (100 users, 2 weeks)
- [ ] Production rollout (gradual 10% → 50% → 100%)

---

## Next Steps

1. **Week 1-2:** Implement compatibility scoring algorithm
2. **Week 3-4:** Build cloud function for daily matching
3. **Week 5-6:** Create frontend UI components
4. **Week 7:** Integration testing and optimization
5. **Week 8:** Beta launch and feedback gathering
6. **Week 9-10:** Refinement based on feedback
7. **Week 11:** Production launch

This implementation roadmap ensures a robust, performant dating discovery system tailored for Christian singles on Nexus.
