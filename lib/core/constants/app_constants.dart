/// Nexus 2.0 Constants and Configuration

/// User relationship status types
/// Used to determine user path, assessments, and journeys
enum RelationshipStatus {
  singleNeverMarried('single_never_married', 'Never Married'),
  married('married', 'Married'),
  divorced('divorced', 'Divorced'),
  widowed('widowed', 'Widowed');

  final String value;
  final String displayName;

  const RelationshipStatus(this.value, this.displayName);

  static RelationshipStatus fromValue(String value) {
    return RelationshipStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RelationshipStatus.singleNeverMarried,
    );
  }

  bool get isSingle =>
      this == RelationshipStatus.singleNeverMarried ||
      this == RelationshipStatus.divorced ||
      this == RelationshipStatus.widowed;

  bool get isMarried => this == RelationshipStatus.married;
}

/// Presurvey goal display copies (mockup exact copies)
/// These are UI-facing and can be edited later without changing enums.
class PresurveyGoalCopy {
  static const List<String> neverMarried = [
    'Find a Compatible Partner through our Dating hub',
    'Take a Free Test to check your Readiness for Marriage',
    'Heal from past Trauma or Family Hurt',
    'Prepare for Marriage',
  ];

  /// Divorced and Widowed share the same copy
  static const List<String> divorcedWidowed = [
    'Heal from a Traumatic Marriage or Family Hurt',
    'Prepare for Remarriage',
    'Find a Compatible Partner through our Dating Hub',
    'Become a better parent to your Kid(s)',
  ];

  static const List<String> married = [
    'Check the Health of your Marriage',
    'Strengthen the Bond in Your Marriage',
    'Heal from Spousal Hurt',
    'Become a better Parent to your Kid(s)',
  ];

  static List<String> forStatus(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return neverMarried;
      case RelationshipStatus.married:
        return married;
      case RelationshipStatus.divorced:
      case RelationshipStatus.widowed:
        return divorcedWidowed;
    }
  }
}

/// User gender
enum Gender {
  male('male', 'Male'),
  female('female', 'Female');

  final String value;
  final String displayName;

  const Gender(this.value, this.displayName);

  static Gender fromValue(String value) {
    return Gender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Gender.male,
    );
  }
}

/// Primary user goals based on relationship status
enum UserGoal {
  // Singles (Never Married) goals
  findPartnerDating('find_partner_dating', 'Find a Partner through Dating'),
  findPartner('find_partner', 'Find a Life Partner'),
  takeReadinessTest('take_readiness_test', 'Take Free Readiness Test'),
  healingFamilyPatterns('healing_family_patterns', 'Heal from Family Patterns'),
  buildEmotionalHealth('build_emotional_health', 'Build Emotional Health'),
  developEmotionally('develop_emotionally', 'Develop Emotionally'),
  prepareForMarriage('prepare_for_marriage', 'Prepare for Marriage'),
  strengthenFaith('strengthen_faith', 'Strengthen My Faith'),
  buildCommunity('build_community', 'Build Community'),

  // Divorced/Widowed goals
  remarriageReadiness('remarriage_readiness', 'Check Remarriage Readiness'),
  healFromPast('heal_from_past', 'Heal from Past Marriage'),
  healAndRecover('heal_and_recover', 'Heal & Recover'),
  blendedFamilyPrep('blended_family_prep', 'Prepare for Blended Family'),
  restoreSelf('restore_self', 'Restore Yourself'),
  coParentWell('co_parent_well', 'Co-Parent Well'),

  // Married goals
  strengthenBond('strengthen_bond', 'Strengthen Marriage Bond'),
  strengthenMarriage('strengthen_marriage', 'Strengthen Our Marriage'),
  improveComms('improve_communication', 'Improve Communication'),
  improveCommunication('improve_comms', 'Improve Communication'),
  raisingKids('raising_kids', 'Raise Godly Kids'),
  parentTogether('parent_together', 'Parent Together'),
  marriageHealthCheck('marriage_health_check', 'Check Marriage Health'),
  conflictResolution('conflict_resolution', 'Resolve Conflicts Better'),
  restoreIntimacy('restore_intimacy', 'Restore Intimacy'),
  manageFinances('manage_finances', 'Manage Finances'),
  growSpiritually('grow_spiritually', 'Grow Spiritually Together');

  final String value;
  final String displayName;

