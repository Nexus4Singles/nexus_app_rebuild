import 'dart:convert';

/// Phase 1 (local) + Firebase-ready moderation domain models.

enum ReportReason {
  harassment,
  impersonation,
  spam,
  inappropriateContent,
  other;

  String get label {
    switch (this) {
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.impersonation:
        return 'Impersonation';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.inappropriateContent:
        return 'Inappropriate content';
      case ReportReason.other:
        return 'Other';
    }
  }

  String get wireValue {
    switch (this) {
      case ReportReason.harassment:
        return 'harassment';
      case ReportReason.impersonation:
        return 'impersonation';
      case ReportReason.spam:
        return 'spam';
      case ReportReason.inappropriateContent:
        return 'inappropriate_content';
      case ReportReason.other:
        return 'other';
    }
  }

  static ReportReason fromWireValue(String v) {
    switch (v) {
      case 'harassment':
        return ReportReason.harassment;
      case 'impersonation':
        return ReportReason.impersonation;
      case 'spam':
        return ReportReason.spam;
      case 'inappropriate_content':
        return ReportReason.inappropriateContent;
      case 'other':
      default:
        return ReportReason.other;
    }
  }
}

class UserReportRecord {
  final String reporterKey; // uid or 'guest'
  final String reportedUid;
  final ReportReason reason;
  final String? notes;
  final int createdAtMs;

  const UserReportRecord({
    required this.reporterKey,
    required this.reportedUid,
    required this.reason,
    required this.createdAtMs,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'reporterKey': reporterKey,
    'reportedUid': reportedUid,
    'reason': reason.wireValue,
    'notes': notes,
    'createdAtMs': createdAtMs,
  };

  static UserReportRecord? fromJson(Object? obj) {
    if (obj is! Map<String, dynamic>) return null;
    final reporterKey = (obj['reporterKey'] ?? '').toString();
    final reportedUid = (obj['reportedUid'] ?? '').toString();
    if (reporterKey.isEmpty || reportedUid.isEmpty) return null;

    final reasonStr = (obj['reason'] ?? '').toString();
    final reason = ReportReason.fromWireValue(reasonStr);
    final notesRaw = obj['notes'];
    final notes = (notesRaw == null) ? null : notesRaw.toString();
    final createdAtMsRaw = obj['createdAtMs'];
    final createdAtMs =
        createdAtMsRaw is int
            ? createdAtMsRaw
            : int.tryParse((createdAtMsRaw ?? '').toString()) ?? 0;

    return UserReportRecord(
      reporterKey: reporterKey,
      reportedUid: reportedUid,
      reason: reason,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAtMs: createdAtMs,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
