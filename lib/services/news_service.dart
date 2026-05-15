import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/news_item.dart';
import 'package:thix_id/supabase/supabase_config.dart';

class NewsService {
  static const String table = 'thix_info_news';
  static const _kLocal = 'thix_info_news_v1';
  static const String imageBucket = 'thix_info_news_images';

  /// Upload an image to Supabase Storage and return a public URL.
  ///
  /// Requires a public storage bucket named [imageBucket].
  Future<String> uploadNewsImage({required Uint8List bytes, required String extension}) async {
    final ext = extension.trim().isEmpty ? 'jpg' : extension.trim().toLowerCase();
    final uid = SupabaseConfig.currentUser?.id ?? 'anon';
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final objectPath = 'news/$uid/$ts.$ext';

    try {
      await SupabaseConfig.storage.from(imageBucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: ext == 'png'
                  ? 'image/png'
                  : ext == 'webp'
                      ? 'image/webp'
                      : ext == 'gif'
                          ? 'image/gif'
                          : 'image/jpeg',
            ),
          );

      final url = SupabaseConfig.storage.from(imageBucket).getPublicUrl(objectPath);
      if (url.trim().isEmpty) throw Exception('Storage: getPublicUrl returned empty.');
      return url;
    } catch (e) {
      final msg = e.toString();
      debugPrint('NewsService.uploadNewsImage failed err=$msg');
      if (msg.contains('Bucket') && msg.contains('not found')) {
        throw Exception("Bucket Supabase Storage introuvable: '$imageBucket'. Crée-le (public) dans Supabase → Storage.");
      }
      throw Exception('Upload image échoué: $msg');
    }
  }

  Future<List<NewsItem>> listNews({int limit = 200}) async {
    // 1) Try Supabase first (so Admin-created content appears immediately)
    try {
      final res = await SupabaseService.select(table, select: '*', orderBy: 'created_at', ascending: false, limit: limit);
      final items = _mapRows(res);
      if (items.isNotEmpty) {
        await _cache(items);
        return items;
      }
    } catch (e) {
      debugPrint('NewsService.listNews supabase failed err=$e');
    }

    // 2) Local fallback (cached or seeded)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocal);
      if (raw == null || raw.trim().isEmpty) {
        final seeded = _seed();
        await prefs.setString(_kLocal, NewsItem.encodeList(seeded));
        return seeded;
      }
      final items = NewsItem.decodeList(raw);
      if (items.isEmpty) {
        final seeded = _seed();
        await prefs.setString(_kLocal, NewsItem.encodeList(seeded));
        return seeded;
      }
      return items;
    } catch (e) {
      debugPrint('NewsService.listNews local failed err=$e');
      return _seed();
    }
  }

  Future<void> createNews(NewsItem item) async {
    try {
      await SupabaseService.insert(table, _toRow(item, preferSubtitleColumn: true));
      return;
    } catch (e) {
      final msg = e.toString();
      debugPrint('NewsService.createNews first insert failed err=$msg');

      // Many Supabase schemas use `content` instead of `subtitle`. Because this
      // app was built to tolerate multiple schemas, we retry with a different
      // column mapping when PostgREST reports a missing column.
      final missingSubtitle = msg.contains("Could not find the 'subtitle' column") || msg.contains('subtitle') && msg.contains('schema cache');
      final missingContent = msg.contains("Could not find the 'content' column") || msg.contains('content') && msg.contains('schema cache');

      if (missingSubtitle) {
        try {
          await SupabaseService.insert(table, _toRow(item, preferSubtitleColumn: false));
          return;
        } catch (e2) {
          debugPrint('NewsService.createNews retry(content) failed err=$e2');
          rethrow;
        }
      }

      if (missingContent) {
        try {
          await SupabaseService.insert(table, _toRow(item, preferSubtitleColumn: true));
          return;
        } catch (e2) {
          debugPrint('NewsService.createNews retry(subtitle) failed err=$e2');
          rethrow;
        }
      }

      rethrow;
    }
  }

  Future<void> updateNews({required String id, required NewsItem item}) async {
    final safeId = id.trim();
    if (safeId.isEmpty) throw Exception('News id requis.');
    try {
      await SupabaseService.update(
        table,
        _toRow(item, preferSubtitleColumn: true),
        filters: {'id': safeId},
      );
    } catch (e) {
      final msg = e.toString();
      debugPrint('NewsService.updateNews failed err=$msg');

      final missingSubtitle = msg.contains("Could not find the 'subtitle' column") || msg.contains('subtitle') && msg.contains('schema cache');
      if (missingSubtitle) {
        await SupabaseService.update(
          table,
          _toRow(item, preferSubtitleColumn: false),
          filters: {'id': safeId},
        );
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteNews({required String id}) async {
    final safeId = id.trim();
    if (safeId.isEmpty) return;
    try {
      await SupabaseService.delete(table, filters: {'id': safeId});
    } catch (e) {
      debugPrint('NewsService.deleteNews failed err=$e');
      rethrow;
    }
  }

  List<NewsItem> _mapRows(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    return rows.map((r) {
      DateTime parseDate(dynamic v) {
        if (v == null) return now;
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString()) ?? now;
      }

      String pick(List<String> keys, {String fallback = ''}) {
        for (final k in keys) {
          final v = r[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
        return fallback;
      }

      final id = pick(const ['id', 'uuid'], fallback: _id('news'));
      final title = pick(const ['title', 'headline'], fallback: '—');
      final subtitle = pick(const ['subtitle', 'summary', 'content'], fallback: '');
      final source = pick(const ['source', 'publisher', 'author'], fallback: 'THIX');
      final category = pick(const ['category', 'tag'], fallback: 'Actualités');
      final severity = pick(const ['severity', 'priority'], fallback: 'Info');
      final featured = (r['featured'] == true) || (r['is_featured'] == true) || (r['featured']?.toString().toLowerCase() == 'true');
      final imageUrl = pick(const ['image_url', 'imageUrl', 'cover_url', 'coverUrl'], fallback: '');

      return NewsItem(
        id: id,
        title: title,
        subtitle: subtitle,
        source: source,
        category: category,
        severity: severity,
        featured: featured,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
        createdAt: parseDate(r['created_at'] ?? r['createdAt']),
        updatedAt: parseDate(r['updated_at'] ?? r['updatedAt']),
      );
    }).toList(growable: false);
  }

  Map<String, dynamic> _toRow(NewsItem item, {required bool preferSubtitleColumn}) {
    return <String, dynamic>{
      // We avoid sending id so DB can generate uuid if needed.
      'title': item.title,
      if (preferSubtitleColumn) 'subtitle': item.subtitle else 'content': item.subtitle,
      'source': item.source,
      'category': item.category,
      'severity': item.severity,
      'featured': item.featured,
      if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) 'image_url': item.imageUrl!.trim(),
      // created_at/updated_at usually default server-side.
    };
  }

  Future<void> _cache(List<NewsItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocal, NewsItem.encodeList(items));
    } catch (e) {
      debugPrint('NewsService cache failed err=$e');
    }
  }

  String _id(String prefix) {
    final rnd = Random.secure();
    final n = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${prefix}_$n';
  }

  List<NewsItem> _seed() {
    final now = DateTime.now();
    return [
      NewsItem(
        id: 'news_kyc_update',
        title: 'Sécurité: mise à jour KYC / vérification',
        subtitle: 'Nous renforçons la vérification des profils et documents. Les comptes “Vérifiés” auront un badge visible partout.',
        source: 'THIX Trust Center',
        category: 'Sécurité',
        severity: 'Important',
        featured: true,
        imageUrl: null,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      NewsItem(
        id: 'news_grants',
        title: 'Opportunités: bourses & subventions',
        subtitle: 'Nouveaux programmes disponibles dans la section Opportunités. Pense à compléter ton profil pour candidater.',
        source: 'THIX Opportunities',
        category: 'Actualités',
        severity: 'Info',
        featured: false,
        imageUrl: null,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}
