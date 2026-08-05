import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import '../../application/dating_preferences_provider.dart';
import '../../application/market_country_utils.dart';
import '../../application/market_phase_provider.dart';
import 'dating_preferences_setup_screen.dart';

DateTime resolveLaunchDateForUkMarket(
  DateTime? marketLaunchDate, {
  DateTime? now,
}) {
  if (marketLaunchDate != null) {
    return marketLaunchDate;
  }

  return _WaitingListScreenState._defaultLaunchDate;
}

class CountdownValue {
  final int days;
  final int hours;
  final int minutes;

  const CountdownValue({
    required this.days,
    required this.hours,
    required this.minutes,
  });
}

CountdownValue calculateLaunchCountdown(DateTime launchDate, DateTime now) {
  final nowUtc = now.toUtc();
  final launchUtc = launchDate.toUtc();
  final remaining =
      launchUtc.isAfter(nowUtc) ? launchUtc.difference(nowUtc) : Duration.zero;

  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  return CountdownValue(days: days, hours: hours, minutes: minutes);
}

/// Premium waiting list screen for UK launch
/// World-class design with animations, gradients, and dark mode support
class WaitingListScreen extends ConsumerStatefulWidget {
  const WaitingListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends ConsumerState<WaitingListScreen>
    with SingleTickerProviderStateMixin {
  static final DateTime _defaultLaunchDate = DateTime(2026, 9, 5);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _countdownTimer;

  /// Get responsive sizes based on screen width
  double _getResponsiveValue(
    BuildContext context, {
    required double small,
    required double large,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 375) {
      return small;
    } else if (width > 600) {
      return large;
    }
    return small + (large - small) * ((width - 375) / 225);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Update countdown every second for real-time updates
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketDataAsync = ref.watch(marketPhaseProvider('uk'));
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 420;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Stack(
          children: [
            // Animated background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.getBackground(context),
                  ],
                ),
              ),
            ),
            // Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 14 : 18,
                        vertical: isCompact ? 10 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: isCompact ? 8 : 12),
                          // Hero icon with pulse animation
                          _buildAnimatedHeroIcon(context),
                          SizedBox(height: isCompact ? 16 : 22),

                          // Main headline - responsive
                          Text(
                            'You\'re On The WaitList!',
                            style: TextStyle(
                              fontSize: _getResponsiveValue(
                                context,
                                small: 22,
                                large: 30,
                              ),
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isCompact ? 6 : 10),

                          // Subheadline - responsive
                          Text(
                            'You will be able to view profiles as soon as we launch',
                            style: TextStyle(
                              fontSize: _getResponsiveValue(
                                context,
                                small: 12,
                                large: 14,
                              ),
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isCompact ? 20 : 28),

                          // Launch countdown card - uses dynamic market launch date
                          marketDataAsync.when(
                            data:
                                (market) =>
                                    _buildLaunchCountdownCard(context, market),
                            loading:
                                () => SizedBox(
                                  height: isCompact ? 180 : 200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            error:
                                (e, _) => Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Text('Error loading launch date: $e'),
                                ),
                          ),
                          SizedBox(height: isCompact ? 28 : 36),

                          // What to expect section
                          _buildWhatToExpectSection(context),
                          SizedBox(height: isCompact ? 28 : 36),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeroIcon(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final iconSize = _getResponsiveValue(
      context,
      small: width < 420 ? 64 : 80,
      large: 110,
    );
    final iconInnerSize = iconSize * 0.52; // 52% of container size

    return Center(
      child: Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.24),
              blurRadius: width < 420 ? 16 : 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          Icons.favorite_rounded,
          size: iconInnerSize,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLaunchCountdownCard(BuildContext context, MarketData? market) {
    final launchDate = resolveLaunchDateForUkMarket(market?.launchDate);

    // Calculate countdown from launch date and clamp negative time to zero.
    final now = DateTime.now();
    final countdown = calculateLaunchCountdown(launchDate, now);
    final days = countdown.days.toString().padLeft(2, '0');
    final hours = countdown.hours.toString().padLeft(2, '0');
    final minutes = countdown.minutes.toString().padLeft(2, '0');

    // Format launch date as "5 September 2026" (no timestamp)
    final launchDateFormatted = _formatLaunchDate(launchDate);

    final isCompact = MediaQuery.of(context).size.width < 420;
    return Container(
      padding: EdgeInsets.all(
        _getResponsiveValue(context, small: isCompact ? 12 : 16, large: 20),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.24),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: isCompact ? 14 : 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Label - responsive
          Text(
            'Launching In',
            style: TextStyle(
              fontSize: _getResponsiveValue(context, small: 10, large: 12),
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: _getResponsiveValue(context, small: 8, large: 12)),
          // Countdown units - responsive
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCountdownUnit(context, '$days', 'Days'),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _getResponsiveValue(context, small: 5, large: 10),
                ),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: _getResponsiveValue(
                      context,
                      small: 24,
                      large: 34,
                    ),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildCountdownUnit(
                context,
                hours.toString().padLeft(2, '0'),
                'Hrs',
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _getResponsiveValue(context, small: 5, large: 10),
                ),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: _getResponsiveValue(
                      context,
                      small: 24,
                      large: 34,
                    ),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildCountdownUnit(
                context,
                minutes.toString().padLeft(2, '0'),
                'Mins',
              ),
            ],
          ),
          SizedBox(height: _getResponsiveValue(context, small: 14, large: 20)),
          // Bold, red launch date (no timestamp) - world class design
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _getResponsiveValue(context, small: 12, large: 18),
              vertical: _getResponsiveValue(context, small: 8, large: 12),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.secondary.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Text(
              launchDateFormatted,
              style: TextStyle(
                fontSize: _getResponsiveValue(context, small: 14, large: 18),
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Format launch date as "22 June 2026" (without timestamp)
  String _formatLaunchDate(DateTime date) {
    final months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Widget _buildCountdownUnit(BuildContext context, String value, String label) {
    final containerWidth = _getResponsiveValue(context, small: 40, large: 52);
    final valueFontSize = _getResponsiveValue(context, small: 16, large: 20);
    final labelFontSize = _getResponsiveValue(context, small: 9, large: 11);

    return Column(
      children: [
        Container(
          width: containerWidth,
          padding: EdgeInsets.symmetric(
            horizontal: _getResponsiveValue(context, small: 5, large: 8),
            vertical: _getResponsiveValue(context, small: 6, large: 8),
          ),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: _getResponsiveValue(context, small: 4, large: 6)),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWhatToExpectSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final expectations = [
      (
        '🎯',
        '5 Daily Recommendations',
        'Recommended based on their compatibility score with yours',
      ),
      ('💬', 'Message Right Away', 'Start conversations with real users'),
      (
        '🔐',
        'Verified Profiles',
        'Everyone\'s identity verified, no fake profiles',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What to Expect',
          style: TextStyle(
            fontSize: _getResponsiveValue(
              context,
              small: width < 420 ? 15 : 17,
              large: 20,
            ),
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: width < 420 ? 10 : 14),
        ...expectations.asMap().entries.map((entry) {
          int index = entry.key;
          var (emoji, title, subtitle) = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: width < 420 ? 8 : 12),
            child: _buildExpectationItem(
              context,
              emoji,
              title,
              subtitle,
              index,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExpectationItem(
    BuildContext context,
    String emoji,
    String title,
    String subtitle,
    int index,
  ) {
    final emojiFontSize = _getResponsiveValue(context, small: 20, large: 26);
    final titleFontSize = _getResponsiveValue(context, small: 11, large: 13);
    final subtitleFontSize = _getResponsiveValue(context, small: 10, large: 12);

    return Container(
      padding: EdgeInsets.all(
        _getResponsiveValue(context, small: 8, large: 12),
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context), width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: emojiFontSize)),
          SizedBox(width: _getResponsiveValue(context, small: 8, large: 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: _getResponsiveValue(context, small: 2, large: 4),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
