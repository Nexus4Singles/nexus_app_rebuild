import 'package:flutter/material.dart';
import '../../journeys/domain/journey_models.dart';

class JourneysScreen extends StatelessWidget {
  final List<Journey> journeys;
  const JourneysScreen({super.key, required this.journeys});

  List<Journey> get featuredJourneys {
    // Pick journeys 1, 3, 9, 19, 20 by priorityRank
    final ids = [1, 3, 9, 19, 20];
    return journeys.where((j) => ids.contains(j.priorityRank)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Journeys',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Intro Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Welcome to Journeys',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A215D),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Journeys are guided experiences designed to help you grow in key areas of life and relationships. Each journey is crafted to bring real transformation, one step at a time. Start your journey today and unlock your best self!',
                  style: TextStyle(fontSize: 15, color: Color(0xFF3A215D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Featured Journeys Carousel
          if (featuredJourneys.isNotEmpty) ...[
            const Text(
              'Featured Journeys',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3A215D),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featuredJourneys.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final journey = featuredJourneys[i];
                  return _FeaturedJourneyCard(journey: journey);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          // All Journeys List
          const Text(
            'All Journeys',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3A215D),
            ),
          ),
          const SizedBox(height: 12),
          ...journeys.map((j) => _JourneyListCard(journey: j)).toList(),
        ],
      ),
    );
  }
}

class _FeaturedJourneyCard extends StatelessWidget {
  final Journey journey;
  const _FeaturedJourneyCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (journey.heroImageAsset.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                journey.heroImageAsset,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            journey.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A215D),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            journey.summary,
            style: const TextStyle(fontSize: 13, color: Color(0xFF3A215D)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _JourneyListCard extends StatelessWidget {
  final Journey journey;
  const _JourneyListCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (journey.heroImageAsset.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                journey.heroImageAsset,
                height: 48,
                width: 48,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  journey.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A215D),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  journey.summary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3A215D),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
