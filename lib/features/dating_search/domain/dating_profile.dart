class DatingProfile {
  final String uid;
  final String name;
  final int age;
  final String gender; // male | female
  final String? city;
  final String? country;
  final String? profession;
  final List<String> photos;
  final DateTime createdAt;
  final String verificationStatus; // verified | legacy

  // Compatibility fields (for filtering)
  final String? maritalStatus;
  final String? haveKids;
  final String? genotype;
  final String? regularSourceOfIncome;
  final String? longDistance;

  const DatingProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.photos,
    required this.createdAt,
    required this.verificationStatus,
    this.city,
    this.country,
    this.profession,
    this.maritalStatus,
    this.haveKids,
    this.genotype,
    this.regularSourceOfIncome,
    this.longDistance,
  });

  bool get isVerified => verificationStatus == 'verified';

  String get displayLocation {
    final c = city?.trim();
    final co = country?.trim();
    if ((c == null || c.isEmpty) && (co == null || co.isEmpty)) return '';
    if (c != null && c.isNotEmpty && co != null && co.isNotEmpty)
      return '$c, $co';
    return (c != null && c.isNotEmpty) ? c : (co ?? '');
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String)
      return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    try {
      // Firestore Timestamp has toDate()
      final toDate = v.toDate;
      if (toDate is Function) return toDate() as DateTime;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory DatingProfile.fromFirestore(String uid, Map<String, dynamic> json) {
    final photosRaw = json['photos'];
    final photos =
        (photosRaw is List)
            ? photosRaw.map((e) => e.toString()).toList()
            : <String>[];

    final dating = json['dating'];
    final status =
        (dating is Map) ? (dating['verificationStatus'] ?? '').toString() : '';
    final normalizedVerificationStatus =
        status.toString().toLowerCase().trim().isNotEmpty
            ? status.toString().toLowerCase().trim()
            : 'legacy';
    return DatingProfile(
      uid: uid,
      name: (json['name'] ?? json['username'] ?? '').toString(),
      age:
          (json['age'] is int)
              ? json['age'] as int
              : int.tryParse('${json['age']}') ?? 0,
      gender: (json['gender'] ?? '').toString().toLowerCase(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      profession: json['profession']?.toString(),
      photos: photos,
      createdAt: _asDate(json['createdAt']),
      verificationStatus: normalizedVerificationStatus,
      maritalStatus: json['maritalStatus']?.toString(),
      haveKids: json['haveKids']?.toString(),
      genotype: json['genotype']?.toString(),
      regularSourceOfIncome: json['regularSourceOfIncome']?.toString(),
      longDistance: json['longDistance']?.toString(),
    );
  }
}