  const UserGoal(this.value, this.displayName);

  static UserGoal fromValue(String value) {
    return UserGoal.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserGoal.takeReadinessTest,
    );
  }

  /// Goals available for each relationship status
  static List<UserGoal> goalsForStatus(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return [
          UserGoal.findPartnerDating,
          UserGoal.takeReadinessTest,
          UserGoal.healingFamilyPatterns,
          UserGoal.buildEmotionalHealth,
          UserGoal.prepareForMarriage,
        ];
      case RelationshipStatus.divorced:
      case RelationshipStatus.widowed:
        return [
          UserGoal.remarriageReadiness,
          UserGoal.healFromPast,
          UserGoal.blendedFamilyPrep,
          UserGoal.restoreSelf,
          UserGoal.findPartnerDating,
        ];
      case RelationshipStatus.married:
        return [
          UserGoal.strengthenBond,
          UserGoal.improveComms,
          UserGoal.raisingKids,
          UserGoal.marriageHealthCheck,
          UserGoal.conflictResolution,
          UserGoal.restoreIntimacy,
        ];
    }
  }
}

/// Assessment signal tiers
enum SignalTier {
  strong('STRONG', 3, 'Strong/Integrated'),
  developing('DEVELOPING', 2, 'Developing'),
  guarded('GUARDED', 1, 'Guarded'),
  atRisk('AT_RISK', 0, 'At-Risk'),
  restoration('RESTORATION', 1, 'Restoration');

  final String value;
  final int weight;
  final String displayName;

  const SignalTier(this.value, this.weight, this.displayName);

  static SignalTier fromValue(String value) {
    return SignalTier.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => SignalTier.developing,
    );
  }
}

/// Session lock rules
enum LockRule {
  free('Free'),
  locked('Locked');

  final String value;

  const LockRule(this.value);

  static LockRule fromValue(String value) {
    if (value.toLowerCase().contains('free')) {
      return LockRule.free;
    }
    return LockRule.locked;
  }

  bool get isFree => this == LockRule.free;
}

/// Session response types
enum ResponseType {
  scale3('scale_3'),
  singleSelect('single_select'),
  multiSelect('multi_select'),
  shortText('short_text'),
  challenge('challenge'),
  ranking('ranking'),
  scriptChoice('script_choice'),
  scheduler('scheduler'),
  reflection('reflection'),
  compound('compound'); // For combined types like "Single Select + Short Input"

  final String value;

  const ResponseType(this.value);

  static ResponseType fromValue(String value) {
    final lower = value.toLowerCase();

    // Check for exact matches first
    for (final type in ResponseType.values) {
      if (type.value == lower) return type;
    }

    // Handle compound types (e.g., "Single Select + Single Select")
    if (lower.contains('+')) {
      // Extract primary type from compound
      final primary = lower.split('+').first.trim();
      return _parseSingleType(primary);
    }

    // Handle alternate naming conventions
    return _parseSingleType(lower);
  }

  static ResponseType _parseSingleType(String value) {
    if (value.contains('reflect')) return ResponseType.reflection;
    if (value.contains('scale')) return ResponseType.scale3;
    if (value.contains('single') || value.contains('select')) {
      return ResponseType.singleSelect;
    }
    if (value.contains('multi')) return ResponseType.multiSelect;
    if (value.contains('short') ||
        value.contains('text') ||
        value.contains('input')) {
      return ResponseType.shortText;
    }
    if (value.contains('challenge')) return ResponseType.challenge;
    if (value.contains('rank')) return ResponseType.ranking;
    if (value.contains('script')) return ResponseType.scriptChoice;
    if (value.contains('schedule')) return ResponseType.scheduler;
    return ResponseType.shortText; // Default
  }
}

/// Session tiers for journey progress
enum SessionTier {
  starter('Starter'),
  growth('Growth'),
  deep('Deep'),
  premium('Premium');

  final String value;

  const SessionTier(this.value);

  static SessionTier fromValue(String value) {
    return SessionTier.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => SessionTier.starter,
    );
  }
}

/// Story read status
enum ReadStatus {
  unopened('unopened'),
  opened('opened'),
  read('read');

  final String value;

  const ReadStatus(this.value);

  static ReadStatus fromValue(String value) {
    return ReadStatus.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => ReadStatus.unopened,
    );
  }
}

