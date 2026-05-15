import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/services/thix_id_service.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Backward-compatible user service.
///
/// The app historically used Firestore for user profiles. This project is now
/// Supabase-only, but many UI pages still depend on the same service name.
///
/// This implementation reads/writes exclusively from Supabase table:
/// - `public.profiles`
class FirestoreUserService {
  final SupabaseClient _client;
  final ProfileService _profiles;

  FirestoreUserService({SupabaseClient? client, ProfileService? profiles})
      : _client = client ?? SupabaseConfig.client,
        _profiles = profiles ?? ProfileService();

  static const _table = ProfileService.table;

  /// Returns the authenticated user id from Supabase session.
  ///
  /// Throws if the client is not authenticated. This prevents accidental writes
  /// with the anon role which would trigger RLS errors (42501).
  String _requireAuthedUid() {
    final uid = _client.auth.currentSession?.user.id;
    if (uid == null || uid.trim().isEmpty) {
      throw StateError('Not authenticated (no Supabase session).');
    }
    return uid;
  }

  Future<void> _reloadSchemaCache() async {
    try {
      // Prefer DB-side NOTIFY-based reload (no edge function required).
      try {
        await _client.rpc('pgrst_schema_reload');
        debugPrint('FirestoreUserService: requested PostgREST schema reload via RPC');
        return;
      } catch (e) {
        debugPrint('FirestoreUserService: schema reload RPC failed (will try edge function) err=$e');
      }

      // Backward-compat: older projects may provide an edge function.
      await _client.functions.invoke('pgrst_schema_reload', body: const {});
      debugPrint('FirestoreUserService: requested PostgREST schema reload via edge function');
    } catch (e) {
      debugPrint('FirestoreUserService: schema reload invoke failed err=$e');
      rethrow;
    }
  }

