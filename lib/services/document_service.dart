import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart'
    if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class DocumentService {
  final SupabaseClient _client;
  DocumentService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  /// Expected table: `documents`
  /// Columns: id (uuid), user_id (text), doc_id (text), title (text), doc_type (text),
  /// status (text), file_name (text), mime_type (text), size_bytes (bigint),
  /// download_url (text), storage_path (text), expires_at (timestamptz),
  /// created_at (timestamptz), updated_at (timestamptz)
  static const String table = 'documents';
  static const String bucket = 'thix-documents';

  /// Thrown when the target Supabase Storage bucket does not exist.
  ///
  /// This typically happens when migrations/setup were not applied on the
  /// connected Supabase project.
  static bool isBucketNotFound(Object e) {
    if (e is! StorageException) return false;
    final msg = (e.message).toLowerCase();
    return e.statusCode == 404 && msg.contains('bucket') && msg.contains('not found');
  }

  /// Generates a download URL for a stored object.
  ///
  /// Why: many Supabase Storage buckets are **private** with RLS, so a public URL
  /// will open but return 403. A signed URL works for both private and public
  /// buckets.
  Future<String> createDownloadUrl({required String storagePath, Duration expiresIn = const Duration(minutes: 20), String bucketName = bucket}) async {
    final path = storagePath.trim();
    if (path.isEmpty) throw Exception('storagePath vide.');
    try {
      final seconds = expiresIn.inSeconds.clamp(60, 60 * 60 * 24);
      return await _client.storage.from(bucketName).createSignedUrl(path, seconds);
    } on StorageException catch (e) {
      debugPrint('DocumentService: createSignedUrl failed bucket=$bucketName path=$path err=${e.message}');
      // Fallback: public URL (works if bucket is public).
      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (e) {
      // Some Supabase client errors are *not* StorageException (platform/web
      // differences). We still return a public URL so the UI can attempt a
      // direct fetch (and show a visible error state if it 403s).
      debugPrint('DocumentService: createSignedUrl unexpected error bucket=$bucketName path=$path err=$e');
      return _client.storage.from(bucketName).getPublicUrl(path);
    }
  }

  /// Uploads a picked file to a given Supabase Storage bucket.
  ///
  /// Returns the uploaded object path.
  Future<String> uploadPickedFileToBucket({
    required String bucketName,
    required String uid,
    required String objectPath,
    required PlatformFile file,
    bool upsert = true,
  }) async {
    final safeBucket = bucketName.trim();
    if (safeBucket.isEmpty) throw Exception('bucketName requis.');
    final path = objectPath.trim();
    if (path.isEmpty) throw Exception('objectPath requis.');
    try {
      final storage = _client.storage.from(safeBucket);
      final contentType = _contentTypeForFile(file);
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Impossible de lire le fichier (bytes null).');
        return await storage.uploadBinary(path, bytes, fileOptions: FileOptions(upsert: upsert, contentType: contentType));
      }

      final p = file.path;
      if (p == null) throw Exception('Chemin fichier invalide.');
      return await storage.upload(path, fileFromPath(p) as dynamic, fileOptions: FileOptions(upsert: upsert, contentType: contentType));
    } on StorageException catch (e) {
      debugPrint('DocumentService: uploadPickedFileToBucket failed bucket=$bucketName uid=$uid path=$objectPath err=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('DocumentService: uploadPickedFileToBucket failed bucket=$bucketName uid=$uid path=$objectPath err=$e');
      rethrow;
    }
  }

  /// Prefers `storage_path` (signed URL) and falls back to `download_url`.
  Future<String> resolveRowDownloadUrl(Map<String, dynamic> row) async {
    final storagePath = (row['storage_path'] ?? row['storagePath'])?.toString() ?? '';
    if (storagePath.trim().isNotEmpty) return createDownloadUrl(storagePath: storagePath);
    return (row['download_url'] ?? row['downloadUrl'])?.toString() ?? '';
  }

  Stream<List<Map<String, dynamic>>> streamDocuments(String uid) async* {
    while (true) {
      try {
        final rows = await _client.from(table).select('*').eq('user_id', uid).order('created_at', ascending: false).limit(200);
        if (rows is List) {
          yield rows.map((e) => (e as Map).cast<String, dynamic>()).toList(growable: false);
        } else {
          yield const <Map<String, dynamic>>[];
        }
      } catch (e) {
        debugPrint('DocumentService: streamDocuments poll failed uid=$uid err=$e');
        yield const <Map<String, dynamic>>[];
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  /// Uploads a file to the default documents bucket and inserts a metadata row.
  ///
  /// Returns the uploaded Storage object path.
  Future<String> uploadPickedFile({
    required String uid,
    required String docId,
    required String title,
    required PlatformFile file,
    String? docType,
    DateTime? expiresAt,
  }) async {
    final normalizedDocId = docId.trim().toUpperCase();
    if (normalizedDocId.isEmpty) throw Exception('Doc ID requis.');
    final safeTitle = title.trim().isEmpty ? file.name : title.trim();

    try {
      final now = DateTime.now().toUtc();
      final ts = now.millisecondsSinceEpoch;
      final ext = (file.extension ?? '').trim();
      final safeExt = ext.isEmpty ? '' : '.${ext.toLowerCase()}';
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = 'users/$uid/documents/$normalizedDocId/${ts}_$safeName$safeExt';
      final storage = _client.storage.from(bucket);

      final contentType = _contentTypeForFile(file);

      String uploadedPath;
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Impossible de lire le fichier.');
        uploadedPath = await storage.uploadBinary(storagePath, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
      } else {
        final path = file.path;
        if (path == null) throw Exception('Chemin fichier invalide.');
        uploadedPath = await storage.upload(storagePath, fileFromPath(path) as dynamic, fileOptions: FileOptions(upsert: true, contentType: contentType));
      }

      // Note: even if the bucket is private, storing a public URL is harmless
      // (it will just 403). UI will prefer signed URLs from `storage_path`.
      final url = storage.getPublicUrl(uploadedPath);
      await _client.from(table).insert({
        'user_id': uid,
        'doc_id': normalizedDocId,
        'doc_type': (docType ?? '').trim().isEmpty ? null : docType!.trim(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'title': safeTitle,
        'status': 'pending',
        'file_name': file.name,
        'mime_type': contentType,
        'size_bytes': file.size,
        'download_url': url,
        'storage_path': uploadedPath,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      return uploadedPath;
    } catch (e) {
      debugPrint('DocumentService: upload failed uid=$uid docId=$docId err=$e');
      rethrow;
    }
  }

  static String _contentTypeForFile(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  Future<void> deleteDocument({required String uid, required String docDocId, String? storagePath}) async {
    try {
      await _client.from(table).delete().eq('id', docDocId).eq('user_id', uid);
      if (storagePath != null && storagePath.trim().isNotEmpty) {
        await _client.storage.from(bucket).remove([storagePath]);
      }
    } catch (e) {
      debugPrint('DocumentService: delete failed uid=$uid doc=$docDocId err=$e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchLatestDocumentRowByDocId({required String uid, required String docId}) async {
    final normalized = docId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final row = await _client
          .from(table)
          .select('*')
          .eq('user_id', uid)
          .eq('doc_id', normalized)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return (row as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('DocumentService: fetchLatestDocumentRowByDocId failed uid=$uid docId=$docId err=$e');
      return null;
    }
  }

  Future<void> deleteLatestDocumentByDocId({required String uid, required String docId}) async {
    try {
      final row = await fetchLatestDocumentRowByDocId(uid: uid, docId: docId);
      if (row == null) return;
      final id = (row['id'] ?? '').toString();
      final storagePath = (row['storage_path'] ?? row['storagePath'])?.toString();
      if (id.trim().isEmpty) return;
      await deleteDocument(uid: uid, docDocId: id, storagePath: storagePath);
    } catch (e) {
      debugPrint('DocumentService: deleteLatestDocumentByDocId failed uid=$uid docId=$docId err=$e');
      rethrow;
    }
  }

  Future<void> deleteObjectFromBucket({required String bucketName, required String storagePath}) async {
    final b = bucketName.trim();
    final p = storagePath.trim();
    if (b.isEmpty || p.isEmpty) return;
    try {
      await _client.storage.from(b).remove([p]);
    } catch (e) {
      debugPrint('DocumentService: deleteObjectFromBucket failed bucket=$bucketName path=$storagePath err=$e');
      rethrow;
    }
  }
}
