import 'package:flutter/material.dart';
import '../../journeys/domain/journey_models.dart';

class JourneyDetailScreen extends StatelessWidget {
  final Journey journey;
  const JourneyDetailScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3A215D)),
        title: const Text(
          'Journey Details',
          style: TextStyle(
            color: Color(0xFF3A215D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (journey.heroImageAsset.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      journey.heroImageAsset,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  journey.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A215D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  journey.summary,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF3A215D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DetailChip(label: '${journey.estimatedDays} days'),
              _DetailChip(label: journey.difficulty),
              _DetailChip(label: journey.audience),
            ],
          ),
          const SizedBox(height: 28),
          // Activities Placeholder
          const Text(
            'Activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A215D),
            ),
          ),
          const SizedBox(height: 12),
          // TODO: List activities here
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFF7F3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Activities for this journey will be listed here.',
              style: TextStyle(color: Color(0xFF3A215D)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF3A215D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
