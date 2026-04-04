import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/counselling_models.dart';

class CoachCard extends StatelessWidget {
  final CoachModel coach;
  final String sessionTypeKey;
  final VoidCallback onTap;

  const CoachCard({
    super.key,
    required this.coach,
    required this.sessionTypeKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = coach.rateForSession(sessionTypeKey);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo — flex so it shrinks when the card height is constrained
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox.expand(
                  child: coach.profilePhotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coach.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _PhotoPlaceholder(
                            name: coach.name,
                            isDark: isDark,
                          ),
                          errorWidget: (_, __, ___) => _PhotoPlaceholder(
                            name: coach.name,
                            isDark: isDark,
                          ),
                        )
                      : _PhotoPlaceholder(name: coach.name, isDark: isDark),
                ),
              ),
            ),

            // Details — fixed, never expands
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    coach.name,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.getTextPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    coach.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Star rating row
                  Row(
                    children: [
                      _StarRating(rating: coach.rating),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          coach.totalRatings == 0
                              ? 'New'
                              : '${coach.formattedRating} (${coach.totalRatings})',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 10,
                            color: AppColors.getTextSecondary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Price
                  if (rate > 0)
                    Text(
                      'From ${coach.currency} ${_formatAmount(rate)}/hr',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final String name;
  final bool isDark;

  const _PhotoPlaceholder({required this.name, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').take(2).map((w) {
      return w.isNotEmpty ? w[0].toUpperCase() : '';
    }).join();

    return Container(
      color: isDark
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.primaryMuted,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          size: 12,
          color: filled || half
              ? const Color(0xFFFFB800)
              : AppColors.getTextSecondary(context).withOpacity(0.3),
        );
      }),
    );
  }
}

/// Also export for use in other screens
class StarRatingWidget extends StatefulWidget {
  final int initialRating;
  final double iconSize;
  final ValueChanged<int>? onRatingChanged;
  final bool readOnly;

  const StarRatingWidget({
    super.key,
    this.initialRating = 0,
    this.iconSize = 32,
    this.onRatingChanged,
    this.readOnly = false,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < _rating;
        return GestureDetector(
          onTap: widget.readOnly
              ? null
              : () {
                  setState(() => _rating = i + 1);
                  widget.onRatingChanged?.call(i + 1);
                },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              key: ValueKey(filled),
              size: widget.iconSize,
              color: filled
                  ? const Color(0xFFFFB800)
                  : AppColors.getTextSecondary(context).withOpacity(0.4),
            ),
          ),
        );
      }),
    );
  }
}
