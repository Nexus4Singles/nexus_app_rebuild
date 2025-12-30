import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../constants/app_constants.dart';

// ============================================================================
// ICON MAPPING
// ============================================================================

/// Maps semantic icon names to Material Icons
/// 
/// When Figma designs are ready:
/// 1. Replace Material Icons with custom icon assets
/// 2. Or create an IconMapper that loads from assets
/// 
/// This abstraction makes icon changes a single-file update.
class AppIcons {
  AppIcons._();
  
  /// Get icon from semantic name (outlined/inactive state)
  static IconData getOutlined(String name) {
    return _outlinedIcons[name] ?? Icons.circle_outlined;
  }
  
  /// Get icon from semantic name (filled/active state)
  static IconData getFilled(String name) {
    return _filledIcons[name] ?? Icons.circle;
  }
  
  // Outlined (inactive) icons
  static const Map<String, IconData> _outlinedIcons = {
    // Navigation
    'home_outlined': Icons.home_outlined,
    'search_outlined': Icons.search,
    'chat_outlined': Icons.chat_bubble_outline,
    'stories_outlined': Icons.auto_stories_outlined,
    'challenges_outlined': Icons.fitness_center_outlined,
    'profile_outlined': Icons.person_outline,
    
    // Survey & general
    'person_single': Icons.person_outline,
    'person_refresh': Icons.refresh,
    'couple': Icons.favorite_border,
    'gender_male': Icons.male,
    'gender_female': Icons.female,
    
    // Goals
    'heart_search': Icons.favorite_border,
    'clipboard_check': Icons.assignment_outlined,
    'foundation': Icons.foundation_outlined,
    'mental_health': Icons.psychology_outlined,
    'healing': Icons.healing_outlined,
    'confidence': Icons.emoji_emotions_outlined,
    'family_blend': Icons.family_restroom_outlined,
    'heart_strong': Icons.favorite_outline,
    'communication': Icons.chat_outlined,
    'handshake': Icons.handshake_outlined,
    'intimacy': Icons.volunteer_activism_outlined,
    'family': Icons.family_restroom_outlined,
  };
  
  // Filled (active) icons
  static const Map<String, IconData> _filledIcons = {
    // Navigation
    'home_filled': Icons.home,
    'search_filled': Icons.search,
    'chat_filled': Icons.chat_bubble,
    'stories_filled': Icons.auto_stories,
    'challenges_filled': Icons.fitness_center,
    'profile_filled': Icons.person,
    
    // General
    'person_single': Icons.person,
    'person_refresh': Icons.refresh,
    'couple': Icons.favorite,
    'gender_male': Icons.male,
    'gender_female': Icons.female,
    
    // Goals (same as outlined for now)
    'heart_search': Icons.favorite,
    'clipboard_check': Icons.assignment,
    'foundation': Icons.foundation,
    'mental_health': Icons.psychology,
    'healing': Icons.healing,
    'confidence': Icons.emoji_emotions,
    'family_blend': Icons.family_restroom,
    'heart_strong': Icons.favorite,
    'communication': Icons.chat,
    'handshake': Icons.handshake,
    'intimacy': Icons.volunteer_activism,
    'family': Icons.family_restroom,
  };
}

// ============================================================================
// NAV BAR THEME TOKENS
// ============================================================================

/// Theme tokens for bottom nav bar - easy to update for Figma
/// 
/// When Figma designs are ready, update these values.
class NavBarTokens {
  NavBarTokens._();
  
  // Layout
  static const double height = 64.0;
  static const double iconSize = 24.0;
  static const double iconContainerSize = 40.0;
  static const double labelFontSize = 11.0;
  static const double labelSpacing = 2.0;
  
  // Badge
  static const double badgeSize = 16.0;
  static const double badgeFontSize = 10.0;
  static const double badgeBorderWidth = 2.0;
  
  // Animation
  static const Duration animationDuration = Duration(milliseconds: 200);
  
  // Colors (reference from theme)
  static Color get activeColor => AppColors.primary;
  static Color get inactiveColor => AppColors.textMuted;
  static Color get backgroundColor => AppColors.surfaceLight;
  static Color get badgeColor => AppColors.secondary;
  static Color get activeBackgroundColor => AppColors.primary.withOpacity(0.1);
}

// ============================================================================
// BOTTOM NAV BAR WIDGET
// ============================================================================

/// Config-driven bottom navigation bar
/// 
/// Automatically adjusts tabs based on user's relationship status.
/// Uses NavConfig from app_constants.dart to determine which tabs to show.
class AppBottomNavBar extends StatelessWidget {
  /// Current selected tab index
  final int currentIndex;
  
