import 'dart:convert';

class TrainingEnrollment {
  final String id;
  final String userId;
  final String trainingId;
  final String status; // active | completed | cancelled
  final double progressPercent;
  final int learningMinutes;
  final DateTime? lastActivityAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingEnrollment({
    required this.id,
    required this.userId,
    required this.trainingId,
    required this.status,
    required this.progressPercent,
    required this.learningMinutes,
    required this.lastActivityAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  TrainingEnrollment copyWith({
    String? id,
    String? userId,
    String? trainingId,
    String? status,
    double? progressPercent,
    int? learningMinutes,
    DateTime? lastActivityAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingEnrollment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trainingId: trainingId ?? this.trainingId,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      learningMinutes: learningMinutes ?? this.learningMinutes,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrainingEnrollment.fromJson(Map<String, dynamic> json) {
    double d(Object? v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int i(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? dt(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return TrainingEnrollment(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      trainingId: (json['training_id'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      progressPercent: d(json['progress_percent']),
      learningMinutes: i(json['learning_minutes']),
      lastActivityAt: dt('last_activity_at'),
      completedAt: dt('completed_at'),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'training_id': trainingId,
      'status': status,
      'progress_percent': progressPercent,
      'learning_minutes': learningMinutes,
      'last_activity_at': lastActivityAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String encodeList(List<TrainingEnrollment> list) => jsonEncode(list.map((e) => e.toJson()).toList(growable: false));
  static List<TrainingEnrollment> decodeList(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data.whereType<Map>().map((e) => TrainingEnrollment.fromJson(e.cast<String, dynamic>())).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
