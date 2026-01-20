import 'package:flutter/material.dart';

Future<T?> safePushNamed<T>(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  try {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  } catch (_) {
    return Navigator.of(
      context,
    ).pushNamed<T>('/placeholder', arguments: {'title': routeName});
  }
}

Future<T?> safeReplaceNamed<T>(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  try {
    return Navigator.of(
      context,
    ).pushReplacementNamed<T, T>(routeName, arguments: arguments);
  } catch (_) {
    return Navigator.of(context).pushReplacementNamed<T, T>(
      '/placeholder',
      arguments: {'title': routeName},
    );
  }
}
