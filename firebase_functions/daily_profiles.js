/**
 * DAILY PROFILES CLOUD FUNCTIONS
 * 
 * Handles:
 * 1. Daily compatibility scoring (midnight UTC via Cloud Scheduler)
 * 2. Push notifications for new daily profiles
 * 3. Preference change updates
 * 4. New profile approvals
 * 
 * DEPLOYMENT:
 * These functions are imported and exported in index.js
 * No additional setup needed - Cloud Scheduler job must be created manually
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const MIN_PROFILES_FOR_NOTIFICATION = 5;

// ============================================================================
// COMPATIBILITY SCORING ENGINE
// ============================================================================

/**
 * Calculate compatibility score between user and profile (0-100)
 * Framework:
 * - Faith alignment (40pts): Speaking in Tongues + Tithing (dealbreaker if misaligned)
 * - Lifestyle (35pts): Kids + Long distance + Cohabiting
 * - Basic compat (15pts): Genotype + Personality + Income
 * - Financial penalty (-10pts): If woman requires stable income but man doesn't have it
 * 
 * Score Interpretation:
 * - 100: Perfect alignment on faith + lifestyle
 * - 90-99: Minor differences in lifestyle
 * - 70-89: One major lifestyle difference
 * - 60-69: Multiple lifestyle differences
 * - 0-59: Faith misalignment or major incompatibilities
 */