/// Story content block types
enum ContentBlockType {
  paragraph('paragraph'),
  heading('heading'),
  quote('quote'),
  bullets('bullets');

  final String value;

  const ContentBlockType(this.value);

  static ContentBlockType fromValue(String value) {
    return ContentBlockType.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => ContentBlockType.paragraph,
    );
  }
}

/// Assessment types available in the app
enum AssessmentType {
  singlesReadiness(
    'singles_readiness',
    'Marriage Readiness Check (Singles)',
    'single_never_married',
  ),
  remarriageReadiness(
    'remarriage_readiness',
    'Remarriage Readiness Check',
    'divorced_widowed',
  ),
  marriageHealthCheck(
    'marriage_health_check',
    'Marriage Health Check',
    'married',
  );

  final String id;
  final String title;
  final String audience;

  const AssessmentType(this.id, this.title, this.audience);

  static AssessmentType? forAudience(String audience) {
    try {
      return AssessmentType.values.firstWhere((e) => e.audience == audience);
    } catch (_) {
      return null;
    }
  }

  static AssessmentType? fromId(String id) {
    try {
      return AssessmentType.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Pulse check values (3-point scale)
enum PulseValue {
  low('Low', 1),
  neutral('Neutral', 2),
  high('High', 3);

  final String displayName;
  final int value;

  const PulseValue(this.displayName, this.value);

  static PulseValue fromValue(int value) {
    return PulseValue.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PulseValue.neutral,
    );
  }

  static PulseValue fromString(String str) {
    return PulseValue.values.firstWhere(
      (e) => e.displayName.toLowerCase() == str.toLowerCase(),
      orElse: () => PulseValue.neutral,
    );
  }
}

/// Difficulty levels for post-session check-in
enum DifficultyLevel {
  easy('Easy', 1),
  moderate('Moderate', 2),
  hard('Hard', 3);

  final String displayName;
  final int value;

  const DifficultyLevel(this.displayName, this.value);
}

/// App configuration constants
class AppConfig {
  AppConfig._();

  // Firebase collection paths
  static const String usersCollection = 'users';
  static const String storiesProgressCollection = 'stories_progress';
  static const String pollVotesCollection = 'poll_votes';
  static const String pollAggregatesCollection = 'poll_aggregates';
  static const String assessmentResultsCollection = 'assessment_results';
  static const String journeyProgressCollection = 'journey_progress';
  static const String sessionResponsesCollection = 'session_responses';

  // Nested field for Nexus 2.0 data
  static const String nexus2Field = 'nexus2';

  // Asset paths
  static const String assessmentsConfigPath = 'assets/config/assessments';
  static const String journeysConfigPath = 'assets/config/journeys';
  static const String engagementConfigPath = 'assets/config/engagement';
  static const String onboardingConfigPath =
      'assets/config/onboarding/nexus1_onboarding_lists_v1.json';
  static const String churchesConfigPath =
      'assets/config/onboarding/churches_v1.json';

  // Config file names
  static const String singlesReadinessConfig = 'singles_readiness_v1.json';
  static const String remarriageReadinessConfig =
      'remarriage_readiness_v1.json';
  static const String marriageHealthCheckConfig =
      'marriage_health_check_v1.json';
  static const String storiesConfig = 'stories_v1.json';
  static const String pollsConfig = 'polls_v1.json';

  // Journey config files by relationship status (v2 - separated by audience)
  static const String singlesNeverMarriedJourneyConfig =
      'journeys_single_never_married_v2.json';
  static const String divorcedWidowedJourneyConfig =
      'journeys_divorced_widowed_v2.json';
  static const String marriedJourneyConfig =
      'journeys_married_v2_parenting.json';

  // Legacy journey configs (deprecated - keep for migration)
  static const String legacySinglesJourneyConfig = 'singles_v1.json';
  static const String legacyMarriedJourneyConfig = 'married_v1.json';

  // Fallback path for singles when v2 is empty
  static const String singlesV1FallbackPath =
      '$journeysConfigPath/$legacySinglesJourneyConfig';

  // Full config paths - Assessments
  static const String singlesReadinessPath =
      '$assessmentsConfigPath/$singlesReadinessConfig';
  static const String remarriageReadinessPath =
      '$assessmentsConfigPath/$remarriageReadinessConfig';
  static const String marriageHealthCheckPath =
      '$assessmentsConfigPath/$marriageHealthCheckConfig';

  // Full config paths - Journeys (by relationship status)
  static const String singlesNeverMarriedJourneyPath =
      '$journeysConfigPath/$singlesNeverMarriedJourneyConfig';
  static const String divorcedWidowedJourneyPath =
      '$journeysConfigPath/$divorcedWidowedJourneyConfig';
  static const String marriedJourneyPath =
      '$journeysConfigPath/$marriedJourneyConfig';

  // Full config paths - Engagement
  static const String storiesPath = '$engagementConfigPath/$storiesConfig';
  static const String pollsPath = '$engagementConfigPath/$pollsConfig';

  // Assessment configuration
  static const int assessmentQuestionCount = 20;
  static const int maxScorePerQuestion = 3;
  static const int maxTotalScore =
      assessmentQuestionCount * maxScorePerQuestion;

  // Scoring thresholds (percentage based)
  static const double strongThreshold = 0.75; // 75%+
  static const double developingThreshold = 0.50; // 50-74%
  static const double guardedThreshold = 0.25; // 25-49%
  // Below 25% = At-Risk

  // Session configuration
  static const int maxShortTextChars = 280;
  static const int maxOneSentenceChars = 140;
  static const int maxReflectionChars = 200;

  // Story configuration
  static const int minReadingTimeMins = 2;
  static const int maxReadingTimeMins = 5;
  static const int maxKeyLessons = 5;
  static const int maxReflectionPrompts = 2;

  // Poll configuration
  static const int maxPollOptions = 4;
  static const int minPollOptions = 3;

  // Streak & Gamification
  static const int streakResetDays = 2;
  static const int minStreakForBadge = 3;

  // Schema version
  static const int nexus2SchemaVersion = 1;
}

// ============================================================================
// NAVIGATION CONFIGURATION
// ============================================================================

/// Navigation tab identifiers - ADD NEW TABS HERE
enum NavTab { home, search, chats, stories, challenges, profile }

/// Configuration for a navigation tab
class NavTabConfig {
  final NavTab id;
  final String label;
  final String iconName; // Semantic icon name (for Figma mapping)
  final String activeIconName; // Active state icon name
  final String route;
  final bool supportsBadge;

  const NavTabConfig({
    required this.id,
    required this.label,
    required this.iconName,
    required this.activeIconName,
    required this.route,
    this.supportsBadge = false,
  });
}

/// Navigation configuration - EDIT THIS TO CHANGE NAV BARS
///
/// To add a new tab:
/// 1. Add to NavTab enum above
/// 2. Add config to allTabs map below
/// 3. Add to appropriate tab list (singlesTabs/marriedTabs)

class AppNavRoutes {
  AppNavRoutes._();

  // Dynamic route helpers (deterministic, no string concatenation elsewhere)
  static String chat(String chatId) => '/chats/$chatId';
  static String profileView(String userId) => '/profile/$userId';
  static String journey(String productId) => '/journey/$productId';
  static String journeySession(String productId, int sessionNumber) =>
      '/journey/$productId/session/$sessionNumber';
  static String story(String storyId) => '/story/$storyId';
  static String storyPoll(String storyId) => '/story/$storyId/poll';

  static const String root = '/';

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String survey = '/survey';

  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  static const String home = '/home';
  static const String search = '/search';
  static const String chats = '/chats';
  static const String challenges = '/challenges';
  static const String stories = '/stories';
  static const String profile = '/profile';

  static const String notifications = '/notifications';
  static const String contactSupport = '/contact-support';

  static const String assessment = '/assessment';
  static const String assessmentResult = '/assessment/result';

  static const String editProfile = '/profile/edit';
  static const String settings = '/profile/settings';
  static const String savedStories = '/profile/saved-stories';
  static const String myProgress = '/profile/progress';
}

class NavConfig {
  NavConfig._();

  /// All available tabs configuration
  static const Map<NavTab, NavTabConfig> allTabs = {
    NavTab.home: NavTabConfig(
      id: NavTab.home,
      label: 'Home',
      iconName: 'home_outlined',
      activeIconName: 'home_filled',
      route: AppNavRoutes.home,
    ),
    NavTab.search: NavTabConfig(
      id: NavTab.search,
      label: 'Search',
      iconName: 'search_outlined',
      activeIconName: 'search_filled',
      route: AppNavRoutes.search,
    ),
    NavTab.chats: NavTabConfig(
      id: NavTab.chats,
      label: 'Chats',
      iconName: 'chat_outlined',
      activeIconName: 'chat_filled',
      route: AppNavRoutes.chats,
      supportsBadge: true,
    ),
    NavTab.stories: NavTabConfig(
      id: NavTab.stories,
      label: 'Stories',
      iconName: 'stories_outlined',
      activeIconName: 'stories_filled',
      route: AppNavRoutes.stories,
      supportsBadge: true,
    ),
    NavTab.challenges: NavTabConfig(
      id: NavTab.challenges,
      label: 'Challenges',
      iconName: 'challenges_outlined',
      activeIconName: 'challenges_filled',
      route: AppNavRoutes.challenges,
    ),
    NavTab.profile: NavTabConfig(
      id: NavTab.profile,
      label: 'Profile',
      iconName: 'profile_outlined',
      activeIconName: 'profile_filled',
      route: AppNavRoutes.profile,
    ),
  };

  /// Tabs for singles (never married, divorced, widowed)
  /// MODIFY THIS LIST TO CHANGE SINGLES NAV BAR ORDER/ITEMS
  static const List<NavTab> singlesTabs = [
    NavTab.home,
    NavTab.search,
    NavTab.chats,
    NavTab.challenges,
    NavTab.profile,
  ];

  /// Tabs for married users
  /// MODIFY THIS LIST TO CHANGE MARRIED NAV BAR ORDER/ITEMS
  static const List<NavTab> marriedTabs = [
    NavTab.home,
    NavTab.stories,
    NavTab.challenges,
    NavTab.profile,
  ];

  /// Get tabs for a given relationship status
  static List<NavTabConfig> getTabsForStatus(RelationshipStatus? status) {
    final tabIds = switch (status) {
      RelationshipStatus.singleNeverMarried => singlesTabs,
      RelationshipStatus.divorced || RelationshipStatus.widowed => singlesTabs,
      RelationshipStatus.married => marriedTabs,
      null => singlesTabs, // Default to singles if unknown
    };

    return tabIds.map((id) => allTabs[id]).whereType<NavTabConfig>().toList();
  }

  /// Check if a tab should be visible for a status
  static bool isTabVisible(NavTab tab, RelationshipStatus? status) {
    final tabs = getTabsForStatus(status);
    return tabs.any((config) => config.id == tab);
  }
}

// ============================================================================
// SURVEY CONFIGURATION
// ============================================================================

/// Generic survey option - can be used for any selection type
class SurveyOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final String? iconName; // Semantic icon name for Figma mapping
  final bool enabled;

  const SurveyOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.iconName,
    this.enabled = true,
  });
}

