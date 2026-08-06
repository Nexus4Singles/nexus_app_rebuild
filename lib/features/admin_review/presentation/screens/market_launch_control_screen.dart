import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/user/is_admin_provider.dart';

/// Market Launch Control Panel - Admin-only screen for controlling market launches
/// Allows admins to view market status, set launch dates, and trigger launches
class MarketLaunchControlScreen extends ConsumerStatefulWidget {
  const MarketLaunchControlScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MarketLaunchControlScreen> createState() =>
      _MarketLaunchControlScreenState();
}

class _MarketLaunchControlScreenState
    extends ConsumerState<MarketLaunchControlScreen> {
  String _selectedMarket = 'uk';
  DateTime? _selectedLaunchDate;
  TimeOfDay? _selectedLaunchTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLaunchDate = DateTime.now().add(const Duration(days: 14));
    _selectedLaunchTime = const TimeOfDay(hour: 14, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);

    if (!isAdmin) {
      return Scaffold(
        body: Center(
          child: Text(
            'Admin access required',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        title: Text(
          'Market Launch Control',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Market selector
            _buildMarketSelector(context),
            const SizedBox(height: 32),

            // Market status card
            _buildMarketStatusCard(context),
            const SizedBox(height: 32),

            // Launch date/time picker
            _buildLaunchDateTimeSection(context),
            const SizedBox(height: 32),

            // Action buttons
            _buildActionButtons(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketSelector(BuildContext context) {
    final markets = ['uk', 'nigeria', 'ghana'];
    final marketLabels = {
      'uk': '🇬🇧 United Kingdom',
      'nigeria': '🇳🇬 Nigeria',
      'ghana': '🇬🇭 Ghana',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Market',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(context), width: 1),
          ),
          child: DropdownButton<String>(
            value: _selectedMarket,
            isExpanded: true,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(12),
            dropdownColor: AppColors.getSurface(context),
            items:
                markets
                    .map(
                      (market) => DropdownMenuItem(
                        value: market,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            marketLabels[market] ?? market,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMarket = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMarketStatusCard(BuildContext context) {
    final fs = ref.watch(firestoreInstanceProvider);

    return StreamBuilder<DocumentSnapshot>(
      stream: fs?.collection('markets').doc(_selectedMarket).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(context), width: 1),
            ),
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Market Not Found',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No market configuration exists for $_selectedMarket',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          );
        }

        final phase = data['phase'] ?? 'unknown';
        final launchDate = data['launchDate'] as Timestamp?;
        final approvedCount = data['approvedProfileCount'] ?? 0;
        final gender = data['gender'] as Map<String, dynamic>? ?? {};
        final maleCount = gender['male'] ?? 0;
        final femaleCount = gender['female'] ?? 0;

        final phaseColor =
            phase == 'active'
                ? AppColors.success
                : phase == 'prelaunch'
                ? AppColors.warning
                : AppColors.info;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                phaseColor.withOpacity(0.1),
                phaseColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: phaseColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Status',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: phaseColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: phaseColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      phase.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: phaseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatusRow(context, 'Approved Profiles', '$approvedCount'),
              const SizedBox(height: 12),
              _buildStatusRow(
                context,
                'Gender Balance',
                '$maleCount♂ / $femaleCount♀',
              ),
              if (launchDate != null) ...[
                const SizedBox(height: 12),
                _buildStatusRow(
                  context,
                  'Scheduled Launch',
                  launchDate.toDate().toString().split('.')[0],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLaunchDateTimeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Launch Configuration',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeButton(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value:
                    _selectedLaunchDate != null
                        ? '${_selectedLaunchDate!.year}-${_selectedLaunchDate!.month.toString().padLeft(2, '0')}-${_selectedLaunchDate!.day.toString().padLeft(2, '0')}'
                        : 'Select Date',
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedLaunchDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedLaunchDate = date);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateTimeButton(
                context,
                icon: Icons.access_time_rounded,
                label: 'Time',
                value:
                    _selectedLaunchTime != null
                        ? _selectedLaunchTime!.format(context)
                        : 'Select Time',
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime:
                        _selectedLaunchTime ??
                        const TimeOfDay(hour: 14, minute: 0),
                  );
                  if (time != null) {
                    setState(() => _selectedLaunchTime = time);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Launch Now button
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _launchNow(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            disabledBackgroundColor: AppColors.success.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            _isLoading
                ? Icons.hourglass_bottom_rounded
                : Icons.rocket_launch_rounded,
          ),
          label: Text(
            _isLoading ? 'Launching...' : '🚀 Launch Now',
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Schedule Launch button
        OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _scheduleLaunch(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: AppColors.primary.withOpacity(0.5),
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.schedule_rounded),
          label: Text(
            '📅 Schedule Launch',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stay in Pre-Launch button
        OutlinedButton.icon(
          onPressed: _isLoading ? null : () => _cancelLaunch(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.getTextSecondary(context),
            side: BorderSide(color: AppColors.getBorder(context), width: 1),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.pause_circle_rounded),
          label: Text(
            '⏸ Stay in Pre-Launch',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.getTextSecondary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchNow(BuildContext context) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('🚀 Launch Immediately?'),
            content: Text(
              'This will activate $_selectedMarket market immediately. All approved profiles will go live.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text('Launch Now'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final fs = ref.read(firestoreInstanceProvider);
      await fs?.collection('markets').doc(_selectedMarket).update({
        'phase': 'active',
        'launchDate': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $_selectedMarket market launched successfully!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Launch failed: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scheduleLaunch(BuildContext context) async {
    if (_selectedLaunchDate == null || _selectedLaunchTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both date and time'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final launchDateTime = DateTime(
        _selectedLaunchDate!.year,
        _selectedLaunchDate!.month,
        _selectedLaunchDate!.day,
        _selectedLaunchTime!.hour,
        _selectedLaunchTime!.minute,
      );

      final nowUtc = DateTime.now().toUtc();
      final launchDateTimeUtc = launchDateTime.toUtc();
      if (!launchDateTimeUtc.isAfter(nowUtc)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose a future launch date and time.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      final fs = ref.read(firestoreInstanceProvider);
      final marketDoc = await fs?.collection('markets').doc(_selectedMarket).get();
      final existingLaunchDate = marketDoc?.data()?['launchDate'] as Timestamp?;

      if (existingLaunchDate != null) {
        final currentLaunchDateUtc = existingLaunchDate.toDate().toUtc();
        if (launchDateTimeUtc.isBefore(currentLaunchDateUtc)) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm earlier launch date'),
              content: Text(
                'The selected launch date is earlier than the currently scheduled launch date (${existingLaunchDate.toDate().toUtc()}).\n\nAre you sure you want to move it earlier?',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          );

          if (confirmed != true) {
            return;
          }
        }
      }

      await fs?.collection('markets').doc(_selectedMarket).update({
        'phase': 'prelaunch',
        'launchDate': Timestamp.fromDate(launchDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📅 Launch scheduled for ${launchDateTime.toString().split('.')[0]} UTC',
          ),
          backgroundColor: AppColors.info,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Schedule failed: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelLaunch(BuildContext context) async {
    setState(() => _isLoading = true);

    try {
      final fs = ref.read(firestoreInstanceProvider);
      await fs?.collection('markets').doc(_selectedMarket).update({
        'phase': 'prelaunch',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏸ Staying in pre-launch mode'),
          backgroundColor: AppColors.info,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Update failed: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