function calculateCompatibilityScore(userAnswers, profileAnswers) {
  if (!userAnswers || !profileAnswers) {
    console.warn('[Score] Missing compatibility data, returning 0');
    return 0;
  }

  let score = 0;
  const breakdown = {
    faith: 0,
    lifestyle: 0,
    basic: 0,
    financial: 0,
  };

  // ====================================================================
  // FAITH ALIGNMENT (40 pts) - DEALBREAKER SECTION
  // ====================================================================
  
  // Speaking in tongues (20 pts)
  const userTongues = (userAnswers.shouldChristianSpeakInTongue || '').toLowerCase();
  const profileTongues = (profileAnswers.shouldChristianSpeakInTongue || '').toLowerCase();
  
  if (!userTongues || !profileTongues) {
    // Missing data = 0 faith points (conservative approach)
    breakdown.faith += 0;
  } else if (
    (userTongues === 'yes' && profileTongues === 'yes') ||
    (userTongues === 'no' && profileTongues === 'no') ||
    (userTongues === 'i\'m not sure') || // User flexible = 20 pts
    (profileTongues === 'i\'m not sure')   // Profile flexible = 20 pts
  ) {
    breakdown.faith += 20;
  } else if (userTongues === 'no' && profileTongues === 'yes') {
    // Hard mismatch = 0 pts
    breakdown.faith += 0;
  } else if (userTongues === 'yes' && profileTongues === 'no') {
    // Hard mismatch = 0 pts
    breakdown.faith += 0;
  } else {
    breakdown.faith += 10; // Partial match
  }

  // Tithing (20 pts)
  const userTithing = (userAnswers.believeInTithing || '').toLowerCase();
  const profileTithing = (profileAnswers.believeInTithing || '').toLowerCase();
  
  if (!userTithing || !profileTithing) {
    breakdown.faith += 0;
  } else if (
    (userTithing === 'yes' && profileTithing === 'yes') ||
    (userTithing === 'no' && profileTithing === 'no')
  ) {
    breakdown.faith += 20;
  } else {
    breakdown.faith += 0; // Hard mismatch on tithing = dealbreaker
  }

  // ====================================================================
  // LIFESTYLE ALIGNMENT (35 pts)
  // ====================================================================
  
  // Kids compatibility (15 pts)
  const userKids = (userAnswers.haveKids || '').toLowerCase();
  const profileKids = (profileAnswers.haveKids || '').toLowerCase();
  
  if (!userKids || !profileKids) {
    breakdown.lifestyle += 0;
  } else if (
    (userKids === 'yes' && profileKids === 'yes') ||
    (userKids === 'no' && profileKids === 'no')
  ) {
    breakdown.lifestyle += 15;
  } else if (
    (userKids === 'yes' && profileKids === 'no') ||
    (userKids === 'no' && profileKids === 'yes')
  ) {
    // One has kids, other doesn't = partial match
    breakdown.lifestyle += 7;
  } else {
    breakdown.lifestyle += 0;
  }

  // Long distance (10 pts)
  const userDistance = (userAnswers.longDistance || '').toLowerCase();
  const profileDistance = (profileAnswers.longDistance || '').toLowerCase();
  
  if (!userDistance || !profileDistance) {
    breakdown.lifestyle += 0;
  } else if (userDistance === 'yes' || profileDistance === 'yes') {
    // Either is open = full points
    breakdown.lifestyle += 10;
  } else if (userDistance === 'no' && profileDistance === 'no') {
    // Both prefer local = full points
    breakdown.lifestyle += 10;
  } else {
    breakdown.lifestyle += 0;
  }

  // Cohabiting (10 pts)
  const userCohabit = (userAnswers.believeInCohabiting || '').toLowerCase();
  const profileCohabit = (profileAnswers.believeInCohabiting || '').toLowerCase();
  
  if (!userCohabit || !profileCohabit) {
    breakdown.lifestyle += 0;
  } else if (
    (userCohabit.includes('yes') && profileCohabit.includes('yes')) ||
    (userCohabit.includes('no') && profileCohabit.includes('no'))
  ) {
    breakdown.lifestyle += 10;
  } else {
    breakdown.lifestyle += 5; // Different but negotiable
  }

  // ====================================================================
  // BASIC COMPATIBILITY (15 pts)
  // ====================================================================
  
  // Genotype (5 pts) - AA/AS/AC compatible; SS limited
  const userGenotype = (userAnswers.genotype || '').toUpperCase();
  const profileGenotype = (profileAnswers.genotype || '').toUpperCase();
  
  if (!userGenotype || !profileGenotype) {
    breakdown.basic += 0;
  } else if (userGenotype === profileGenotype) {
    breakdown.basic += 5;
  } else if (
    (userGenotype === 'AA' && profileGenotype === 'AC') ||
    (userGenotype === 'AC' && profileGenotype === 'AA')
  ) {
    breakdown.basic += 5;
  } else {
    breakdown.basic += 2; // Different = minor penalty
  }

  // Personality (5 pts) - Any match accepted
  const userPersonality = (userAnswers.personalityType || '').toLowerCase();
  const profilePersonality = (profileAnswers.personalityType || '').toLowerCase();
  
  if (!userPersonality || !profilePersonality) {
    breakdown.basic += 0;
  } else {
    // Personality is flexible - no major penalty for difference
    breakdown.basic += 5;
  }

  // Income (5 pts)
  const userIncome = (userAnswers.regularSourceOfIncome || '').toLowerCase();
  const profileIncome = (profileAnswers.regularSourceOfIncome || '').toLowerCase();
  
  if (!userIncome || !profileIncome) {
    breakdown.basic += 0;
  } else if (userIncome === profileIncome) {
    breakdown.basic += 5;
  } else {
    breakdown.basic += 2; // Both have different income = minor penalty
  }

  // ====================================================================
  // FINANCIAL MISALIGNMENT PENALTY (-10 pts)
  // Edge case: Woman wants financially stable man, man doesn't have income
  // ====================================================================
  breakdown.financial = 0;
  
  const userFSAnswer = (userAnswers.marrySomeoneNotFS || '').toLowerCase();
  const profileFSAnswer = (profileAnswers.marrySomeoneNotFS || '').toLowerCase();
  
  // If user says "No, must be financially stable" 
  // AND profile says "No, don't have income"
  // = Hard incompatibility
  if (
    userFSAnswer.includes('no') && 
    profileIncome === 'no'
  ) {
    breakdown.financial = -10;
  }

  // Calculate total (max 100, min 0)
  score = breakdown.faith + breakdown.lifestyle + breakdown.basic + breakdown.financial;
  score = Math.max(0, Math.min(100, score));

  console.log(
    `[Score] User vs Profile: ${score}% | Faith: ${breakdown.faith}, Lifestyle: ${breakdown.lifestyle}, Basic: ${breakdown.basic}, Financial: ${breakdown.financial}`
  );

  return score;
}

// ============================================================================
// MAIN SCHEDULER: DAILY PROFILE CALCULATION (Midnight UTC)
// ============================================================================

/**
 * Cloud Scheduler Job (Created manually in GCP Console):
 * - Name: daily-profile-refresh
 * - Frequency: 0 0 * * * (midnight UTC)
 * - HTTP Target: calculateDailyProfiles function
 */
