import 'package:flutter/material.dart';

void safePushPlaceholder(BuildContext context, String title) {
  Navigator.of(context).pushNamed(
    '/placeholder',
    arguments: {'title': title},
  );
}
