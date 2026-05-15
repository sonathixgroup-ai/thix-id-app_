class TrainingLesson {
  final String id;
  final String trainingId;
  final int moduleIndex;
  final int lessonIndex;
  final String title;
  final String type; // video | live | quiz | reading
  final int? durationMinutes;
  final String? videoUrl;
  final String? resourcesJson;
  final bool isPreview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingLesson({
    required this.id,
    required this.trainingId,
    required this.moduleIndex,
    required this.lessonIndex,
    required this.title,
    required this.type,
    required this.durationMinutes,
    required this.videoUrl,
    required this.resourcesJson,
    required this.isPreview,
    required this.createdAt,
    required this.updatedAt,
  });

  TrainingLesson copyWith({
    String? id,
    String? trainingId,
    int? moduleIndex,
    int? lessonIndex,
    String? title,
    String? type,
    int? durationMinutes,
    String? videoUrl,
    String? resourcesJson,
    bool? isPreview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingLesson(
      id: id ?? this.id,
      trainingId: trainingId ?? this.trainingId,
      moduleIndex: moduleIndex ?? this.moduleIndex,
      lessonIndex: lessonIndex ?? this.lessonIndex,
      title: title ?? this.title,
      type: type ?? this.type,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      videoUrl: videoUrl ?? this.videoUrl,
      resourcesJson: resourcesJson ?? this.resourcesJson,
      isPreview: isPreview ?? this.isPreview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrainingLesson.fromJson(Map<String, dynamic> json) {
    int i(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return TrainingLesson(
      id: (json['id'] ?? '').toString(),
      trainingId: (json['training_id'] ?? '').toString(),
      moduleIndex: i(json['module_index']),
      lessonIndex: i(json['lesson_index']),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? 'video').toString(),
      durationMinutes: (json['duration_minutes'] is num) ? (json['duration_minutes'] as num).toInt() : int.tryParse((json['duration_minutes'] ?? '').toString()),
      videoUrl: (json['video_url'] ?? '').toString().trim().isEmpty ? null : (json['video_url'] ?? '').toString(),
      resourcesJson: (json['resources'] ?? '').toString().trim().isEmpty ? null : (json['resources'] ?? '').toString(),
      isPreview: (json['is_preview'] ?? false) == true,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'training_id': trainingId,
      'module_index': moduleIndex,
      'lesson_index': lessonIndex,
      'title': title,
      'type': type,
      'duration_minutes': durationMinutes,
      'video_url': videoUrl,
      'resources': resourcesJson,
      'is_preview': isPreview,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
