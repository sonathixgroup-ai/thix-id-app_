import 'dart:convert';

/// Core training/course entity for the THIX Learning ecosystem.
///
/// This model is designed to map 1:1 with the Supabase table `thix_trainings`.
class TrainingItem {
  final String id;
  final String title;
  final String? tagline;
  final String? description;
  final String? coverImageBucket;
  final String? coverImagePath;
  final String category;
  final String level;
  final String language;
  final String deliveryMode; // online | physical | hybrid
  final int? durationMinutes;
  final bool isFree;
  final num? priceAmount;
  final String currency;
  final bool certificationIncluded;
  final bool isFeatured;
  final bool isPublished;

  // Instructor / institution (simple fields; can evolve to separate tables)
  final String? instructorName;
  final String? instructorTitle;
  final String? instructorAvatarUrl;
  final String? institutionName;
  final String? institutionLogoUrl;

  // Display
  final List<String> skills;
  final String? requirements;
  final DateTime? startDate;

  // Metrics (denormalized or computed from views)
  final int studentsCount;
  final double rating;
  final int reviewsCount;
  final double completionRate;

  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingItem({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.coverImageBucket,
    required this.coverImagePath,
    required this.category,
    required this.level,
    required this.language,
    required this.deliveryMode,
    required this.durationMinutes,
    required this.isFree,
    required this.priceAmount,
    required this.currency,
    required this.certificationIncluded,
    required this.isFeatured,
    required this.isPublished,
    required this.instructorName,
    required this.instructorTitle,
    required this.instructorAvatarUrl,
    required this.institutionName,
    required this.institutionLogoUrl,
    required this.skills,
    required this.requirements,
    required this.startDate,
    required this.studentsCount,
    required this.rating,
    required this.reviewsCount,
    required this.completionRate,
    required this.createdAt,
    required this.updatedAt,
  });

  TrainingItem copyWith({
    String? id,
    String? title,
    String? tagline,
    String? description,
    String? coverImageBucket,
    String? coverImagePath,
    String? category,
    String? level,
    String? language,
    String? deliveryMode,
    int? durationMinutes,
    bool? isFree,
    num? priceAmount,
    String? currency,
    bool? certificationIncluded,
    bool? isFeatured,
    bool? isPublished,
    String? instructorName,
    String? instructorTitle,
    String? instructorAvatarUrl,
    String? institutionName,
    String? institutionLogoUrl,
    List<String>? skills,
    String? requirements,
    DateTime? startDate,
    int? studentsCount,
    double? rating,
    int? reviewsCount,
    double? completionRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      coverImageBucket: coverImageBucket ?? this.coverImageBucket,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      category: category ?? this.category,
      level: level ?? this.level,
      language: language ?? this.language,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isFree: isFree ?? this.isFree,
      priceAmount: priceAmount ?? this.priceAmount,
      currency: currency ?? this.currency,
      certificationIncluded: certificationIncluded ?? this.certificationIncluded,
      isFeatured: isFeatured ?? this.isFeatured,
      isPublished: isPublished ?? this.isPublished,
      instructorName: instructorName ?? this.instructorName,
      instructorTitle: instructorTitle ?? this.instructorTitle,
      instructorAvatarUrl: instructorAvatarUrl ?? this.instructorAvatarUrl,
      institutionName: institutionName ?? this.institutionName,
      institutionLogoUrl: institutionLogoUrl ?? this.institutionLogoUrl,
      skills: skills ?? this.skills,
      requirements: requirements ?? this.requirements,
      startDate: startDate ?? this.startDate,
      studentsCount: studentsCount ?? this.studentsCount,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      completionRate: completionRate ?? this.completionRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TrainingItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt(String key) {
      final v = json[key];
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    List<String> parseSkills(Object? v) {
      if (v == null) return const [];
      if (v is List) return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList(growable: false);
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) return const [];
        // Accept comma-separated for admin quick entry.
        return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
      }
      return const [];
    }

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

    return TrainingItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      tagline: (json['tagline'] ?? json['quick_hook'])?.toString(),
      description: (json['description'] ?? '').toString().trim().isEmpty ? null : (json['description'] ?? '').toString(),
      coverImageBucket: (json['cover_image_bucket'] ?? json['coverImageBucket'])?.toString(),
      coverImagePath: (json['cover_image_path'] ?? json['coverImagePath'])?.toString(),
      category: (json['category'] ?? 'General').toString(),
      level: (json['level'] ?? 'Beginner').toString(),
      language: (json['language'] ?? 'FR').toString(),
      deliveryMode: (json['delivery_mode'] ?? 'online').toString(),
      durationMinutes: (json['duration_minutes'] is num) ? (json['duration_minutes'] as num).toInt() : int.tryParse((json['duration_minutes'] ?? '').toString()),
      isFree: (json['is_free'] ?? false) == true,
      priceAmount: json['price_amount'] as num?,
      currency: (json['currency'] ?? 'USD').toString(),
      certificationIncluded: (json['certification_included'] ?? true) == true,
      isFeatured: (json['is_featured'] ?? false) == true,
      isPublished: (json['is_published'] ?? true) == true,
      instructorName: (json['instructor_name'] ?? json['instructor'])?.toString(),
      instructorTitle: (json['instructor_title'] ?? '').toString().trim().isEmpty ? null : (json['instructor_title'] ?? '').toString(),
      instructorAvatarUrl: (json['instructor_avatar_url'] ?? '').toString().trim().isEmpty ? null : (json['instructor_avatar_url'] ?? '').toString(),
      institutionName: (json['institution_name'] ?? '').toString().trim().isEmpty ? null : (json['institution_name'] ?? '').toString(),
      institutionLogoUrl: (json['institution_logo_url'] ?? '').toString().trim().isEmpty ? null : (json['institution_logo_url'] ?? '').toString(),
      skills: parseSkills(json['skills']),
      requirements: (json['requirements'] ?? '').toString().trim().isEmpty ? null : (json['requirements'] ?? '').toString(),
      startDate: dt('start_date'),
      studentsCount: i(json['students_count']),
      rating: d(json['rating']),
      reviewsCount: i(json['reviews_count']),
      completionRate: d(json['completion_rate']),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'tagline': tagline,
      'description': description,
      'cover_image_bucket': coverImageBucket,
      'cover_image_path': coverImagePath,
      'category': category,
      'level': level,
      'language': language,
      'delivery_mode': deliveryMode,
      'duration_minutes': durationMinutes,
      'is_free': isFree,
      'price_amount': priceAmount,
      'currency': currency,
      'certification_included': certificationIncluded,
      'is_featured': isFeatured,
      'is_published': isPublished,
      'instructor_name': instructorName,
      'instructor_title': instructorTitle,
      'instructor_avatar_url': instructorAvatarUrl,
      'institution_name': institutionName,
      'institution_logo_url': institutionLogoUrl,
      'skills': skills,
      'requirements': requirements,
      'start_date': startDate?.toUtc().toIso8601String(),
      'students_count': studentsCount,
      'rating': rating,
      'reviews_count': reviewsCount,
      'completion_rate': completionRate,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static String encodeList(List<TrainingItem> list) => jsonEncode(list.map((e) => e.toJson()).toList(growable: false));
  static List<TrainingItem> decodeList(String raw) {
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return data.whereType<Map>().map((e) => TrainingItem.fromJson(e.cast<String, dynamic>())).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
