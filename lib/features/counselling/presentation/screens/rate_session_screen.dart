import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/coach_service.dart';
import '../../domain/counselling_models.dart';
import '../widgets/coach_card.dart';

class RateSessionScreen extends ConsumerStatefulWidget {
  final BookingModel booking;

  const RateSessionScreen({super.key, required this.booking});

  @override
  ConsumerState<RateSessionScreen> createState() => _RateSessionScreenState();
}

class _RateSessionScreenState extends ConsumerState<RateSessionScreen> {
  int _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ratingModel = BookingRatingModel(
        id: widget.booking.id,
        bookingId: widget.booking.id,
        coachId: widget.booking.coachId,
        userId: widget.booking.userId,
        rating: _rating,
        review:
            _reviewController.text.trim().isEmpty
                ? null
                : _reviewController.text.trim(),
        createdAt: Timestamp.fromDate(DateTime.now()),
      );

      await ref.read(coachServiceProvider).submitRating(ratingModel);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Rate Your Session',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Coach info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryMuted,
                    backgroundImage:
                        widget.booking.coachPhotoUrl != null
                            ? NetworkImage(widget.booking.coachPhotoUrl!)
                            : null,
                    child:
                        widget.booking.coachPhotoUrl == null
                            ? Text(
                              widget.booking.coachName
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.booking.coachName,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.booking.sessionTypeEnum.label,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Rating title
            Text(
              'How was your session?',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Your feedback helps others find the right counselor',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // Stars
            StarRatingWidget(
              initialRating: _rating,
              iconSize: 44,
              onRatingChanged: (r) => setState(() => _rating = r),
            ),

            const SizedBox(height: 8),

            // Label for selected rating
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                key: ValueKey(_rating),
                _ratingLabel(_rating),
                style: AppTextStyles.titleSmall.copyWith(
                  color:
                      _rating > 0
                          ? AppColors.primary
                          : AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Written review
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Write a review (optional)',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              maxLength: 400,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Share your experience to help others...',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                filled: true,
                fillColor: AppColors.getSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                counterStyle: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontSize: 10,
                ),
              ),
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    _isSubmitting
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : Text(
                          'Submit Review',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) => switch (rating) {
    1 => 'Poor',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Very Good',
    5 => 'Excellent!',
    _ => 'Tap a star to rate',
  };
}
