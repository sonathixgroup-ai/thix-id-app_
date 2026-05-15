import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/services/platform_file_from_path_stub.dart' if (dart.library.io) 'package:thix_id/services/platform_file_from_path_io.dart';

class EmergencyAlertType {
  static const aggression = 'agression_danger';
  static const ambulance = 'ambulance';
  static const firefighters = 'pompiers';
  static const blood = 'sang';
  static const accident = 'accident';
  static const reportAnonymous = 'denoncer_anonyme';
  static const quickAssist = 'assistance_rapide';
  static const trustedContacts = 'contacts_confiance';
  static const surveillance = 'mode_surveillance';
  static const liveLocation = 'partage_localisation_live';
  static const critical = 'urgence_critique';
}

class SponsoredSafetyAd {
  final String id;
  final String title;
  final String? body;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? sponsorName;

  const SponsoredSafetyAd({required this.id, required this.title, this.body, this.ctaLabel, this.ctaUrl, this.sponsorName});

  factory SponsoredSafetyAd.fromJson(Map<String, dynamic> json) => SponsoredSafetyAd(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: json['body']?.toString(),
        ctaLabel: json['cta_label']?.toString(),
        ctaUrl: json['cta_url']?.toString(),
        sponsorName: json['sponsor_name']?.toString(),
      );
}

class EmergencyService {
  EmergencyService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  bool _adminsTableDisabled = false;
  bool _safetyAdsTableDisabled = false;
  bool _alertsTableDisabled = false;
  bool _auditTableDisabled = false;
  bool _locationsTableDisabled = false;
  bool _evidenceTableDisabled = false;

  bool _isMissingTableError(Object e) => e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'));

  // Supabase/PostgREST can surface missing-column errors in a couple of ways:
  // - PostgREST: code=PGRST204
  // - Postgres: code=42703 (undefined_column)
  bool _isMissingColumnError(Object e) => e is PostgrestException && (e.code == 'PGRST204' || e.code == '42703' || e.message.toLowerCase().contains('does not exist'));

  bool _isSchemaUnavailable(Object e) => _isMissingTableError(e) || _isMissingColumnError(e);

  String _localId() => 'local_${DateTime.now().millisecondsSinceEpoch}_${_client.auth.currentUser?.id ?? 'anon'}';

  StreamSubscription<Position>? _trackingSub;
  Timer? _trackingTimer;
  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;

  bool _audioStreamActive = false;

  static const emergencyBucket = 'thix-emergency';

  static const hotlineEmergency = '112';
  static const hotlineAmbulance = '112';
  static const hotlineFirefighters = '112';

