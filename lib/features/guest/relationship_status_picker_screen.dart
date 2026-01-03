import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/session/guest_session_provider.dart';
import '../../safe_imports.dart';

class RelationshipStatusPickerScreen extends ConsumerStatefulWidget {
  const RelationshipStatusPickerScreen({super.key});

  @override
  ConsumerState<RelationshipStatusPickerScreen> createState() =>
      _RelationshipStatusPickerScreenState();
}

class _RelationshipStatusPickerScreenState
    extends ConsumerState<RelationshipStatusPickerScreen> {
  String? _gender;
  final Set<String> _goals = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let’s personalize your experience',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Select your relationship status to continue.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            _OptionTile(
              title: 'Single (Never Married)',
              onTap: () => _selectStatus(RelationshipStatus.singleNeverMarried),
            ),
            _OptionTile(
              title: 'Divorced / Widowed',
              onTap: () => _selectStatus(RelationshipStatus.divorced),
            ),
            _OptionTile(
              title: 'Married',
              onTap: () => _selectStatus(RelationshipStatus.married),
            ),

            const SizedBox(height: 28),
            Text('Gender (optional)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Male'),
                  selected: _gender == 'male',
                  onSelected: (_) => setState(() => _gender = 'male'),
                ),
                ChoiceChip(
                  label: const Text('Female'),
                  selected: _gender == 'female',
                  onSelected: (_) => setState(() => _gender = 'female'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('Goals (optional)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),

            _GoalChip('Self-control'),
            _GoalChip('Healing'),
            _GoalChip('Marriage readiness'),
            _GoalChip('Relationship skills'),
            _GoalChip('Confidence'),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveExtras,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You can explore in guest mode. Some features will require creating an account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStatus(RelationshipStatus status) async {
    await ref.read(guestSessionProvider.notifier).setRelationshipStatus(status);
  }

  Future<void> _saveExtras() async {
    final notifier = ref.read(guestSessionProvider.notifier);
    await notifier.setGender(_gender);
    await notifier.setGoals(_goals.toList());
  }

  Widget _GoalChip(String goal) {
    final selected = _goals.contains(goal);
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: FilterChip(
        label: Text(goal),
        selected: selected,
        onSelected: (v) {
          setState(() {
            if (v) {
              _goals.add(goal);
            } else {
              _goals.remove(goal);
            }
          });
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _OptionTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