  /// Callback when a tab is tapped
  final ValueChanged<int> onTap;
  
  /// User's relationship status (determines which tabs to show)
  final RelationshipStatus? userStatus;
  
  /// Badge counts for tabs that support badges (keyed by NavTab)
  final Map<NavTab, int>? badgeCounts;
  
  /// Whether to show badge dots (without count) for specific tabs
  final Set<NavTab>? showBadgeDots;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.userStatus,
    this.badgeCounts,
    this.showBadgeDots,
  });

  @override
  Widget build(BuildContext context) {
    // Get tabs for user's status from config
    final tabs = NavConfig.getTabsForStatus(userStatus);

    return Container(
      decoration: BoxDecoration(
        color: NavBarTokens.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: NavBarTokens.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tabConfig = entry.value;
              final isActive = index == currentIndex;
              
              // Check for badge
              final badgeCount = badgeCounts?[tabConfig.id];
              final showDot = showBadgeDots?.contains(tabConfig.id) ?? false;
              final showBadge = tabConfig.supportsBadge && (badgeCount != null || showDot);

              return Expanded(
                child: _NavBarItem(
                  config: tabConfig,
                  isActive: isActive,
                  badgeCount: badgeCount,
                  showBadge: showBadge,
                  onTap: () => onTap(index),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  /// Get the route for a given tab index
  String? getRouteForIndex(int index) {
    final tabs = NavConfig.getTabsForStatus(userStatus);
    if (index < 0 || index >= tabs.length) return null;
    return tabs[index].route;
  }
  
  /// Get the index for a given route
  int? getIndexForRoute(String route) {
    final tabs = NavConfig.getTabsForStatus(userStatus);
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].route == route) return i;
    }
    return null;
  }
}

// ============================================================================
// NAV BAR ITEM
// ============================================================================

class _NavBarItem extends StatelessWidget {
  final NavTabConfig config;
  final bool isActive;
  final int? badgeCount;
  final bool showBadge;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.config,
    required this.isActive,
    required this.onTap,
    this.badgeCount,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? NavBarTokens.activeColor : NavBarTokens.inactiveColor;
    final icon = isActive 
        ? AppIcons.getFilled(config.activeIconName)
        : AppIcons.getOutlined(config.iconName);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with optional badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Icon container with active background
              AnimatedContainer(
                duration: NavBarTokens.animationDuration,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive 
                      ? NavBarTokens.activeBackgroundColor 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: NavBarTokens.iconSize,
                ),
              ),
              // Badge
              if (showBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _Badge(count: badgeCount),
                ),
            ],
          ),
          SizedBox(height: NavBarTokens.labelSpacing),
          // Label
          Text(
            config.label,
            style: TextStyle(
              fontSize: NavBarTokens.labelFontSize,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BADGE
// ============================================================================

class _Badge extends StatelessWidget {
  final int? count;

  const _Badge({this.count});

  @override
  Widget build(BuildContext context) {
    final hasCount = count != null && count! > 0;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hasCount ? 5 : 0,
        vertical: 2,
      ),
      constraints: BoxConstraints(
        minWidth: NavBarTokens.badgeSize,
        minHeight: NavBarTokens.badgeSize,
      ),
      decoration: BoxDecoration(
        color: NavBarTokens.badgeColor,
        borderRadius: BorderRadius.circular(NavBarTokens.badgeSize / 2),
        border: Border.all(
          color: NavBarTokens.backgroundColor, 
          width: NavBarTokens.badgeBorderWidth,
        ),
      ),
      child: hasCount
          ? Text(
              count! > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: NavBarTokens.badgeFontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            )
          : null,
    );
  }
}

// ============================================================================
// SCAFFOLD WITH NAV BAR
// ============================================================================

/// Convenience widget that wraps Scaffold with AppBottomNavBar
/// 
/// Use this for main screens to ensure consistent nav bar behavior.
class AppScaffoldWithNav extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final RelationshipStatus? userStatus;
  final Map<NavTab, int>? badgeCounts;
  final Set<NavTab>? showBadgeDots;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final Color? backgroundColor;

  const AppScaffoldWithNav({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onNavTap,
    this.userStatus,
    this.badgeCounts,
    this.showBadgeDots,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: currentIndex,
        onTap: onNavTap,
        userStatus: userStatus,
        badgeCounts: badgeCounts,
        showBadgeDots: showBadgeDots,
      ),
    );
  }
}