  /// Optional: fetch admin phones from Supabase if your DB provides it.
  /// Expected table (recommended): `thix_emergency_admins` with columns:
  /// - phone (text)
  /// - active (bool)
  /// - priority (int, optional)
  ///
  /// This method is schema-safe: if the table/columns don't exist or RLS blocks,
  /// it returns an empty list and the UI will fall back to the hotline.
  Future<List<String>> fetchAdminPhones({int limit = 3}) async {
    if (_adminsTableDisabled) return const [];
    try {
      final rows = await _client
          .from('thix_emergency_admins')
          .select('phone')
          .eq('active', true)
          .order('priority', ascending: true)
          .limit(limit);
      if (rows is! List) return const [];
      final phones = <String>[];
      for (final r in rows) {
        if (r is Map) {
          final p = (r['phone'] ?? '').toString().trim();
          if (p.isNotEmpty) phones.add(p);
        }
      }
      return phones;
    } on PostgrestException catch (e) {
      // Missing table/column or RLS denial.
      if (_isMissingTableError(e)) {
        _adminsTableDisabled = true;
        debugPrint('EmergencyService: thix_emergency_admins missing; disabling admin phone lookup.');
        return const [];
      }
      debugPrint('EmergencyService: fetchAdminPhones PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('EmergencyService: fetchAdminPhones failed: $e');
      return const [];
    }
  }


  Future<bool> ensureLocationPermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
      return true;
    } catch (e) {
      debugPrint('EmergencyService: location permission failed: $e');
      return false;
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final ok = await ensureLocationPermission();
      if (!ok) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    } catch (e) {
      debugPrint('EmergencyService: getCurrentPosition failed: $e');
      return null;
    }
  }

  Future<String?> createEmergencyAlert({
    required String type,
    required bool isCritical,
    required bool silentMode,
    String? title,
    String? description,
    Position? position,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('EmergencyService: cannot create alert, no Supabase auth user');
      return null;
    }

    if (_alertsTableDisabled) {
      final id = _localId();
      // Keep the UI functional even if the DB schema isn't deployed yet.
      debugPrint('EmergencyService: alerts table disabled; returning local alertId=$id');
      return id;
    }
    try {
      final payload = {
        'user_id': userId,
        // If you store THIX ID publicly, you can populate this field from your profile service.
        'profile_thix_id': null,
        'type': type,
        'severity': isCritical ? 'critical' : 'high',
        'is_critical': isCritical,
        'silent_mode': silentMode,
        'status': 'active',
        'title': title,
        'description': description,
        'last_lat': position?.latitude,
        'last_lng': position?.longitude,
        'last_accuracy_m': position?.accuracy,
        'last_location_at': position == null ? null : DateTime.now().toIso8601String(),
        'metadata': metadata ?? {},
      };

      final res = await _client.from('thix_emergency_alerts').insert(payload).select('id').single();
      final alertId = (res['id'] ?? '').toString();
      await _insertAudit(action: 'create_alert', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'type': type, 'silent_mode': silentMode, 'is_critical': isCritical});
      return alertId.isEmpty ? null : alertId;
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _alertsTableDisabled = true;
        final id = _localId();
        debugPrint('EmergencyService: thix_emergency_alerts missing; falling back to local alertId=$id');
        return id;
      }
      debugPrint('EmergencyService: createEmergencyAlert PostgrestException: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('EmergencyService: createEmergencyAlert failed: $e');
      return null;
    }
  }

  Future<void> updateAlertMetadata({required String alertId, required Map<String, dynamic> metadata}) async {
    if (_alertsTableDisabled) return;
    try {
      await _client.from('thix_emergency_alerts').update({'metadata': metadata}).eq('id', alertId);
      await _insertAudit(action: 'update_metadata', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'metadata_keys': metadata.keys.toList()});
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _alertsTableDisabled = true;
        debugPrint('EmergencyService: updateAlertMetadata disabled (schema unavailable).');
        return;
      }
      debugPrint('EmergencyService: updateAlertMetadata PostgrestException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('EmergencyService: updateAlertMetadata failed: $e');
    }
  }

  Future<String?> uploadEvidenceFile({required String alertId, required PlatformFile file, required String kind}) async {
    if (_evidenceTableDisabled) return null;
    try {
      final ext = (file.extension?.trim().isNotEmpty == true) ? '.${file.extension}' : '';
      final safeName = (file.name.trim().isEmpty ? 'evidence' : file.name).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = 'evidence/$alertId/${DateTime.now().millisecondsSinceEpoch}_$safeName$ext';

      final bucket = _client.storage.from(emergencyBucket);
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) return null;
        await bucket.uploadBinary(storagePath, bytes);
      } else {
        final path = file.path;
        if (path == null) return null;
        final f = fileFromPath(path);
        final bytes = await (f as dynamic).readAsBytes();
        await bucket.uploadBinary(storagePath, bytes);
      }

      await _client.from('thix_emergency_evidence').insert({
        'alert_id': alertId,
        'kind': kind,
        'storage_path': storagePath,
        'mime_type': null,
        'file_name': file.name,
        'file_size_bytes': file.size,
      });

      await _insertAudit(action: 'upload_evidence', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'kind': kind, 'path': storagePath, 'name': file.name});
      return storagePath;
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _evidenceTableDisabled = true;
        debugPrint('EmergencyService: thix_emergency_evidence missing; disabling evidence uploads.');
        return null;
      }
      debugPrint('EmergencyService: uploadEvidenceFile PostgrestException: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('EmergencyService: uploadEvidenceFile failed: $e');
      return null;
    }
  }

  Future<List<String>> uploadEvidenceFiles({required String alertId, required List<PlatformFile> files, required String kind}) async {
    final out = <String>[];
    for (final f in files) {
      final p = await uploadEvidenceFile(alertId: alertId, file: f, kind: kind);
      if (p != null) out.add(p);
    }
    return out;
  }

  Future<void> _insertAudit({required String action, required String entityType, String? entityId, Map<String, dynamic>? metadata}) async {
    if (_auditTableDisabled) return;
    try {
      final userId = _client.auth.currentUser?.id;
      await _client.from('thix_emergency_audit_logs').insert({
        'actor_user_id': userId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'metadata': metadata ?? {},
      });
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _auditTableDisabled = true;
        debugPrint('EmergencyService: thix_emergency_audit_logs missing; disabling audit writes.');
        return;
      }
      debugPrint('EmergencyService: audit insert PostgrestException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('EmergencyService: audit insert failed ($action): $e');
    }
  }

  Future<void> appendLocationPoint({required String alertId, required Position position}) async {
    if (_locationsTableDisabled || _alertsTableDisabled) return;
    try {
      await _client.from('thix_emergency_locations').insert({
        'alert_id': alertId,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy_m': position.accuracy,
        'speed_mps': position.speed,
        'heading_deg': position.heading,
        'captured_at': DateTime.now().toIso8601String(),
      });
      await _client.from('thix_emergency_alerts').update({
        'last_lat': position.latitude,
        'last_lng': position.longitude,
        'last_accuracy_m': position.accuracy,
        'last_location_at': DateTime.now().toIso8601String(),
      }).eq('id', alertId);
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _locationsTableDisabled = true;
        debugPrint('EmergencyService: location tables missing; disabling live location persistence.');
        return;
      }
      debugPrint('EmergencyService: appendLocationPoint PostgrestException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('EmergencyService: appendLocationPoint failed: $e');
    }
  }

  Future<void> startLiveTracking({required String alertId}) async {
    await stopLiveTracking();
    final ok = await ensureLocationPermission();
    if (!ok) return;

    // If schema is unavailable, we still keep a local UI refresh in the overlay.
    if (_locationsTableDisabled || _alertsTableDisabled) {
      debugPrint('EmergencyService: live tracking persistence disabled; skipping DB writes.');
      return;
    }

    try {
      // Cross-platform & predictable: push a point every 5 seconds.
      // (Position stream interval behavior varies by OS/device.)
      _trackingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        final pos = await getCurrentPosition();
        if (pos == null) return;
        await appendLocationPoint(alertId: alertId, position: pos);
      });
      await _insertAudit(action: 'start_tracking', entityType: 'thix_emergency_alerts', entityId: alertId);
    } catch (e) {
      debugPrint('EmergencyService: startLiveTracking failed: $e');
    }
  }

  Future<void> stopLiveTracking() async {
    try {
      await _trackingSub?.cancel();
    } catch (_) {}
    _trackingSub = null;

    try {
      _trackingTimer?.cancel();
    } catch (_) {}
    _trackingTimer = null;
  }

  Future<bool> ensureMicrophonePermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('EmergencyService: microphone permission failed: $e');
      return false;
    }
  }

  Future<String?> startAudioEvidenceRecording({required String alertId}) async {
    try {
      // We try on all platforms. If the plugin/permission isn't available, we fail gracefully.
      final canRecord = await ensureMicrophonePermission();
      if (!canRecord) return null;

      // Web cannot always provide a writable filesystem path.
      if (kIsWeb) {
        _recordingPath = null;
        final webPath = 'thix_emergency_${alertId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: webPath);
        await _insertAudit(action: 'start_recording', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'platform': 'web'});
        return null;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/thix_emergency_${alertId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path;
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100), path: path);
      await _insertAudit(action: 'start_recording', entityType: 'thix_emergency_alerts', entityId: alertId);
      return path;
    } catch (e) {
      debugPrint('EmergencyService: startAudioEvidenceRecording failed: $e');
      return null;
    }
  }

  /// Records short audio chunks and uploads them to Supabase Storage.
  ///
  /// This provides a near real-time "listening" capability for admins:
  /// each chunk becomes an evidence row and the alert's `audio_path` is updated
  /// to the latest uploaded chunk.
  ///
  /// Notes:
  /// - This is **foreground-only**. Mobile OSes will stop recording in background.
  /// - Web recording is best-effort and may not produce a file path.
  Future<void> startLiveAudioStreaming({required String alertId, Duration chunkDuration = const Duration(seconds: 10)}) async {
    await stopLiveAudioStreaming();
    _audioStreamActive = true;
    unawaited(_audioStreamingLoop(alertId: alertId, chunkDuration: chunkDuration));
  }

  Future<void> stopLiveAudioStreaming() async {
    _audioStreamActive = false;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    _recordingPath = null;
  }

  Future<void> _audioStreamingLoop({required String alertId, required Duration chunkDuration}) async {
    while (_audioStreamActive) {
      try {
        // Start chunk recording
        await startAudioEvidenceRecording(alertId: alertId);
        await Future<void>.delayed(chunkDuration);
        if (!_audioStreamActive) break;

        // Stop and upload this chunk
        await stopAndUploadAudioEvidence(alertId: alertId);
      } catch (e) {
        debugPrint('EmergencyService: audio streaming loop error: $e');
        // Backoff slightly to avoid tight loops on repeated failures.
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<String?> stopAndUploadAudioEvidence({required String alertId}) async {
    try {
      if (!await _recorder.isRecording()) return null;
      await _recorder.stop();
      final path = _recordingPath;
      _recordingPath = null;
      if (path == null) return null;

      if (kIsWeb) return null;
      final file = fileFromPath(path);
      final exists = await (file as dynamic).exists() as bool;
      if (!exists) return null;

      final storagePath = 'emergency_audio/$alertId/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final bytes = await (file as dynamic).readAsBytes();
      await _client.storage.from(emergencyBucket).uploadBinary(storagePath, bytes);
      if (!_alertsTableDisabled) {
        await _client.from('thix_emergency_alerts').update({'audio_path': storagePath}).eq('id', alertId);
      }
      final len = await (file as dynamic).length() as int;
      final uri = (file as dynamic).uri;
      final fileName = (uri != null && (uri as Uri).pathSegments.isNotEmpty) ? (uri as Uri).pathSegments.last : null;
      if (!_evidenceTableDisabled) {
        await _client.from('thix_emergency_evidence').insert({'alert_id': alertId, 'kind': 'audio', 'storage_path': storagePath, 'mime_type': 'audio/mp4', 'file_name': fileName, 'file_size_bytes': len});
      }
      await _insertAudit(action: 'upload_recording', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'path': storagePath});
      return storagePath;
    } on PostgrestException catch (e) {
      if (_isSchemaUnavailable(e)) {
        _alertsTableDisabled = true;
        _evidenceTableDisabled = true;
        debugPrint('EmergencyService: stopAndUploadAudioEvidence disabled (schema unavailable).');
        return null;
      }
      debugPrint('EmergencyService: stopAndUploadAudioEvidence PostgrestException: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('EmergencyService: stopAndUploadAudioEvidence failed: $e');
      return null;
    }
  }

  Future<void> notifyBackend({required String alertId, required String channel}) async {
    // Best-effort: Edge Function / push notifications.
    // Always keep a high-integrity audit trail.
    await _insertAudit(action: 'notify_backend', entityType: 'thix_emergency_alerts', entityId: alertId, metadata: {'channel': channel});

    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    if (channel != 'admins' && channel != 'sos') return;

    try {
      await _client.functions.invoke(
        'sos_alert',
        body: {
          'alertId': alertId,
          'userId': uid,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('EmergencyService: notifyBackend invoke sos_alert failed: $e');
    }
  }

  Future<void> notifyAdminsSos({required String alertId, required String type, required String title, Position? position, required bool silentMode, required bool isCritical}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final lat = position?.latitude;
    final lng = position?.longitude;
    final mapsUrl = (lat != null && lng != null) ? 'https://www.google.com/maps?q=$lat,$lng' : null;
    try {
      await _insertAudit(
        action: 'notify_admins_sos',
        entityType: 'thix_emergency_alerts',
        entityId: alertId,
        metadata: {'type': type, 'title': title, 'silent_mode': silentMode, 'is_critical': isCritical, 'maps_url': mapsUrl},
      );
      await _client.functions.invoke(
        'sos_alert',
        body: {
          'alertId': alertId,
          'userId': uid,
          'type': type,
          'severity': isCritical ? 'critical' : 'high',
          'silentMode': silentMode,
          'title': title,
          'lat': lat,
          'lng': lng,
          'accuracyM': position?.accuracy,
          'mapsUrl': mapsUrl,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('EmergencyService: notifyAdminsSos failed: $e');
    }
  }

  Future<List<SponsoredSafetyAd>> fetchSafetyAds({int limit = 3}) async {
    if (_safetyAdsTableDisabled) return const [];
    try {
      final rows = await _client.from('thix_safety_ads').select().eq('active', true).order('priority', ascending: true).limit(limit);
      return (rows as List).map((e) => SponsoredSafetyAd.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (_isMissingTableError(e)) {
        _safetyAdsTableDisabled = true;
        debugPrint('EmergencyService: thix_safety_ads missing; disabling safety ads.');
        return const [];
      }
      debugPrint('EmergencyService: fetchSafetyAds PostgrestException: ${e.code} ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('EmergencyService: fetchSafetyAds failed: $e');
      return const [];
    }
  }

  Future<void> logPhoneCallIntent(String phone) async {
    await _insertAudit(action: 'launch_call_intent', entityType: 'thix_emergency_alerts', metadata: {'phone': phone});
  }

  Future<void> sendSmsAudit({required List<String> phones, required String body}) async {
    await _insertAudit(action: 'sms_prepare', entityType: 'thix_emergency_alerts', metadata: {'phones': phones, 'body': body});
  }

  Future<List<TrustedContact>> loadTrustedContacts() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return const [];

      final row = await _client.from('profiles').select('trusted_contacts').eq('id', uid).maybeSingle();
      final raw = row?['trusted_contacts'];
      if (raw is! List) return const [];
      return raw.map((e) => (e is Map) ? TrustedContact.fromJson(e.cast<String, dynamic>()) : null).whereType<TrustedContact>().toList(growable: false);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204') {
        debugPrint('EmergencyService: trusted_contacts column missing in profiles; returning empty list.');
        return const [];
      }
      debugPrint('EmergencyService: loadTrustedContacts PostgrestException: ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('EmergencyService: loadTrustedContacts failed: $e');
      return const [];
    }
  }

  Future<void> saveTrustedContacts(List<TrustedContact> contacts) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;

      final payload = contacts.map((c) => c.toJson()).toList(growable: false);
      final now = DateTime.now().toUtc().toIso8601String();

      await SupabaseSafeWrite.update(client: _client, table: 'profiles', patch: {'trusted_contacts': payload, 'updated_at': now}, filters: {'id': uid});
      await _insertAudit(action: 'trusted_contacts_save', entityType: 'profiles', entityId: uid, metadata: {'count': contacts.length});
    } catch (e) {
      debugPrint('EmergencyService: saveTrustedContacts failed: $e');
    }
  }
}

class TrustedContact {
  final String name;
  final String phone;
  const TrustedContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  static TrustedContact? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString().trim();
    final phone = (j['phone'] ?? '').toString().trim();
    if (name.isEmpty || phone.isEmpty) return null;
    return TrustedContact(name: name, phone: phone);
  }
}
