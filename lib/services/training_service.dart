import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/training_certificate.dart';
import 'package:thix_id/models/training_enrollment.dart';
import 'package:thix_id/models/training_item.dart';
import 'package:thix_id/models/training_lesson.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// User-side training service.
///
/// Reads from Supabase (preferred). Falls back to local seed if DB is not ready.
class TrainingService {
  TrainingService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;
  final SupabaseClient _client;

  static const String trainingsTable = 'thix_trainings';
  static const String trainingsStatusView = 'thix_trainings_status';
  static const String lessonsTable = 'thix_training_lessons';
  static const String enrollmentsTable = 'thix_training_enrollments';
  static const String certificatesTable = 'thix_training_certificates';

  // Local fallback cache keys
  static const _kSeedTrainings = 'thix_seed_trainings_v1';

  Future<List<TrainingItem>> listPublishedTrainings({int limit = 200}) async {
    try {
      final res = await _client.from(trainingsStatusView).select('*').eq('is_published', true).order('is_featured', ascending: false).order('updated_at', ascending: false).limit(limit);
      if (res is! List) return const [];
      return res.map((e) => TrainingItem.fromJson((e as Map).cast<String, dynamic>())).where((t) => t.id.trim().isNotEmpty).toList(growable: false);
    } catch (e) {
      debugPrint('TrainingService.listPublishedTrainings failed err=$e');
      return _localSeedTrainings();
    }
  }

