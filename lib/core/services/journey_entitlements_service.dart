import 'package:shared_preferences/shared_preferences.dart';

class JourneyEntitlementsService {
  static const _purchasedKey = 'journeys.purchased_ids';

  Future<Set<String>> loadPurchasedJourneyIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_purchasedKey) ?? <String>[];
    return list.toSet();
  }

  Future<bool> isPurchased(String journeyId) async {
    final ids = await loadPurchasedJourneyIds();
    return ids.contains(journeyId);
  }

  Future<void> markPurchased(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_purchasedKey) ?? <String>[]).toSet();
    list.add(journeyId);
    await prefs.setStringList(_purchasedKey, list.toList());
  }

  Future<void> revokePurchase(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_purchasedKey) ?? <String>[]).toSet();
    list.remove(journeyId);
    await prefs.setStringList(_purchasedKey, list.toList());
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_purchasedKey);
  }
}
