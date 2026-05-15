import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountType { personal, enterprise }

class AppUser {
  final String id; // Firebase uid (or local id in demo mode)
  final String thixId; // THIX-XXXXXX
  final String thixChat; // public chat handle (modifiable)

  /// Optional score (0-100) representing a trust/completeness indicator.
  /// When absent, UI can compute a fallback from profile completeness.
  final int? thixScore;

  final String email;
  final String? phone;
  final String displayName;
  final AccountType accountType;

  final String? photoUrl;
  final String? bio;
  final String? countryOrOrigin;

  // Extended personal profile fields.
  final String? contactPhone; // user's own phone (optional if login via email)
  final String? maritalStatus;
  final String? gender;
  final String? occupation;
  /// Job title / role (newer schema column: `profession`).
  final String? profession;

  // Personal identity fields (used primarily for Personal account registration).
  final String? dateOfBirth; // ISO-8601 (yyyy-MM-dd)
  final String? placeOfBirth;
  final String? nationality;
  final String? address;
  final String? fatherName;
  final String? motherName;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;

  final String? registrationStatus; // draft | submitted | verified | rejected

  /// List of education entries (free-form maps to keep UI flexible).
  final List<Map<String, dynamic>> education;

  /// List of experience entries (free-form maps to keep UI flexible).
  final List<Map<String, dynamic>> experience;

  /// Skills list: [{name: 'Project management', level: 'Expert'}]
  final List<Map<String, dynamic>> skills;

  /// Enrollments list: [{title, provider, progress (0-100), status}]
  final List<Map<String, dynamic>> enrollments;

  /// Spoken languages (multi-add).
  final List<String> languages;

  /// User security preferences.
  final bool biometricsEnabled;
  final bool twoFaEnabled;

  final DateTime createdAt;
  final DateTime updatedAt;

  // Legacy local-auth fields (kept for backward compatibility).
  final String passwordSaltB64;
  final String passwordHashHex;

  const AppUser({
    required this.id,
    required this.thixId,
    required this.thixChat,
    required this.thixScore,
    required this.email,
    required this.phone,
    required this.displayName,
    required this.accountType,
    required this.photoUrl,
    required this.bio,
    required this.countryOrOrigin,
    this.contactPhone,
    this.maritalStatus,
    this.gender,
    this.occupation,
    this.profession,
    this.dateOfBirth,
    this.placeOfBirth,
    this.nationality,
    this.address,
    this.fatherName,
    this.motherName,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.registrationStatus,
    required this.education,
    required this.experience,
    required this.skills,
    required this.enrollments,
    required this.languages,
    required this.biometricsEnabled,
    required this.twoFaEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.passwordSaltB64 = '',
    this.passwordHashHex = '',
  });

