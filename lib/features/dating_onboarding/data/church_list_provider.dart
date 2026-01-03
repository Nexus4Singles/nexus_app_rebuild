import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final churchListProvider = FutureProvider<List<String>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/churches_v1.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final list = (data['churches'] as List).cast<String>();
  return list;
});