  Future<TrainingItem?> fetchTraining(String trainingId) async {
    final id = trainingId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _client.from(trainingsStatusView).select('*').eq('id', id).maybeSingle();
      if (row == null) return null;
      return TrainingItem.fromJson((row as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('TrainingService.fetchTraining failed id=$id err=$e');
      final all = await listPublishedTrainings();
      try {
        return all.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<TrainingLesson>> listLessons(String trainingId) async {
    final id = trainingId.trim();
    if (id.isEmpty) return const [];
    try {
      final res = await _client.from(lessonsTable).select('*').eq('training_id', id).order('module_index', ascending: true).order('lesson_index', ascending: true).limit(500);
      if (res is! List) return const [];
      return res.map((e) => TrainingLesson.fromJson((e as Map).cast<String, dynamic>())).where((l) => l.id.trim().isNotEmpty).toList(growable: false);
    } catch (e) {
      debugPrint('TrainingService.listLessons failed training=$id err=$e');
      return const [];
    }
  }

  Future<TrainingEnrollment?> getMyEnrollment({required String userId, required String trainingId}) async {
    final uid = userId.trim();
    final tid = trainingId.trim();
    if (uid.isEmpty || tid.isEmpty) return null;
    try {
      final row = await _client.from(enrollmentsTable).select('*').eq('user_id', uid).eq('training_id', tid).maybeSingle();
      if (row == null) return null;
      return TrainingEnrollment.fromJson((row as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('TrainingService.getMyEnrollment failed err=$e');
      return null;
    }
  }

  Future<TrainingEnrollment?> fetchEnrollmentById(String enrollmentId) async {
    final id = enrollmentId.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _client.from(enrollmentsTable).select('*').eq('id', id).maybeSingle();
      if (row == null) return null;
      return TrainingEnrollment.fromJson((row as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('TrainingService.fetchEnrollmentById failed err=$e');
      return null;
    }
  }

  Future<TrainingEnrollment> enroll({required String userId, required String trainingId}) async {
    final uid = userId.trim();
    final tid = trainingId.trim();
    if (uid.isEmpty || tid.isEmpty) throw Exception('Missing userId/trainingId');
    final now = DateTime.now().toUtc();
    try {
      // Upsert ensures idempotency.
      final res = await _client
          .from(enrollmentsTable)
          .upsert({
            'user_id': uid,
            'training_id': tid,
            'status': 'active',
            'progress_percent': 0,
            'learning_minutes': 0,
            'last_activity_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select('*')
          .maybeSingle();
      if (res == null) throw Exception('Enroll returned null');
      return TrainingEnrollment.fromJson((res as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('TrainingService.enroll failed err=$e');
      rethrow;
    }
  }

  Future<void> saveProgress({
    required String enrollmentId,
    required double progressPercent,
    int? addLearningMinutes,
    DateTime? lastActivityAt,
    bool? markCompleted,
  }) async {
    final id = enrollmentId.trim();
    if (id.isEmpty) return;
    try {
      final now = DateTime.now().toUtc();
      final patch = <String, dynamic>{
        'progress_percent': progressPercent.clamp(0, 100),
        if (addLearningMinutes != null) 'learning_minutes': addLearningMinutes,
        'last_activity_at': (lastActivityAt ?? now).toIso8601String(),
        if (markCompleted == true) ...{
          'status': 'completed',
          'completed_at': now.toIso8601String(),
        },
        'updated_at': now.toIso8601String(),
      };
      await _client.from(enrollmentsTable).update(patch).eq('id', id);
    } catch (e) {
      debugPrint('TrainingService.saveProgress failed err=$e');
    }
  }

  Stream<List<TrainingEnrollment>> streamMyEnrollments(String userId) async* {
    final uid = userId.trim();
    if (uid.isEmpty) {
      yield const [];
      return;
    }
    // Polling-based stream (web + mobile safe). Can be replaced by Realtime.
    while (true) {
      try {
        final res = await _client.from(enrollmentsTable).select('*').eq('user_id', uid).order('updated_at', ascending: false).limit(200);
        if (res is List) {
          yield res.map((e) => TrainingEnrollment.fromJson((e as Map).cast<String, dynamic>())).toList(growable: false);
        } else {
          yield const [];
        }
      } catch (e) {
        debugPrint('TrainingService.streamMyEnrollments poll failed err=$e');
        yield const [];
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Stream<List<TrainingCertificate>> streamMyCertificates(String userId) async* {
    final uid = userId.trim();
    if (uid.isEmpty) {
      yield const [];
      return;
    }
    while (true) {
      try {
        final res = await _client.from(certificatesTable).select('*').eq('user_id', uid).order('issued_at', ascending: false).limit(200);
        if (res is List) {
          yield res.map((e) => TrainingCertificate.fromJson((e as Map).cast<String, dynamic>())).toList(growable: false);
        } else {
          yield const [];
        }
      } catch (e) {
        debugPrint('TrainingService.streamMyCertificates poll failed err=$e');
        yield const [];
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  List<TrainingItem> _localSeedTrainings() {
    // Persist seed once to allow basic demo even before SQL is applied.
    // This avoids a totally empty screen in early setup.
    return _seedCached().toList(growable: false);
  }

  List<TrainingItem> _seedCached() {
    // Best-effort caching; never crash UI.
    final now = DateTime.now().toUtc();
    final seeded = <TrainingItem>[
      TrainingItem(
        id: 'trn_cyber_fundamentals',
        title: 'Cybersecurity Foundations (THIX Verified)',
        tagline: 'Zero-trust mindset • Threat modeling • African compliance',
        description: 'Un parcours premium orienté terrain: sécurité, politiques, audits, et réponses à incident. Certificat THIX Verified inclus.',
        coverImageBucket: null,
        coverImagePath: null,
        category: 'Cybersecurity',
        level: 'Beginner',
        language: 'FR',
        deliveryMode: 'online',
        durationMinutes: 6 * 60,
        isFree: false,
        priceAmount: 49,
        currency: 'USD',
        certificationIncluded: true,
        isFeatured: true,
        isPublished: true,
        instructorName: 'THIX Security Lab',
        instructorTitle: 'Cyber Defense Team',
        instructorAvatarUrl: null,
        institutionName: 'THIX ID Academy',
        institutionLogoUrl: null,
        skills: const ['Threat Modeling', 'SOC Basics', 'Incident Response', 'IAM'],
        requirements: 'Aucun prérequis. Un téléphone + connexion internet.',
        startDate: now.add(const Duration(days: 2)),
        studentsCount: 1280,
        rating: 4.9,
        reviewsCount: 342,
        completionRate: 0.72,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      TrainingItem(
        id: 'trn_ai_data_sentinel',
        title: 'AI & Data Sentinel',
        tagline: 'Data governance • Privacy • Practical LLM safety',
        description: 'Apprends à construire des produits IA responsables: governance, privacy, sécurité et mise en prod.',
        coverImageBucket: null,
        coverImagePath: null,
        category: 'AI & Data',
        level: 'Intermediate',
        language: 'FR',
        deliveryMode: 'online',
        durationMinutes: 8 * 60,
        isFree: true,
        priceAmount: 0,
        currency: 'USD',
        certificationIncluded: true,
        isFeatured: false,
        isPublished: true,
        instructorName: 'Prof. N. Kabila',
        instructorTitle: 'Data & AI',
        instructorAvatarUrl: null,
        institutionName: 'Partner University',
        institutionLogoUrl: null,
        skills: const ['Data Governance', 'Prompt Safety', 'PII Protection'],
        requirements: 'Connaissances basiques en data.',
        startDate: now.add(const Duration(days: 6)),
        studentsCount: 840,
        rating: 4.8,
        reviewsCount: 190,
        completionRate: 0.66,
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    unawaited(_persistSeed(seeded));
    return seeded;
  }

  Future<void> _persistSeed(List<TrainingItem> seeded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kSeedTrainings);
      if (existing != null && existing.trim().isNotEmpty) return;
      await prefs.setString(_kSeedTrainings, TrainingItem.encodeList(seeded));
    } catch (e) {
      debugPrint('TrainingService._persistSeed failed err=$e');
    }
  }
}