async function calculateDailyProfiles(req, res) {
  const startTime = Date.now();
  console.log('🚀 [DailyProfiles] Starting daily profile calculation at', new Date().toISOString());

  try {
    const db = admin.firestore();
    const batch = db.batch();
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

    // ====================================================================
    // STEP 1: Get all UK users (complete profiles + compatibility quiz)
    // ====================================================================
    console.log('[DailyProfiles] Fetching UK users...');
    
    const usersSnapshot = await db
      .collection('users')
      .where('dating.profile.country', '==', 'United Kingdom')
      .where('compatibilitySetted', '==', true)
      .where('status', '!=', 'disabled')
      .get();

    if (usersSnapshot.empty) {
      console.log('[DailyProfiles] ⚠️  No UK users found');
      return res.status(200).json({
        success: true,
        message: 'No UK users to process',
        usersProcessed: 0,
      });
    }

    console.log(`[DailyProfiles] Found ${usersSnapshot.size} UK users with complete profiles`);

    // ====================================================================
    // STEP 2: Get all approved dating profiles in UK
    // ====================================================================
    console.log('[DailyProfiles] Fetching approved UK profiles...');
    
    const profilesSnapshot = await db
      .collection('users')
      .where('dating.profile.country', '==', 'United Kingdom')
      .where('dating.verificationStatus', '==', 'verified')
      .where('status', '!=', 'disabled')
      .get();

    const allProfiles = profilesSnapshot.docs.map(doc => ({
      uid: doc.id,
      data: doc.data(),
      compatibility: doc.data().compatibility || {},
    }));

    console.log(`[DailyProfiles] Found ${allProfiles.length} approved UK profiles`);

    // ====================================================================
    // STEP 3: For each user, calculate scores and select top 5
    // ====================================================================
    let usersProcessed = 0;
    let profilesWithMissingData = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      const userCompatibility = userData.compatibility || {};
      const userGender = (userData.gender || '').toLowerCase();

      // Skip users with incomplete data
      if (!userGender || !userCompatibility) {
        console.warn(`[DailyProfiles] Skipping user ${userId} - missing gender or compatibility`);
        continue;
      }

      // Only show opposite gender (standard dating)
      const targetGender = userGender === 'male' ? 'female' : 'male';

      // Get profiles user has already viewed in the past
      // This prevents the same profile from being shown again to the same user.
      const viewedProfilesSnapshot = await db
        .collection('users')
        .doc(userId)
        .collection('dailyProfilesViewed')
        .get();

      const viewedProfileIds = new Set(
        viewedProfilesSnapshot.docs.map(doc => doc.id)
      );

      // Calculate scores for all unseen, opposite-gender profiles
      // ====================================================================
      // IMPORTANT: All viable profiles are shown (sorted by score) - NO threshold
      // filtering. Reason: A profile with 40% compat to User A might score 80%+
      // with User B. Compatibility is bidirectional per pairing, not absolute.
      // ====================================================================
      const scoredProfiles = allProfiles
        .filter(p => {
          const profileGender = (p.data.gender || '').toLowerCase();
          return profileGender === targetGender && !viewedProfileIds.has(p.uid);
        })
        .map(profile => ({
          profileId: profile.uid,
          name: profile.data.name || 'Unknown',
          age: profile.data.age || 0,
          country: profile.data.dating?.profile?.country || 'N/A',
          compatibilityScore: calculateCompatibilityScore(
            userCompatibility,
            profile.compatibility
          ),
        }))
        .sort((a, b) => b.compatibilityScore - a.compatibilityScore)
        .slice(0, MIN_PROFILES_FOR_NOTIFICATION); // Top N by score only

      if (scoredProfiles.length === 0) {
        console.warn(`[DailyProfiles] No suitable profiles found for user ${userId}`);
        continue;
      }

      // Store daily profiles in Firestore
      const dailyProfilesRef = db
        .collection('dailyProfiles')
        .doc(today)
        .collection('users')
        .doc(userId);

      batch.set(dailyProfilesRef, {
        profiles: scoredProfiles,
        refreshedAt: admin.firestore.FieldValue.serverTimestamp(),
        userGender: userGender,
        userPreferencesSnapshot: {
          minAge: userData.minAge || 21,
          maxAge: userData.maxAge || 65,
          allowLongDistance: userData.allowLongDistance || false,
          openToKids: userData.openToKids || false,
        },
        notificationSent: false, // Will be updated after profiles are created
        notificationEligible: scoredProfiles.length >= MIN_PROFILES_FOR_NOTIFICATION,
        profileCount: scoredProfiles.length,
      });

      usersProcessed++;

      // Firestore batch limit is 500, so flush if needed
      if (usersProcessed % 100 === 0) {
        console.log(`[DailyProfiles] Processed ${usersProcessed} users...`);
      }
    }

    // Commit batch
    await batch.commit();
    console.log(`[DailyProfiles] ✅ Stored daily profiles for ${usersProcessed} users`);

    const duration = (Date.now() - startTime) / 1000;
    return res.status(200).json({
      success: true,
      usersProcessed,
      profilesWithMissingData,
      duration: `${duration.toFixed(2)}s`,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('[DailyProfiles] ❌ Error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
}

// ============================================================================
// SEND DAILY PROFILE NOTIFICATIONS
// ============================================================================

/**
 * Triggered after daily profiles are calculated
 * ⚠️  ONLY sends notifications if:
 *     1. User has daily profiles with actual profiles array
 *     2. Notification not already sent today
 *     3. User has FCM token enabled
 * This prevents disappointing users with notifications when no new profiles exist
 */
async function sendDailyProfileNotifications(req, res) {
  console.log('📢 [Notifications] Starting daily profile notifications...');

  try {
    const db = admin.firestore();
    const today = new Date().toISOString().split('T')[0];

    // Get users who have daily profiles for today
    const usersSnapshot = await db
      .collection('dailyProfiles')
      .doc(today)
      .collection('users')
      .get();

    let notificationsSent = 0;
    let notificationsSkipped = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const dailyProfilesData = userDoc.data();
      
      // ===================================================================
      // CRITICAL CHECKS:
      // 1. Must have actual profiles (not empty array)
      // 2. Notification must not already be sent today
      // 3. This prevents notifying users with no new profiles
      // ===================================================================
      
      const profiles = dailyProfilesData.profiles || [];
      const alreadyNotified = dailyProfilesData.notificationSent === true;
      const notificationEligible =
        dailyProfilesData.notificationEligible === true ||
        profiles.length >= MIN_PROFILES_FOR_NOTIFICATION;

      if (profiles.length === 0) {
        console.log(
          `[Notifications] Skipping ${userId} - no profiles available (all viewed or no suitable matches)`
        );
        notificationsSkipped++;
        continue;
      }

      if (!notificationEligible) {
        console.log(
          `[Notifications] Skipping ${userId} - only ${profiles.length} profiles available (< ${MIN_PROFILES_FOR_NOTIFICATION} threshold)`
        );
        notificationsSkipped++;
        continue;
      }

      if (alreadyNotified) {
        console.log(
          `[Notifications] Skipping ${userId} - notification already sent today`
        );
        notificationsSkipped++;
        continue;
      }

      // Get user document to check FCM token
      const userRef = db.collection('users').doc(userId);
      const userDoc_ = await userRef.get();
      const userData = userDoc_.data();

      // Check if user has notification enabled
      if (userData?.fcmToken === undefined || userData?.fcmToken === null) {
        console.log(`[Notifications] Skipping ${userId} - no FCM token`);
        notificationsSkipped++;
        continue;
      }

      // ===================================================================
      // SEND NOTIFICATION ONLY IF ALL CHECKS PASS
      // ===================================================================
      
      // Create notification document (sendPushNotification trigger will handle FCM)
      const notificationRef = userRef.collection('notifications').doc();
      
      await notificationRef.set({
        type: 'daily_profiles',
        title: 'New Profiles Available',
        body: 'Still Single? Check out these new profiles!',
        payload: {
          type: 'daily_profiles',
          deepLink: 'nexus://dating/daily-profiles',
          profileCount: profiles.length,
        },
        isSent: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mark notification as sent for this user today
      await userDoc
        .collection('dailyProfiles')
        .doc(today)
        .update({
          notificationSent: true,
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(
        `[Notifications] ✅ Sent notification to ${userId} (${profiles.length} profiles)`
      );
      notificationsSent++;
    }

    console.log(
      `[Notifications] ✅ Completed: ${notificationsSent} sent, ${notificationsSkipped} skipped`
    );

    return res.status(200).json({
      success: true,
      notificationsSent,
      notificationsSkipped,
      totalUsers: usersSnapshot.size,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('[Notifications] ❌ Error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

// ============================================================================
// CALLABLE: UPDATE DAILY PROFILES ON PREFERENCE CHANGE
// ============================================================================

/**
 * Called from Flutter app when user changes search preferences
 * Recalculates their daily 5 based on new preferences
 */
async function updateProfilesOnPreferenceChange(data, context) {
  const userId = context.auth.uid;
  if (!userId) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  console.log(`[PreferenceChange] User ${userId} changed preferences`);

  try {
    const db = admin.firestore();
    const today = new Date().toISOString().split('T')[0];

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (!userData?.compatibility) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'User has incomplete compatibility quiz'
      );
    }

    const userGender = (userData.gender || '').toLowerCase();
    const targetGender = userGender === 'male' ? 'female' : 'male';

    // Get all approved UK profiles
    const profilesSnapshot = await db
      .collection('users')
      .where('dating.profile.country', '==', 'United Kingdom')
      .where('dating.verificationStatus', '==', 'verified')
      .get();

    const allProfiles = profilesSnapshot.docs.map(doc => ({
      uid: doc.id,
      data: doc.data(),
      compatibility: doc.data().compatibility || {},
    }));

    // Get profiles user has viewed in the past
    const viewedProfilesSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('dailyProfilesViewed')
      .get();

    const viewedProfileIds = new Set(
      viewedProfilesSnapshot.docs.map(doc => doc.id)
    );

    // Recalculate top 5
    const scoredProfiles = allProfiles
      .filter(p => {
        const profileGender = (p.data.gender || '').toLowerCase();
        return profileGender === targetGender && !viewedProfileIds.has(p.uid);
      })
      .map(profile => ({
        profileId: profile.uid,
        name: profile.data.name || 'Unknown',
        age: profile.data.age || 0,
        country: profile.data.dating?.profile?.country || 'N/A',
        compatibilityScore: calculateCompatibilityScore(
          userData.compatibility,
          profile.compatibility
        ),
      }))
      .sort((a, b) => b.compatibilityScore - a.compatibilityScore)
      .slice(0, 5);

    // Update daily profiles
    await db
      .collection('dailyProfiles')
      .doc(today)
      .collection('users')
      .doc(userId)
      .update({
        profiles: scoredProfiles,
        refreshedAt: admin.firestore.FieldValue.serverTimestamp(),
        userPreferencesSnapshot: {
          minAge: userData.minAge || 21,
          maxAge: userData.maxAge || 65,
          allowLongDistance: userData.allowLongDistance || false,
          openToKids: userData.openToKids || false,
        },
      });

    console.log(`[PreferenceChange] ✅ Updated daily profiles for ${userId}`);

    return {
      success: true,
      profilesUpdated: scoredProfiles.length,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error(`[PreferenceChange] ❌ Error:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
}

// ============================================================================
// CALLABLE: HANDLE NEW PROFILE APPROVAL
// ============================================================================

/**
 * Called from admin review screen when profile is approved
 * Adds profile to next day's daily profile batch
 */
async function handleNewProfileApproval(data, context) {
  // Admin only
  if (!context.auth?.token?.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { profileUid } = data;
  if (!profileUid) {
    throw new functions.https.HttpsError('invalid-argument', 'profileUid required');
  }

  console.log(`[NewProfile] Admin approved profile: ${profileUid}`);

  try {
    const db = admin.firestore();

    // Get the profile document
    const profileDoc = await db.collection('users').doc(profileUid).get();
    const profileData = profileDoc.data();

    if (!profileData) {
      throw new functions.https.HttpsError('not-found', 'Profile not found');
    }

    // Store in pending profiles for next day (don't modify today's batch)
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split('T')[0];

    await db
      .collection('pendingDailyProfiles')
      .doc(tomorrowStr)
      .collection('profiles')
      .doc(profileUid)
      .set({
        profileUid,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Profile data will be fetched fresh at midnight calculation
      });

    console.log(`[NewProfile] ✅ Profile ${profileUid} queued for tomorrow's batch`);

    return {
      success: true,
      message: 'Profile will appear in tomorrow\'s daily selection',
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error(`[NewProfile] ❌ Error:`, error);
    throw new functions.https.HttpsError('internal', error.message);
  }
}

// ============================================================================
// CLEANUP: Remove old daily profile data (older than 30 days)
// ============================================================================

async function cleanupOldDailyProfiles(req, res) {
  console.log('[Cleanup] Starting daily profile cleanup...');

  try {
    const db = admin.firestore();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split('T')[0];

    // Delete old daily profiles
    const batch = db.batch();
    const oldDatesSnapshot = await db
      .collection('dailyProfiles')
      .where('refreshedAt', '<', admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .limit(50) // Process in batches
      .get();

    let docsDeleted = 0;
    oldDatesSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
      docsDeleted++;
    });

    if (docsDeleted > 0) {
      await batch.commit();
      console.log(`[Cleanup] ✅ Deleted ${docsDeleted} old daily profile documents`);
    }

    return res.status(200).json({
      success: true,
      docsDeleted,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('[Cleanup] ❌ Error:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  calculateDailyProfiles,
  sendDailyProfileNotifications,
  updateProfilesOnPreferenceChange,
  handleNewProfileApproval,
  cleanupOldDailyProfiles,
};
