class TrainingCertificate {
  final String id;
  final String userId;
  final String trainingId;
  final String verificationId;
  final String status; // issued | revoked
  final DateTime issuedAt;
  final DateTime? revokedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingCertificate({
    required this.id,
    required this.userId,
    required this.trainingId,
    required this.verificationId,
    required this.status,
    required this.issuedAt,
    required this.revokedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  TrainingCertificate copyWith({
    String? id,
    String? userId,
    String? trainingId,
    String? verificationId,
    String? status,
    DateTime? issuedAt,
    DateTime? revokedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingCertificate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trainingId: trainingId ?? this.trainingId,
      verificationId: verificationId ?? this.verificationId,
      status: status ?? this.status,
      issuedAt: issuedAt ?? this.issuedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrainingCertificate.fromJson(Map<String, dynamic> json) {
    DateTime? dt(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return TrainingCertificate(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      trainingId: (json['training_id'] ?? '').toString(),
      verificationId: (json['verification_id'] ?? '').toString(),
      status: (json['status'] ?? 'issued').toString(),
      issuedAt: dt('issued_at') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      revokedAt: dt('revoked_at'),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'training_id': trainingId,
      'verification_id': verificationId,
      'status': status,
      'issued_at': issuedAt.toUtc().toIso8601String(),
      'revoked_at': revokedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