  factory AppUser.firebase({required String uid, required String? email, required String? phone}) {
    final now = DateTime.now();
    return AppUser(
      id: uid,
      thixId: 'THIX-000000',
      thixChat: '',
      thixScore: null,
      email: (email ?? '').toLowerCase(),
      phone: phone,
      displayName: 'Utilisateur THIX',
      accountType: AccountType.personal,
      photoUrl: null,
      bio: null,
      countryOrOrigin: null,
      contactPhone: phone,
      maritalStatus: null,
      gender: null,
      occupation: null,
      profession: null,
      dateOfBirth: null,
      placeOfBirth: null,
      nationality: null,
      address: null,
      fatherName: null,
      motherName: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
      emergencyContactRelation: null,
      registrationStatus: null,
      education: const [],
      experience: const [],
      skills: const [],
      enrollments: const [],
      languages: const [],
      biometricsEnabled: true,
      twoFaEnabled: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  AppUser copyWith({
    String? id,
    String? thixId,
    String? thixChat,
    int? thixScore,
    String? email,
    String? phone,
    String? displayName,
    AccountType? accountType,
    String? photoUrl,
    String? bio,
    String? countryOrOrigin,
    String? contactPhone,
    String? maritalStatus,
    String? gender,
    String? occupation,
    String? profession,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? address,
    String? fatherName,
    String? motherName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? registrationStatus,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? skills,
    List<Map<String, dynamic>>? enrollments,
    List<String>? languages,
    bool? biometricsEnabled,
    bool? twoFaEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? passwordSaltB64,
    String? passwordHashHex,
  }) {
    return AppUser(
      id: id ?? this.id,
      thixId: thixId ?? this.thixId,
      thixChat: thixChat ?? this.thixChat,
      thixScore: thixScore ?? this.thixScore,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      countryOrOrigin: countryOrOrigin ?? this.countryOrOrigin,
      contactPhone: contactPhone ?? this.contactPhone,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      gender: gender ?? this.gender,
      occupation: occupation ?? this.occupation,
      profession: profession ?? this.profession,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      nationality: nationality ?? this.nationality,
      address: address ?? this.address,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      registrationStatus: registrationStatus ?? this.registrationStatus,
      education: education ?? this.education,
      experience: experience ?? this.experience,
      skills: skills ?? this.skills,
      enrollments: enrollments ?? this.enrollments,
      languages: languages ?? this.languages,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      passwordSaltB64: passwordSaltB64 ?? this.passwordSaltB64,
      passwordHashHex: passwordHashHex ?? this.passwordHashHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thixId': thixId,
      'thixChat': thixChat,
      'thixScore': thixScore,
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'accountType': accountType.name,
      'photoUrl': photoUrl,
      'bio': bio,
      'countryOrOrigin': countryOrOrigin,
      'contactPhone': contactPhone,
      'maritalStatus': maritalStatus,
      'gender': gender,
      'occupation': occupation,
      'profession': profession,
      'dateOfBirth': dateOfBirth,
      'placeOfBirth': placeOfBirth,
      'nationality': nationality,
      'address': address,
      'fatherName': fatherName,
      'motherName': motherName,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'registrationStatus': registrationStatus,
      'education': education,
      'experience': experience,
      'skills': skills,
      'enrollments': enrollments,
      'languages': languages,
      'biometricsEnabled': biometricsEnabled,
      'twoFaEnabled': twoFaEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'passwordSaltB64': passwordSaltB64,
      'passwordHashHex': passwordHashHex,
    };
  }

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      thixId: json['thixId'] as String,
      thixChat: (json['thixChat'] as String?) ?? '',
      thixScore: (json['thixScore'] as num?)?.toInt(),
      email: json['email'] as String,
      phone: json['phone'] as String?,
      displayName: json['displayName'] as String,
      accountType: AccountType.values.firstWhere((e) => e.name == (json['accountType'] as String)),
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      countryOrOrigin: json['countryOrOrigin'] as String?,
      contactPhone: json['contactPhone'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      profession: json['profession'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      placeOfBirth: json['placeOfBirth'] as String?,
      nationality: json['nationality'] as String?,
      address: json['address'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      emergencyContactName: json['emergencyContactName'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      emergencyContactRelation: json['emergencyContactRelation'] as String?,
      registrationStatus: json['registrationStatus'] as String?,
      education: ((json['education'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      experience: ((json['experience'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      skills: ((json['skills'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      enrollments: ((json['enrollments'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      languages: ((json['languages'] as List?) ?? const []).whereType<String>().toList(growable: false),
      biometricsEnabled: (json['biometricsEnabled'] as bool?) ?? true,
      twoFaEnabled: (json['twoFaEnabled'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      passwordSaltB64: (json['passwordSaltB64'] as String?) ?? '',
      passwordHashHex: (json['passwordHashHex'] as String?) ?? '',
    );
  }

  static AppUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const <String, dynamic>{};
    final createdAt = _readDate(d['createdAt']) ?? DateTime.now();
    final updatedAt = _readDate(d['updatedAt']) ?? createdAt;
    final accountTypeStr = (d['accountType'] as String?) ?? AccountType.personal.name;
    return AppUser(
      id: snap.id,
      thixId: (d['thixId'] as String?) ?? 'THIX-000000',
      thixChat: (d['thixChat'] as String?) ?? '',
      thixScore: (d['thixScore'] as num?)?.toInt(),
      email: ((d['email'] as String?) ?? '').toLowerCase(),
      phone: d['phone'] as String?,
      displayName: (d['displayName'] as String?) ?? 'Utilisateur THIX',
      accountType: AccountType.values.firstWhere((e) => e.name == accountTypeStr, orElse: () => AccountType.personal),
      photoUrl: d['photoUrl'] as String?,
      bio: d['bio'] as String?,
      countryOrOrigin: d['countryOrOrigin'] as String?,
      contactPhone: d['contactPhone'] as String?,
      maritalStatus: d['maritalStatus'] as String?,
      gender: d['gender'] as String?,
      occupation: d['occupation'] as String?,
      profession: d['profession'] as String?,
      dateOfBirth: d['dateOfBirth'] as String?,
      placeOfBirth: d['placeOfBirth'] as String?,
      nationality: d['nationality'] as String?,
      address: d['address'] as String?,
      fatherName: d['fatherName'] as String?,
      motherName: d['motherName'] as String?,
      emergencyContactName: d['emergencyContactName'] as String?,
      emergencyContactPhone: d['emergencyContactPhone'] as String?,
      emergencyContactRelation: d['emergencyContactRelation'] as String?,
      registrationStatus: d['registrationStatus'] as String?,
      education: ((d['education'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      experience: ((d['experience'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      skills: ((d['skills'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      enrollments: ((d['enrollments'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false),
      languages: ((d['languages'] as List?) ?? const []).whereType<String>().toList(growable: false),
      biometricsEnabled: (d['biometricsEnabled'] as bool?) ?? true,
      twoFaEnabled: (d['twoFaEnabled'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'thixId': thixId,
      'thixChat': thixChat,
      'thixScore': thixScore,
      'email': email,
      'phone': phone,
      'displayName': displayName,
      'accountType': accountType.name,
      'photoUrl': photoUrl,
      'bio': bio,
      'countryOrOrigin': countryOrOrigin,
      'contactPhone': contactPhone,
      'maritalStatus': maritalStatus,
      'gender': gender,
      'occupation': occupation,
      'dateOfBirth': dateOfBirth,
      'placeOfBirth': placeOfBirth,
      'nationality': nationality,
      'address': address,
      'fatherName': fatherName,
      'motherName': motherName,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'emergencyContactRelation': emergencyContactRelation,
      'registrationStatus': registrationStatus,
      'education': education,
      'experience': experience,
      'skills': skills,
      'enrollments': enrollments,
      'languages': languages,
      'biometricsEnabled': biometricsEnabled,
      'twoFaEnabled': twoFaEnabled,
      // Prefer server timestamps when writing in services.
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static DateTime? _readDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static List<AppUser> decodeList(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(AppUser.fromJson).toList(growable: false);
  }

  static String encodeList(List<AppUser> users) => jsonEncode(users.map((u) => u.toJson()).toList(growable: false));

  /// Returns true when the user currently has an active free trial.
  ///
  /// Trial is encoded inside [registrationStatus] as:
  /// `trial_until:<ISO-8601 UTC timestamp>`
  bool get hasActiveTrial {
    final raw = (registrationStatus ?? '').trim();
    if (!raw.toLowerCase().startsWith('trial_until:')) return false;
    final iso = raw.substring('trial_until:'.length).trim();
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    return dt.isAfter(DateTime.now().toUtc());
  }

  /// Returns true when [thixId] looks like a final, usable THIX ID.
  ///
  /// We treat these as "pending" placeholders:
  /// - empty
  /// - THIX-PENDING
  /// - THIX-000000
  bool get hasRealThixId {
    final v = thixId.trim().toUpperCase();
    return v.isNotEmpty && v != 'THIX-PENDING' && v != 'THIX-000000';
  }
}