  Future<AppUser?> fetchUserByUid(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return null;
    try {
      final row = await _client.from(_table).select('*').eq('id', id).maybeSingle();
      if (row == null) return null;
      return _appUserFromProfileRow((row as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): fetchUserByUid failed uid=$uid err=$e');
      return null;
    }
  }

  Future<AppUser?> fetchUserByThixId(String thixId) async {
    final normalized = thixId.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final row = await _client.from(_table).select('*').eq('thix_id', normalized).maybeSingle();
      if (row == null) return null;
      final m = (row as Map).cast<String, dynamic>();
      return _appUserFromProfileRow(m);
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): fetchUserByThixId failed thix=$thixId err=$e');
      return null;
    }
  }

  Future<AppUser?> fetchUserByThixChat(String handle) async {
    final raw = handle.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.startsWith('@') ? raw : '@$raw';
    try {
      // Use ilike so user can type @Handle or @handle.
      final row = await _client.from(_table).select('*').ilike('thix_chat', normalized).maybeSingle();
      if (row == null) return null;
      return _appUserFromProfileRow((row as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): fetchUserByThixChat failed handle=$handle err=$e');
      return null;
    }
  }

  /// Searches profiles to help users find someone to start a chat with.
  ///
  /// This is a best-effort search (RLS must allow reading `display_name`,
  /// `thix_id`, and/or `thix_chat`).
  Future<List<AppUser>> searchUsers(String query, {int limit = 12, String? excludeUid}) async {
    final q = query.trim();
    if (q.isEmpty) return const <AppUser>[];
    final safeLimit = limit.clamp(1, 50);
    try {
      final needle = q.replaceAll('%', '').replaceAll('_', '');
      final like = '%$needle%';
      final rows = await _client
          .from(_table)
          .select('id, user_id, display_name, thix_id, thix_chat, avatar_url, photo_url, created_at, updated_at')
          .or('display_name.ilike.$like,thix_id.ilike.$like,thix_chat.ilike.$like')
          .limit(safeLimit);
      if (rows is! List) return const <AppUser>[];
      final list = rows.whereType<Map>().map((m) => _appUserFromProfileRow(m.cast<String, dynamic>())).toList(growable: false);
      if (excludeUid == null || excludeUid.trim().isEmpty) return list;
      final ex = excludeUid.trim();
      return list.where((u) => u.id != ex).toList(growable: false);
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): searchUsers failed query=$query err=$e');
      return const <AppUser>[];
    }
  }

  Future<void> updateProfile({
    required String uid,
    int? thixScore,
    String? displayName,
    String? fullName,
    String? competence,
    String? bio,
    String? countryOrOrigin,
    String? contactPhone,
    String? maritalStatus,
    String? gender,
    String? profession,
    String? occupation,
    String? dateOfBirth,
    String? placeOfBirth,
    String? nationality,
    String? address,
    String? fatherName,
    String? motherName,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? originProvince,
    String? originTerritory,
    String? originSector,
    String? residenceCountry,
    String? residenceProvince,
    String? residenceTerritory,
    String? residenceCity,
    String? residenceCommune,
    String? residenceQuarter,
    String? residenceAvenue,
    String? residenceNumber,
    List<Map<String, dynamic>>? emergencyContacts,
    String? height,
    String? weight,
    String? bloodGroup,
    bool? hasPhysicalDisability,
    String? physicalDisabilityDescription,
    String? nationalIdNumber,
    String? idDocumentType,
    String? idDocumentIssueDate,
    String? idDocumentExpiryDate,
    String? idDocumentIssuePlace,
    String? idDocumentFrontDocId,
    String? idDocumentBackDocId,
    String? idDocumentSelfieDocId,
    String? idVerificationStatus,
    List<Map<String, dynamic>>? languagesDetailed,
    List<Map<String, dynamic>>? trainings,
    String? thixChat,
    String? registrationStatus,
    String? photoUrl,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? skills,
    List<Map<String, dynamic>>? enrollments,
    List<String>? languages,
    bool? biometricsEnabled,
    bool? twoFaEnabled,
  }) async {
    // Single source of truth for who is allowed to write is the Supabase session.
    // This ensures the payload `id` matches `auth.uid()` for RLS policies.
    final sessionUid = _requireAuthedUid();
    final userId = uid.trim();
    if (userId.isEmpty) return;
    if (userId != sessionUid) {
      debugPrint('FirestoreUserService.updateProfile: uid mismatch. param=$userId session=$sessionUid. Using session uid.');
    }
    final targetUid = sessionUid;
    final now = DateTime.now().toUtc().toIso8601String();
    final patch = <String, dynamic>{'updated_at': now};
    void put(String k, Object? v) {
      if (v == null) return;
      if (v is String) {
        patch[k] = v.trim().isEmpty ? null : v.trim();
      } else {
        patch[k] = v;
      }
    }

    void putAliases(List<String> keys, Object? v) {
      for (final k in keys) {
        put(k, v);
      }
    }

    put('display_name', displayName);
    // Fix mapping: also write to `full_name` when present in the schema.
    put('full_name', fullName ?? displayName);
    put('competence', competence);
    put('bio', bio);
    put('country_or_origin', countryOrOrigin);
    put('contact_phone', contactPhone);
    put('marital_status', maritalStatus);
    put('gender', gender);
    // New column in refreshed schema.
    put('profession', profession);
    put('occupation', occupation);
    put('date_of_birth', dateOfBirth);
    put('place_of_birth', placeOfBirth);
    put('nationality', nationality);
    put('address', address);
    put('father_name', fatherName);
    put('mother_name', motherName);

    // Emergency contact fields (must map exactly to `public.profiles` columns).
    put('emergency_contact_name', emergencyContactName);
    put('emergency_contact_phone', emergencyContactPhone);
    put('emergency_contact_relation', emergencyContactRelation);

    // Origin / residence.
    //
    // IMPORTANT:
    // Connected Supabase projects may have different column names for residence
    // (ex: `pays_residence`, `province_residence`, `ville_residence`, etc.).
    // We write aliases to prevent silent “not saved” issues when one variant is
    // missing.
    putAliases(['origin_province', 'province_origine'], originProvince);
    putAliases(['origin_territory', 'territoire_origine'], originTerritory);
    putAliases(['origin_sector', 'secteur_origine'], originSector);

    putAliases(['residence_country', 'pays_residence', 'current_residence_country'], residenceCountry);
    putAliases(['residence_province', 'province_residence'], residenceProvince);
    putAliases(['residence_territory', 'territoire_residence'], residenceTerritory);
    putAliases(['residence_city', 'ville_residence'], residenceCity);
    putAliases(['residence_commune', 'commune_residence'], residenceCommune);
    putAliases(['residence_quarter', 'quartier_residence'], residenceQuarter);
    putAliases(['residence_avenue', 'avenue_residence'], residenceAvenue);
    putAliases(['residence_number', 'numero_residence'], residenceNumber);

    if (emergencyContacts != null) patch['emergency_contacts'] = emergencyContacts;
    put('height', height);
    put('weight', weight);
    put('blood_group', bloodGroup);
    if (hasPhysicalDisability != null) patch['has_physical_disability'] = hasPhysicalDisability;
    put('physical_disability_description', physicalDisabilityDescription);
    put('national_id_number', nationalIdNumber);
    put('id_document_type', idDocumentType);
    put('id_document_issue_date', idDocumentIssueDate);
    put('id_document_expiry_date', idDocumentExpiryDate);
    put('id_document_issue_place', idDocumentIssuePlace);
    put('id_document_front_doc_id', idDocumentFrontDocId);
    put('id_document_back_doc_id', idDocumentBackDocId);
    put('id_document_selfie_doc_id', idDocumentSelfieDocId);
    put('id_verification_status', idVerificationStatus);
    if (languagesDetailed != null) patch['languages_detailed'] = languagesDetailed;
    if (trainings != null) patch['trainings'] = trainings;
    put('thix_chat', thixChat);
    put('registration_status', registrationStatus);
    put('avatar_url', photoUrl);

    if (thixScore != null) patch['thix_score'] = thixScore;
    if (education != null) patch['education'] = education;
    if (experience != null) patch['experience'] = experience;
    if (skills != null) patch['skills'] = skills;
    if (enrollments != null) patch['enrollments'] = enrollments;
    if (languages != null) patch['languages'] = languages.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList(growable: false);
    if (biometricsEnabled != null) patch['biometrics_enabled'] = biometricsEnabled;
    if (twoFaEnabled != null) patch['two_fa_enabled'] = twoFaEnabled;

    try {
      // Prefer UPDATE over UPSERT to reduce schema/cache failures.
      // Some connected Supabase projects have a reduced `public.profiles` schema.
      // Updating only the provided patch is less error-prone than upserting a
      // larger payload.
      await SupabaseSafeWrite.update(
        client: _client,
        table: _table,
        patch: patch,
        filters: {'id': targetUid},
        onUnknownColumn: _reloadSchemaCache,
      );
    } on PostgrestException catch (e) {
      // If the row doesn't exist yet, fall back to a minimal upsert.
      // (e.g., first-time signup where the profile row was not created yet).
      final msg = e.message.toLowerCase();
      final isMissingRow = msg.contains('0 rows') || msg.contains('not found');
      if (isMissingRow) {
        await SupabaseSafeWrite.upsert(client: _client, table: _table, payload: {'id': targetUid, ...patch}, onUnknownColumn: _reloadSchemaCache);
        return;
      }
      debugPrint('FirestoreUserService(Supabase): updateProfile failed uid=$uid err=$e');
      rethrow;
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): updateProfile failed uid=$uid err=$e');
      rethrow;
    }
  }

  /// In Supabase, THIX UID is assigned by the activation RPC after payment.
  ///
  /// For pre-payment flows, we just ensure the row exists and return current
  /// value if already present.
  Future<String> ensureThixId({required String uid, required String countryCode}) async {
    final sessionUid = _requireAuthedUid();
    final userId = uid.trim();
    if (userId.isEmpty) throw Exception('UID requis.');
    final targetUid = sessionUid;
    try {
      final row = await _client.from(_table).select('thix_id').eq('id', targetUid).maybeSingle();
      final existing = (row?['thix_id'] ?? '').toString().trim();
      if (existing.isNotEmpty && existing != 'THIX-PENDING' && existing != 'THIX-000000') return existing;
      // Ensure row exists with placeholder.
      // IMPORTANT: use schema-safe upsert so signup can't be blocked by
      // PostgREST schema cache (PGRST204) or optional columns.
      await SupabaseSafeWrite.upsert(
        client: _client,
        table: _table,
        payload: {
          'id': targetUid,
          'thix_id': existing.isEmpty ? 'THIX-PENDING' : existing,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onUnknownColumn: _reloadSchemaCache,
      );
      return existing.isEmpty ? 'THIX-PENDING' : existing;
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): ensureThixId failed uid=$uid err=$e');
      return 'THIX-PENDING';
    }
  }

  /// Assigns a real, unique THIX ID in `public.profiles.thix_id` if missing.
  ///
  /// This is required even when payments are fictive: the ID must work everywhere
  /// (search, public profile, chat lookup).
  Future<String> assignRealThixIdIfMissing({required String uid, String? countryOrOrigin, String? displayName}) async {
    final sessionUid = _requireAuthedUid();
    if (uid.trim().isEmpty) throw Exception('UID requis.');
    final targetUid = sessionUid;
    try {
      // Some projects don't have `country_or_origin` column. Avoid selecting it.
      final row = await _client.from(_table).select('thix_id').eq('id', targetUid).maybeSingle();
      final existing = (row?['thix_id'] ?? '').toString().trim().toUpperCase();
      if (existing.isNotEmpty && existing != 'THIX-PENDING' && existing != 'THIX-000000') return existing;

      final cc = ThixIdService.inferCountryCode(selectedOrUserProvided: countryOrOrigin);
      final nameForId = (displayName ?? '').trim().isEmpty ? 'User' : (displayName ?? '').trim();
      // Generate candidate and ensure uniqueness.
      // We use a DB-side unique constraint (migration) + retry loop to handle
      // concurrency races safely.
      for (var i = 0; i < 20; i++) {
        final candidate = ThixIdService.generateV2(countryCode: cc, displayName: nameForId).toUpperCase();
        try {
          await SupabaseSafeWrite.upsert(
            client: _client,
            table: _table,
            payload: {
              'id': targetUid,
              'thix_id': candidate,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onUnknownColumn: _reloadSchemaCache,
          );
          return candidate;
        } catch (e) {
          // If candidate collides with an existing thix_id, retry.
          if (_looksLikeUniqueViolation(e)) continue;
          rethrow;
        }
      }
      throw Exception('Impossible de générer un THIX ID unique.');
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): assignRealThixIdIfMissing failed uid=$uid err=$e');
      rethrow;
    }
  }

  bool _looksLikeUniqueViolation(Object e) {
    if (e is PostgrestException) {
      // Postgres unique_violation = 23505.
      if (e.code == '23505') return true;
      final msg = (e.message).toLowerCase();
      if (msg.contains('duplicate') || msg.contains('unique')) return true;
    }
    final raw = e.toString().toLowerCase();
    return raw.contains('23505') || raw.contains('unique') || raw.contains('duplicate');
  }

  Future<String> ensureThixChat({required String uid, String? desired}) async {
    final sessionUid = _requireAuthedUid();
    final userId = uid.trim();
    if (userId.isEmpty) throw Exception('UID requis.');
    final targetUid = sessionUid;
    final raw = (desired ?? '').trim();
    final cleaned = raw.startsWith('@') ? raw.substring(1) : raw;
    final key = cleaned.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '_');
    if (key.length < 3) throw Exception('THIX CHAT invalide.');
    final handle = '@${key.length > 20 ? key.substring(0, 20) : key}';
    await updateProfile(uid: targetUid, thixChat: handle);
    return handle;
  }

  /// Convenience: call the Supabase activation RPC (via ProfileService).
  Future<String> activateAfterPayment({
    required String uid,
    required String countryCode,
    required String displayName,
    required String txRef,
    required String method,
    required num amount,
    required String currency,
    String? photoUrl,
  }) {
    return _profiles.activateAccountAfterPayment(
      userId: uid,
      countryCode: countryCode,
      displayName: displayName,
      txRef: txRef,
      method: method,
      amount: amount,
      currency: currency,
      photoUrl: photoUrl,
    );
  }

  // ---- Payments (Supabase) ----

  /// Writes a payment-like event.
  ///
  /// In Supabase migrations, the canonical table is `thix_payments`.
  /// UI expects a richer payload (title/meta). We store `title` in `method`
  /// as a best-effort fallback when custom columns aren't present.
  Future<void> addPaymentTransaction({
    required String uid,
    required String title,
    required num amount,
    String currency = 'USD',
    String method = 'Simulé',
    String status = 'paid',
    String? transactionRef,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final txRef = (transactionRef ?? '').trim().isEmpty
          ? 'tx_${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, uid.length >= 6 ? 6 : uid.length)}'
          : transactionRef!.trim();
      await _client.from('thix_payments').insert({
        'user_id': uid,
        'tx_ref': txRef,
        'method': '$method • $title',
        'amount': amount,
        'currency': currency,
        'status': status,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (meta != null && meta.isNotEmpty) {
        // Optional extended table if present.
        try {
          await _client.from('thix_payment_meta').insert({
            'user_id': uid,
            'tx_ref': txRef,
            'meta': meta,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('FirestoreUserService(Supabase): addPaymentTransaction failed uid=$uid err=$e');
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamPayments(String uid) async* {
    while (true) {
      try {
        final rows = await _client.from('thix_payments').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(50);
        if (rows is List) {
          yield rows.map((e) => (e as Map).cast<String, dynamic>()).toList(growable: false);
        } else {
          yield const <Map<String, dynamic>>[];
        }
      } catch (e) {
        debugPrint('FirestoreUserService(Supabase): streamPayments poll failed uid=$uid err=$e');
        yield const <Map<String, dynamic>>[];
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  // ---- Security events (Supabase) ----

  bool _securityEventsTableMissing = false;

  Future<void> logSecurityEvent({required String uid, required String type, String? label, Map<String, dynamic>? meta}) async {
    try {
      if (_securityEventsTableMissing) return;
      await _client.from('thix_security_events').insert({
        'user_id': uid,
        'type': type,
        'label': label,
        'meta': meta ?? const <String, dynamic>{},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'))) {
        _securityEventsTableMissing = true;
        debugPrint('FirestoreUserService(Supabase): table missing (thix_security_events). Disabling logging. err=${e.message}');
        return;
      }
      // Table might not exist yet; keep app usable.
      debugPrint('FirestoreUserService(Supabase): logSecurityEvent failed uid=$uid err=$e');
    }
  }

  Stream<List<Map<String, dynamic>>> streamSecurityEvents(String uid) async* {
    while (true) {
      try {
        if (_securityEventsTableMissing) {
          yield const <Map<String, dynamic>>[];
          return;
        }
        final rows = await _client.from('thix_security_events').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(40);
        if (rows is List) {
          yield rows.map((e) => (e as Map).cast<String, dynamic>()).toList(growable: false);
        } else {
          yield const <Map<String, dynamic>>[];
        }
      } catch (e) {
        if (e is PostgrestException && (e.code == 'PGRST205' || e.message.contains('Could not find the table'))) {
          _securityEventsTableMissing = true;
          debugPrint('FirestoreUserService(Supabase): table missing (thix_security_events). Disabling polling. err=${e.message}');
          yield const <Map<String, dynamic>>[];
          return;
        }
        debugPrint('FirestoreUserService(Supabase): streamSecurityEvents poll failed uid=$uid err=$e');
        yield const <Map<String, dynamic>>[];
      }
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  AppUser _appUserFromProfileRow(Map<String, dynamic> row) {
    DateTime dt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final uid = (row['user_id'] ?? row['id'] ?? '').toString();
    return AppUser(
      id: uid,
      thixId: (row['thix_id'] ?? 'THIX-PENDING').toString(),
      thixChat: (row['thix_chat'] ?? '').toString(),
      thixScore: (row['thix_score'] as num?)?.toInt(),
      email: '',
      phone: null,
      displayName: (row['display_name'] ?? 'Utilisateur THIX').toString(),
      accountType: AccountType.personal,
      photoUrl: (row['photo_url'] ?? row['avatar_url'])?.toString(),
      bio: row['bio']?.toString(),
      countryOrOrigin: row['country_or_origin']?.toString(),
      contactPhone: row['contact_phone']?.toString(),
      maritalStatus: row['marital_status']?.toString(),
      gender: row['gender']?.toString(),
      occupation: (row['occupation'] ?? row['occupation_title'])?.toString(),
      profession: (row['profession'] ?? row['job_title'])?.toString(),
      dateOfBirth: row['date_of_birth']?.toString(),
      placeOfBirth: row['place_of_birth']?.toString(),
      nationality: row['nationality']?.toString(),
      address: row['address']?.toString(),
      fatherName: row['father_name']?.toString(),
      motherName: row['mother_name']?.toString(),
      emergencyContactName: row['emergency_contact_name']?.toString(),
      emergencyContactPhone: row['emergency_contact_phone']?.toString(),
      emergencyContactRelation: row['emergency_contact_relation']?.toString(),
      registrationStatus: row['registration_status']?.toString(),
      education: (row['education'] is List)
          ? (row['education'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false)
          : const [],
      experience: (row['experience'] is List)
          ? (row['experience'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false)
          : const [],
      skills: (row['skills'] is List)
          ? (row['skills'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false)
          : const [],
      enrollments: (row['enrollments'] is List)
          ? (row['enrollments'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false)
          : const [],
      languages: (row['languages'] is List) ? (row['languages'] as List).whereType<String>().toList(growable: false) : const [],
      biometricsEnabled: (row['biometrics_enabled'] as bool?) ?? true,
      twoFaEnabled: (row['two_fa_enabled'] as bool?) ?? false,
      createdAt: dt(row['created_at']),
      updatedAt: dt(row['updated_at']),
    );
  }
}