/// Survey configuration - EDIT THIS TO CHANGE SURVEY OPTIONS
///
/// All survey options are defined here for easy modification.
/// When Figma designs are ready, just update the labels/icons.
class SurveyConfig {
  SurveyConfig._();

  // ---------------------------------------------------------------------------
  // RELATIONSHIP STATUS OPTIONS
  // ---------------------------------------------------------------------------

  /// MODIFY THIS LIST TO CHANGE RELATIONSHIP STATUS OPTIONS
  static const List<SurveyOption<RelationshipStatus>>
  relationshipStatusOptions = [
    SurveyOption(
      value: RelationshipStatus.singleNeverMarried,
      label: 'Single (Never Married)',
      subtitle: 'Looking for meaningful connection',
      iconName: 'person_single',
    ),
    SurveyOption(
      value: RelationshipStatus.divorced,
      label: 'Divorced or Widowed',
      subtitle: 'Ready for a fresh start',
      iconName: 'person_refresh',
    ),
    SurveyOption(
      value: RelationshipStatus.married,
      label: 'Married',
      subtitle: 'Growing together in faith',
      iconName: 'couple',
    ),
  ];

  // ---------------------------------------------------------------------------
  // GENDER OPTIONS
  // ---------------------------------------------------------------------------

  /// MODIFY THIS LIST TO CHANGE GENDER OPTIONS
  static const List<SurveyOption<Gender>> genderOptions = [
    SurveyOption(value: Gender.male, label: 'Male', iconName: 'gender_male'),
    SurveyOption(
      value: Gender.female,
      label: 'Female',
      iconName: 'gender_female',
    ),
  ];

