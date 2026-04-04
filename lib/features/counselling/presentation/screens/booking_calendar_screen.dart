import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';
import '../widgets/time_slot_chip.dart';
import 'booking_summary_screen.dart';

class BookingCalendarScreen extends ConsumerStatefulWidget {
  final CoachModel coach;
  final SessionType sessionType;

  const BookingCalendarScreen({
    super.key,
    required this.coach,
    required this.sessionType,
  });

  @override
  ConsumerState<BookingCalendarScreen> createState() =>
      _BookingCalendarScreenState();
}

class _BookingCalendarScreenState
    extends ConsumerState<BookingCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  TimeSlotModel? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final slotsAsync =
        ref.watch(availableSlotsProvider(widget.coach.id));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Date & Time',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              widget.coach.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: slotsAsync.when(
        loading: () => const _CalendarSkeleton(),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (slots) {
          // Group slots by date
          final slotsByDate = <DateTime, List<TimeSlotModel>>{};
          for (final slot in slots) {
            final d = slot.dateTime;
            final normalized = DateTime(d.year, d.month, d.day);
            slotsByDate.putIfAbsent(normalized, () => []).add(slot);
          }

          // Filter to session type
          final filteredByDate = <DateTime, List<TimeSlotModel>>{};
          slotsByDate.forEach((date, daySlots) {
            final filtered = daySlots
                .where((s) =>
                    s.supportsSessionType(widget.sessionType.firestoreKey))
                .toList();
            if (filtered.isNotEmpty) filteredByDate[date] = filtered;
          });

          final selectedDaySlots = _selectedDate != null
              ? (filteredByDate[_selectedDate] ?? [])
              : <TimeSlotModel>[];

          return Column(
            children: [
              // Month calendar — fixed
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _MonthCalendar(
                  focusedMonth: _focusedMonth,
                  availableDates: filteredByDate.keys.toSet(),
                  selectedDate: _selectedDate,
                  onDateSelected: (date) => setState(() {
                    _selectedDate = date;
                    _selectedSlot = null;
                  }),
                  onMonthChanged: (month) =>
                      setState(() => _focusedMonth = month),
                ),
              ),

              // Scrollable slots area — fills remaining space, never overflows
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: _selectedDate != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    color: AppColors.primary, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Available times on ${DateFormat('EEEE, d MMMM').format(_selectedDate!)}',
                                    style: AppTextStyles.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (selectedDaySlots.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(14),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'All slots on this day have been booked.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color:
                                        AppColors.getTextSecondary(context),
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: selectedDaySlots.map((slot) {
                                  return TimeSlotChip(
                                    slot: slot,
                                    isSelected: _selectedSlot?.id == slot.id,
                                    onTap: () =>
                                        setState(() => _selectedSlot = slot),
                                  );
                                }).toList(),
                              ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Text(
                            'Select a highlighted date above to see available times.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),

              // CTA
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedSlot != null
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookingSummaryScreen(
                                    coach: widget.coach,
                                    sessionType: widget.sessionType,
                                    slot: _selectedSlot!,
                                  ),
                                ),
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.getTextSecondary(
                                context)
                            .withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _selectedSlot != null
                            ? 'Continue — ${_selectedSlot!.formattedStart}'
                            : 'Select a time slot',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: _selectedSlot != null
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Calendar Skeleton (shown while slots are loading) ─────────────────────────

class _CalendarSkeleton extends StatefulWidget {
  const _CalendarSkeleton();

  @override
  State<_CalendarSkeleton> createState() => _CalendarSkeletonState();
}

class _CalendarSkeletonState extends State<_CalendarSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _fade = Tween(begin: 0.35, end: 0.75)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) {
        final base = AppColors.getSurface(context);
        final color = base.withOpacity(_fade.value);

        Widget bone(double w, double h, {double r = 10}) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(r),
              ),
            );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar block placeholder
              bone(double.infinity, 260, r: 14),
              const SizedBox(height: 18),
              // "Available times on …" label
              bone(180, 12),
              const SizedBox(height: 12),
              // Grid of chip placeholders
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  6,
                  (_) => bone(90, 52, r: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Month Calendar ────────────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final Set<DateTime> availableDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _MonthCalendar({
    required this.focusedMonth,
    required this.availableDates,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);
    final startPad = firstDay.weekday % 7; // Sunday = 0
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Month header with navigation
          Row(
            children: [
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month - 1),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(focusedMonth),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => onMonthChanged(
                  DateTime(focusedMonth.year, focusedMonth.month + 1),
                ),
                icon: const Icon(Icons.chevron_right_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Day-of-week headers
          Row(
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 2),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: startPad + lastDay.day,
            itemBuilder: (context, i) {
              if (i < startPad) return const SizedBox.shrink();
              final day = i - startPad + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);
              final normalized = DateTime(date.year, date.month, date.day);
              final isToday = normalized ==
                  DateTime(today.year, today.month, today.day);
              final isAvailable = availableDates.contains(normalized);
              final isSelected = selectedDate != null &&
                  selectedDate == normalized;
              final isPast = date.isBefore(
                  DateTime(today.year, today.month, today.day));

              return GestureDetector(
                onTap: isAvailable && !isPast
                    ? () => onDateSelected(normalized)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isPast
                                  ? AppColors.getTextSecondary(context)
                                      .withOpacity(0.3)
                                  : isAvailable
                                      ? AppColors.getTextPrimary(context)
                                      : AppColors.getTextSecondary(context)
                                          .withOpacity(0.4),
                        ),
                      ),
                      // Availability dot
                      if (isAvailable && !isPast && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Available',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
