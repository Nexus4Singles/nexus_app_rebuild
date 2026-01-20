/// Firestore Stub Types (Safe Mode)
/// --------------------------------
/// This file exists ONLY for stabilization builds where Firebase is disabled.
/// It allows models that reference Firestore types to compile without
/// pulling cloud_firestore (and therefore gRPC).

class Timestamp {
  final DateTime dateTime;
  const Timestamp(this.dateTime);

  static Timestamp now() => Timestamp(DateTime.now());

  /// Matches Firestore API shape used across models.
  static Timestamp fromDate(DateTime date) => Timestamp(date);

  DateTime toDate() => dateTime;

  @override
  String toString() => 'Timestamp($dateTime)';
}

/// Minimal DocumentSnapshot stub used in a few model constructors.
/// We only implement what is required for compilation.
class DocumentSnapshot<T> {
  final String id;
  final T? dataValue;

  const DocumentSnapshot({required this.id, this.dataValue});

  T? data() => dataValue;
}

/// Minimal QueryDocumentSnapshot stub (sometimes used interchangeably)
class QueryDocumentSnapshot<T> extends DocumentSnapshot<T> {
  const QueryDocumentSnapshot({required super.id, super.dataValue});
}