  // ---------------------------------------------------------------------------
  // GOAL OPTIONS BY RELATIONSHIP STATUS
  // ---------------------------------------------------------------------------

  /// Maximum number of goals a user can select
  static const int maxGoalSelections = 3;

  /// Get goals for a specific relationship status
  static List<SurveyOption<UserGoal>> getGoalsForStatus(
    RelationshipStatus status,
  ) {
    return switch (status) {
      RelationshipStatus.singleNeverMarried => singlesGoalOptions,
      RelationshipStatus.divorced ||
      RelationshipStatus.widowed => divorcedWidowedGoalOptions,
      RelationshipStatus.married => marriedGoalOptions,
    };
  }

  /// MODIFY THIS LIST TO CHANGE SINGLES GOAL OPTIONS
  static const List<SurveyOption<UserGoal>> singlesGoalOptions = [
    SurveyOption(
      value: UserGoal.findPartnerDating,
      label: 'Find a Life Partner',
      subtitle: 'Meet someone who shares your faith',
      iconName: 'heart_search',
    ),
    SurveyOption(
      value: UserGoal.takeReadinessTest,
      label: 'Check My Readiness',
      subtitle: 'Take the free assessment',
      iconName: 'clipboard_check',
    ),
    SurveyOption(
      value: UserGoal.prepareForMarriage,
      label: 'Prepare for Marriage',
      subtitle: 'Build a strong foundation',
      iconName: 'foundation',
    ),
    SurveyOption(
      value: UserGoal.buildEmotionalHealth,
      label: 'Build Emotional Health',
      subtitle: 'Develop healthy relationship habits',
      iconName: 'mental_health',
    ),
    SurveyOption(
      value: UserGoal.healingFamilyPatterns,
      label: 'Heal from Past Patterns',
      subtitle: 'Break unhealthy cycles',
      iconName: 'healing',
    ),
  ];

