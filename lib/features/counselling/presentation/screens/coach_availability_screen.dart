import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../application/coach_service.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';

class CoachAvailabilityScreen extends ConsumerStatefulWidget {
  final CoachModel coach;

  const CoachAvailabilityScreen({super.key, required this.coach});

  @override
  ConsumerState<CoachAvailabilityScreen> createState() =>
      _CoachAvailabilityScreenState();
}

class _CoachAvailabilityScreenState
    extends ConsumerState<CoachAvailabilityScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(allCoachSlotsProvider(widget.coach.id));

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
        title: Text(
          'Manage Availability',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSlotSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Time Slot'),
      ),
      body: slotsAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (slots) {
          // Build a map: dateKey → list of slots
          final Map<String, List<TimeSlotModel>> slotsByDate = {};
          for (final slot in slots) {
            final key = _dateKey(slot.dateTime);
            slotsByDate.putIfAbsent(key, () => []).add(slot);
          }

          final daySlots =
              _selectedDay != null
                  ? (slotsByDate[_dateKey(_selectedDay!)] ?? [])
                  : <TimeSlotModel>[];

          return Column(
            children: [
              // ── Calendar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _AvailabilityCalendar(
                  focusedMonth: _focusedMonth,
                  selectedDay: _selectedDay,
                  slotsByDate: slotsByDate,
                  onMonthChanged: (m) => setState(() => _focusedMonth = m),
                  onDaySelected: (d) => setState(() => _selectedDay = d),
                ),
              ),

              // ── Divider ──
              Divider(
                height: 1,
                color: AppColors.getTextSecondary(context).withOpacity(0.1),
              ),

              // ── Slots list ──
              Expanded(
                child:
                    _selectedDay == null
                        ? _NoSelectionHint()
                        : daySlots.isEmpty
                        ? _EmptyDay(
                          onAdd:
                              () => _showAddSlotSheet(
                                context,
                                preselectedDate: _selectedDay,
                              ),
                        )
                        : _SlotList(
                          slots: daySlots,
                          coachId: widget.coach.id,
                          onAdd:
                              () => _showAddSlotSheet(
                                context,
                                preselectedDate: _selectedDay,
                              ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _showAddSlotSheet(BuildContext context, {DateTime? preselectedDate}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _AddSlotSheet(
            coach: widget.coach,
            initialDate: preselectedDate ?? _selectedDay ?? DateTime.now(),
            onAdded: () {
              Navigator.of(context).pop();
              // refresh is automatic via Stream
            },
          ),
    );
  }
}

// ── Calendar ─────────────────────────────────────────────────────────────────

class _AvailabilityCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime? selectedDay;
  final Map<String, List<TimeSlotModel>> slotsByDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  const _AvailabilityCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.slotsByDate,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0

    final cells = <_DayCell>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(_DayCell.empty());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, d);
      final key = _dateKey(date);
      final slotsOnDay = slotsByDate[key] ?? [];
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isSelected =
          selectedDay != null &&
          date.year == selectedDay!.year &&
          date.month == selectedDay!.month &&
          date.day == selectedDay!.day;
      final isPast = date.isBefore(
        DateTime(today.year, today.month, today.day),
      );

      cells.add(
        _DayCell(
          day: d,
          date: date,
          slotCount: slotsOnDay.length,
          hasBooked: slotsOnDay.any((s) => s.isBooked),
          isToday: isToday,
          isSelected: isSelected,
          isPast: isPast,
        ),
      );
    }

    return Column(
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed:
                  () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month - 1),
                  ),
            ),
            Text(
              DateFormat('MMMM yyyy').format(focusedMonth),
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed:
                  () => onMonthChanged(
                    DateTime(focusedMonth.year, focusedMonth.month + 1),
                  ),
            ),
          ],
        ),
        // Weekday headers
        Row(
          children:
              ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 4),
        // Grid
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children:
              cells.map((cell) {
                if (cell.date == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => onDaySelected(cell.date!),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          cell.isSelected
                              ? AppColors.primary
                              : cell.isToday
                              ? AppColors.primary.withOpacity(0.1)
                              : null,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${cell.day}',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight:
                                cell.isToday || cell.isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                            color:
                                cell.isSelected
                                    ? Colors.white
                                    : cell.isPast
                                    ? AppColors.getTextSecondary(
                                      context,
                                    ).withOpacity(0.3)
                                    : AppColors.getTextPrimary(context),
                          ),
                        ),
                        if (cell.slotCount > 0 && !cell.isSelected) ...[
                          const SizedBox(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color:
                                      cell.hasBooked
                                          ? AppColors.primary
                                          : AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Legend(color: AppColors.success, label: 'Open'),
              const SizedBox(width: 12),
              _Legend(color: AppColors.primary, label: 'Booked'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.getTextSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DayCell {
  final int? day;
  final DateTime? date;
  final int slotCount;
  final bool hasBooked;
  final bool isToday;
  final bool isSelected;
  final bool isPast;

  const _DayCell({
    required this.day,
    required this.date,
    required this.slotCount,
    required this.hasBooked,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
  });

  factory _DayCell.empty() => const _DayCell(
    day: null,
    date: null,
    slotCount: 0,
    hasBooked: false,
    isToday: false,
    isSelected: false,
    isPast: false,
  );
}

// ── Slot list ─────────────────────────────────────────────────────────────────

class _SlotList extends ConsumerWidget {
  final List<TimeSlotModel> slots;
  final String coachId;
  final VoidCallback onAdd;

  const _SlotList({
    required this.slots,
    required this.coachId,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${slots.length} slot${slots.length == 1 ? '' : 's'}',
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add slot'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...slots.map((slot) => _SlotRow(slot: slot, coachId: coachId)),
      ],
    );
  }
}

class _SlotRow extends ConsumerWidget {
  final TimeSlotModel slot;
  final String coachId;

  const _SlotRow({required this.slot, required this.coachId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              slot.isBooked
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.success.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (slot.isBooked ? AppColors.primary : AppColors.success)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              slot.isBooked
                  ? Icons.event_busy_rounded
                  : Icons.event_available_rounded,
              color: slot.isBooked ? AppColors.primary : AppColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.formattedStart} – ${slot.formattedEnd}',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${slot.durationMinutes} min  ·  '
                  '${slot.sessionTypes.map((k) => SessionType.values.firstWhere((e) => e.firestoreKey == k, orElse: () => SessionType.individual).shortLabel).join(', ')}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (slot.isBooked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Booked',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Remove slot',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remove Slot?'),
            content: const Text('This time slot will be permanently removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(coachServiceProvider).removeSlot(coachId, slot.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
      }
    }
  }
}

// ── Hint / Empty states ───────────────────────────────────────────────────────

class _NoSelectionHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a date to view or manage slots',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyDay({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: AppColors.getTextSecondary(context).withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'No slots on this day',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add a slot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add Slot Bottom Sheet ─────────────────────────────────────────────────────

class _AddSlotSheet extends ConsumerStatefulWidget {
  final CoachModel coach;
  final DateTime initialDate;
  final VoidCallback onAdded;

  const _AddSlotSheet({
    required this.coach,
    required this.initialDate,
    required this.onAdded,
  });

  @override
  ConsumerState<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends ConsumerState<_AddSlotSheet> {
  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 60;
  final Set<String> _selectedTypes = {};
  bool _isLoading = false;

  final List<int> _durations = [30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    // default: support all session types offered by coach
    _selectedTypes.addAll(widget.coach.sessionTypes);
  }

  @override
  Widget build(BuildContext context) {
    final endTime = _computeEndTime();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getTextSecondary(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Add Time Slot',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Date picker
            _FieldLabel(label: 'Date'),
            _TappableRow(
              icon: Icons.calendar_today_outlined,
              text: DateFormat('EEE, d MMMM yyyy').format(_date),
              onTap: () => _pickDate(context),
            ),

            const SizedBox(height: 16),

            // Start time
            _FieldLabel(label: 'Start Time'),
            _TappableRow(
              icon: Icons.access_time_rounded,
              text: _startTime.format(context),
              onTap: () => _pickTime(context),
            ),

            const SizedBox(height: 16),

            // Duration
            _FieldLabel(label: 'Duration'),
            Wrap(
              spacing: 8,
              children:
                  _durations.map((d) {
                    final selected = d == _durationMinutes;
                    return ChoiceChip(
                      label: Text(
                        d < 60
                            ? '${d}min'
                            : '${d ~/ 60}h${d % 60 > 0 ? ' ${d % 60}m' : ''}',
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() => _durationMinutes = d),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      backgroundColor: AppColors.getSurface(context),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 4),
            Text(
              'Ends at: ${endTime.format(context)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),

            const SizedBox(height: 16),

            // Session types
            _FieldLabel(label: 'Supported Session Types'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  SessionType.values.map((type) {
                    final isOffered = widget.coach.sessionTypes.contains(
                      type.firestoreKey,
                    );
                    final selected = _selectedTypes.contains(type.firestoreKey);
                    return FilterChip(
                      label: Text(type.shortLabel),
                      selected: selected,
                      onSelected:
                          isOffered
                              ? (val) {
                                setState(() {
                                  if (val) {
                                    _selectedTypes.add(type.firestoreKey);
                                  } else {
                                    _selectedTypes.remove(type.firestoreKey);
                                  }
                                });
                              }
                              : null,
                      selectedColor: AppColors.primary.withOpacity(0.15),
                      checkmarkColor: AppColors.primary,
                      backgroundColor: AppColors.getSurface(context),
                      disabledColor: AppColors.getTextSecondary(
                        context,
                      ).withOpacity(0.05),
                      labelStyle: TextStyle(
                        color:
                            !isOffered
                                ? AppColors.getTextSecondary(
                                  context,
                                ).withOpacity(0.4)
                                : selected
                                ? AppColors.primary
                                : null,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading || _selectedTypes.isEmpty ? null : _addSlot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('Add Slot'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _computeEndTime() {
    final totalMinutes =
        _startTime.hour * 60 + _startTime.minute + _durationMinutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  String _timeOfDayTo24h(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addSlot() async {
    setState(() => _isLoading = true);

    try {
      final endTime = _computeEndTime();
      final slotDate = DateTime(_date.year, _date.month, _date.day);

      final slot = TimeSlotModel(
        id: '',
        coachId: widget.coach.id,
        date: Timestamp.fromDate(slotDate),
        startTime: _timeOfDayTo24h(_startTime),
        endTime: _timeOfDayTo24h(endTime),
        durationMinutes: _durationMinutes,
        isBooked: false,
        sessionTypes: _selectedTypes.toList(),
      );

      await ref.read(coachServiceProvider).addSlot(widget.coach.id, slot);

      widget.onAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add slot: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.getTextSecondary(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TappableRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.getTextSecondary(context).withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.getTextSecondary(context), size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.getTextSecondary(context),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