  /// MODIFY THIS LIST TO CHANGE DIVORCED/WIDOWED GOAL OPTIONS
  static const List<SurveyOption<UserGoal>> divorcedWidowedGoalOptions = [
    SurveyOption(
      value: UserGoal.healFromPast,
      label: 'Heal and Recover',
      subtitle: 'Process your journey',
      iconName: 'healing',
    ),
    SurveyOption(
      value: UserGoal.remarriageReadiness,
      label: 'Check Remarriage Readiness',
      subtitle: 'Take the free assessment',
      iconName: 'clipboard_check',
    ),
    SurveyOption(
      value: UserGoal.findPartnerDating,
      label: 'Find Love Again',
      subtitle: 'When you\'re ready',
      iconName: 'heart_search',
    ),
    SurveyOption(
      value: UserGoal.restoreSelf,
      label: 'Rebuild Confidence',
      subtitle: 'Rediscover your worth',
      iconName: 'confidence',
    ),
    SurveyOption(
      value: UserGoal.blendedFamilyPrep,
      label: 'Prepare for Blended Family',
      subtitle: 'Navigate family dynamics',
      iconName: 'family_blend',
    ),
  ];

  /// MODIFY THIS LIST TO CHANGE MARRIED GOAL OPTIONS
  static const List<SurveyOption<UserGoal>> marriedGoalOptions = [
    SurveyOption(
      value: UserGoal.strengthenBond,
      label: 'Strengthen Our Marriage',
      subtitle: 'Deepen your connection',
      iconName: 'heart_strong',
    ),
    SurveyOption(
      value: UserGoal.improveComms,
      label: 'Improve Communication',
      subtitle: 'Understand each other better',
      iconName: 'communication',
    ),
    SurveyOption(
      value: UserGoal.conflictResolution,
      label: 'Resolve Conflicts Better',
      subtitle: 'Handle disagreements with grace',
      iconName: 'handshake',
    ),
    SurveyOption(
      value: UserGoal.restoreIntimacy,
      label: 'Deepen Intimacy',
      subtitle: 'Grow closer together',
      iconName: 'intimacy',
    ),
    SurveyOption(
      value: UserGoal.marriageHealthCheck,
      label: 'Check Marriage Health',
      subtitle: 'Take the free assessment',
      iconName: 'clipboard_check',
    ),
    SurveyOption(
      value: UserGoal.raisingKids,
      label: 'Raise Godly Children',
      subtitle: 'Parent as a team',
      iconName: 'family',
    ),
  ];
}
