import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/models/thix_profile.dart';
import 'package:thix_id/services/profile_service.dart';
import 'package:thix_id/services/push_notification_service.dart';
import 'package:thix_id/services/supabase_safe_write.dart';
import 'package:thix_id/supabase/supabase_config.dart';

/// Supabase-backed auth + profile persistence.
///
/// - Auth: Supabase Auth (email/password)
/// - Profile row: created/updated in Supabase table `public.profiles`
class SupabaseAuthManager implements AuthManager {
  final SupabaseClient _client;
  final ProfileService _profiles;
  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);
  StreamSubscription<AuthState>? _sub;
  StreamSubscription<ThixProfile?>? _profileSub;

  SupabaseAuthManager({SupabaseClient? client, ProfileService? profiles})
      : _client = client ?? SupabaseConfig.client,
        _profiles = profiles ?? ProfileService();

  @override
  ValueListenable<AppUser?> get currentUserListenable => _currentUser;

  @override
  AppUser? get currentUser => _currentUser.value;

  @override
  Future<void> init() async {
    await _sub?.cancel();
    _sub = _client.auth.onAuthStateChange.listen((state) async {
      try {
        final user = state.session?.user;
        if (user == null) {
          await _profileSub?.cancel();
          _profileSub = null;
          _currentUser.value = null;
          unawaited(PushNotificationService.instance.onSignedOut());
          return;
        }
        final hydrated = await _hydrateUser(user);
        _currentUser.value = hydrated;
        _bindProfileSync(user.id);
        unawaited(PushNotificationService.instance.onSignedIn(userId: user.id));
      } catch (e, st) {
        debugPrint('SupabaseAuthManager: auth state hydrate failed err=$e');
        debugPrint('$st');
        await _profileSub?.cancel();
        _profileSub = null;
        _currentUser.value = null;
        unawaited(PushNotificationService.instance.onSignedOut());
      }
    });

    // Hydrate initial session if already persisted.
    // IMPORTANT: Supabase can sometimes expose a `currentUser` without a valid
    // session (e.g. after refresh/restore). Writes would then happen with anon
    // role and be rejected by RLS. We treat this as unauthenticated.
    final s = _client.auth.currentSession;
    final u = s?.user;
    if (u == null) {
      await _profileSub?.cancel();
      _profileSub = null;
      _currentUser.value = null;
      return;
    }
    final hydrated = await _hydrateUser(u);
    _currentUser.value = hydrated;
    _bindProfileSync(u.id);
  }

  void _bindProfileSync(String uid) {
    // Keep AuthController's `currentUser` always consistent with `public.profiles`.
    // This is what makes “Mon Compte” changes instantly visible everywhere.
    unawaited(_profileSub?.cancel());
    _profileSub = _profiles.streamMyProfile(uid).listen(
      (p) {
        if (p == null) return;
        final cur = _currentUser.value;
        if (cur == null || cur.id != uid) return;

        // Merge profile fields into the in-memory AppUser.
        final merged = cur.copyWith(
          thixId: p.thixId.trim().isEmpty ? cur.thixId : p.thixId.trim(),
          thixChat: (p.thixChat ?? '').trim().isEmpty ? cur.thixChat : (p.thixChat ?? '').trim(),
          displayName: p.displayName.trim().isEmpty ? cur.displayName : p.displayName.trim(),
          photoUrl: (p.photoUrl ?? '').trim().isEmpty ? cur.photoUrl : p.photoUrl,
          bio: p.bio ?? cur.bio,
          occupation: p.occupation ?? cur.occupation,
          profession: p.profession ?? cur.profession,
          countryOrOrigin: p.countryOrOrigin ?? cur.countryOrOrigin,
          contactPhone: p.contactPhone ?? cur.contactPhone,
          maritalStatus: p.maritalStatus ?? cur.maritalStatus,
          gender: p.gender ?? cur.gender,
          dateOfBirth: p.dateOfBirth ?? cur.dateOfBirth,
          placeOfBirth: p.placeOfBirth ?? cur.placeOfBirth,
          nationality: p.nationality ?? cur.nationality,
          address: p.address ?? cur.address,
          fatherName: p.fatherName ?? cur.fatherName,
          motherName: p.motherName ?? cur.motherName,
          emergencyContactName: p.emergencyContactName ?? cur.emergencyContactName,
          emergencyContactPhone: p.emergencyContactPhone ?? cur.emergencyContactPhone,
          emergencyContactRelation: p.emergencyContactRelation ?? cur.emergencyContactRelation,
          languages: p.languages,
          education: p.education,
          experience: p.experience,
          skills: p.skills,
          updatedAt: p.updatedAt,
        );

        // Avoid spamming notifications if nothing changed.
        final unchanged = merged.displayName == cur.displayName &&
            merged.photoUrl == cur.photoUrl &&
            merged.bio == cur.bio &&
            merged.countryOrOrigin == cur.countryOrOrigin &&
            merged.occupation == cur.occupation &&
            merged.profession == cur.profession &&
            merged.thixChat == cur.thixChat &&
            merged.thixId == cur.thixId &&
            merged.contactPhone == cur.contactPhone &&
            merged.maritalStatus == cur.maritalStatus &&
            merged.gender == cur.gender &&
            merged.dateOfBirth == cur.dateOfBirth &&
            merged.placeOfBirth == cur.placeOfBirth &&
            merged.nationality == cur.nationality &&
            merged.address == cur.address &&
            merged.fatherName == cur.fatherName &&
            merged.motherName == cur.motherName &&
            merged.emergencyContactName == cur.emergencyContactName &&
            merged.emergencyContactPhone == cur.emergencyContactPhone &&
            merged.emergencyContactRelation == cur.emergencyContactRelation &&
            listEquals(merged.languages, cur.languages) &&
            merged.updatedAt == cur.updatedAt;
        if (unchanged) return;
        _currentUser.value = merged;
      },
      onError: (e, st) {
        debugPrint('SupabaseAuthManager: profile sync stream failed uid=$uid err=$e');
        debugPrint('$st');
      },
    );
  }

  Future<AppUser> _hydrateUser(User user) async {
    final uid = user.id;
    final email = (user.email ?? '').toLowerCase();
    final meta = (user.userMetadata ?? const <String, dynamic>{});

    // Try to fetch private profile row.
    final row = await _selectProfileRow(uid);
    if (row == null) {
      // Ensure minimal row exists (id-based) so downstream services work.
      String? s(String k) {
        final v = meta[k];
        if (v == null) return null;
        final t = v.toString().trim();
        return t.isEmpty ? null : t;
      }

      List<String> strList(String k) {
        final v = meta[k];
        if (v is List) return v.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        return const <String>[];
      }

      final base = AppUser(
        id: uid,
        thixId: 'THIX-PENDING',
        thixChat: '',
        thixScore: null,
        email: email,
        phone: user.phone,
        displayName: (s('display_name') ?? 'Utilisateur THIX'),
        accountType: _accountTypeFromMeta(meta),
        photoUrl: null,
        bio: s('bio'),
        countryOrOrigin: s('country_or_origin') ?? s('countryOrOrigin'),
        contactPhone: s('contact_phone') ?? s('contactPhone'),
        maritalStatus: s('marital_status') ?? s('maritalStatus'),
        gender: s('gender'),
          occupation: s('occupation'),
          profession: s('profession'),
        dateOfBirth: s('date_of_birth') ?? s('dateOfBirth'),
        placeOfBirth: s('place_of_birth') ?? s('placeOfBirth'),
        nationality: s('nationality'),
        address: s('address'),
        fatherName: s('father_name') ?? s('fatherName'),
        motherName: s('mother_name') ?? s('motherName'),
        emergencyContactName: s('emergency_contact_name') ?? s('emergencyContactName'),
        emergencyContactPhone: s('emergency_contact_phone') ?? s('emergencyContactPhone'),
        emergencyContactRelation: s('emergency_contact_relation') ?? s('emergencyContactRelation'),
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: strList('languages'),
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _ensureProfileRow(userId: uid, user: base);
      await _profiles.ensureProfileExists(user: base);
      return base;
    }

    return _appUserFromProfileRow(uid: uid, email: email, row: row, phone: user.phone);
  }

  AccountType _accountTypeFromMeta(Map<String, dynamic>? meta) {
    final raw = (meta?['account_type'] ?? meta?['accountType'] ?? '').toString().trim().toLowerCase();
    if (raw == AccountType.enterprise.name) return AccountType.enterprise;
    return AccountType.personal;
  }

  AppUser _appUserFromProfileRow({
    required String uid,
    required String email,
    required String? phone,
    required Map<String, dynamic> row,
  }) {
    DateTime dt(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = dt(row['created_at'] ?? row['createdAt']);
    final updatedAt = dt(row['updated_at'] ?? row['updatedAt']);
    final accountTypeRaw = (row['account_type'] ?? row['accountType'] ?? AccountType.personal.name).toString();
    final accountType = AccountType.values.firstWhere((e) => e.name == accountTypeRaw, orElse: () => AccountType.personal);

    List<String> strList(Object? v) => (v is List) ? v.whereType<String>().toList(growable: false) : const <String>[];
    List<Map<String, dynamic>> mapList(Object? v) => (v is List) ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false) : const <Map<String, dynamic>>[];

    return AppUser(
      id: uid,
      thixId: (row['thix_id'] ?? row['thixId'] ?? row['thix_uid'] ?? row['thixUid'] ?? 'THIX-PENDING').toString(),
      thixChat: (row['thix_chat'] ?? row['thixChat'] ?? '').toString(),
      thixScore: (row['thix_score'] as num?)?.toInt() ?? (row['thixScore'] as num?)?.toInt(),
      email: email,
      phone: phone,
      displayName: (row['display_name'] ?? row['displayName'] ?? 'Utilisateur THIX').toString(),
      accountType: accountType,
      photoUrl: (row['avatar_url'] ?? row['photo_url'] ?? row['photoUrl'])?.toString(),
      bio: row['bio']?.toString(),
      countryOrOrigin: (row['country_or_origin'] ?? row['countryOrOrigin'])?.toString(),
      contactPhone: (row['contact_phone'] ?? row['contactPhone'])?.toString(),
      maritalStatus: (row['marital_status'] ?? row['maritalStatus'])?.toString(),
      gender: row['gender']?.toString(),
      occupation: (row['occupation'] ?? row['occupation_title'] ?? row['occupationTitle'])?.toString(),
      profession: (row['profession'] ?? row['job_title'] ?? row['jobTitle'])?.toString(),
      dateOfBirth: (row['date_of_birth'] ?? row['dateOfBirth'])?.toString(),
      placeOfBirth: (row['place_of_birth'] ?? row['placeOfBirth'])?.toString(),
      nationality: row['nationality']?.toString(),
      address: row['address']?.toString(),
      fatherName: (row['father_name'] ?? row['fatherName'])?.toString(),
      motherName: (row['mother_name'] ?? row['motherName'])?.toString(),
      emergencyContactName: (row['emergency_contact_name'] ?? row['emergencyContactName'])?.toString(),
      emergencyContactPhone: (row['emergency_contact_phone'] ?? row['emergencyContactPhone'])?.toString(),
      emergencyContactRelation: (row['emergency_contact_relation'] ?? row['emergencyContactRelation'])?.toString(),
      registrationStatus: (row['registration_status'] ?? row['registrationStatus'])?.toString(),
      education: mapList(row['education']),
      experience: mapList(row['experience']),
      skills: mapList(row['skills']),
      enrollments: mapList(row['enrollments']),
      languages: strList(row['languages']),
      biometricsEnabled: (row['biometrics_enabled'] as bool?) ?? (row['biometricsEnabled'] as bool?) ?? true,
      twoFaEnabled: (row['two_fa_enabled'] as bool?) ?? (row['twoFaEnabled'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Future<Map<String, dynamic>?> _selectProfileRow(String uid) async {
    // Single source of truth: `public.profiles`.
    try {
      final row = await _client.from('profiles').select('*').eq('id', uid).maybeSingle();
      if (row != null) return (row as Map).cast<String, dynamic>();
    } catch (e) {
      debugPrint('SupabaseAuthManager: profiles select by id failed uid=$uid err=$e');
    }
    return null;
  }

  Future<void> _ensureProfileRow({required String userId, required AppUser user}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    // Keep the upsert payload intentionally SMALL.
    // Many Supabase projects connected to Dreamflow have a reduced `profiles`
    // schema (only a few columns). Sending a large payload causes PostgREST
    // schema-cache errors (PGRST204) that can block critical flows like signup
    // and trial activation.
    final payload = <String, dynamic>{
      'id': userId,
      'thix_id': user.thixId,
      // Optional (only written if the column exists).
      'thix_chat': user.thixChat,
      'bio': user.bio,
      // Newer schema fields (safe-written; unknown columns are stripped).
      'profession': user.profession,
      'occupation': user.occupation,
      'display_name': user.displayName,
      'avatar_url': user.photoUrl,
      'country_or_origin': user.countryOrOrigin,
      'contact_phone': user.contactPhone,
      'marital_status': user.maritalStatus,
      'gender': user.gender,
      'date_of_birth': user.dateOfBirth,
      'place_of_birth': user.placeOfBirth,
      'nationality': user.nationality,
      'address': user.address,
      'father_name': user.fatherName,
      'mother_name': user.motherName,
      'emergency_contact_name': user.emergencyContactName,
      'emergency_contact_phone': user.emergencyContactPhone,
      'emergency_contact_relation': user.emergencyContactRelation,
      'languages': user.languages,
      'registration_status': user.registrationStatus,
      // Optional timestamps.
      'created_at': now,
      'updated_at': now,
    };

    try {
      await SupabaseSafeWrite.upsert(
        client: _client,
        table: 'profiles',
        payload: payload,
        onUnknownColumn: () async {
          try {
            await _client.functions.invoke('pgrst_schema_reload', body: const {});
          } catch (e) {
            debugPrint('SupabaseAuthManager: schema reload invoke failed err=$e');
            rethrow;
          }
        },
      );
    } catch (e) {
      debugPrint('SupabaseAuthManager: profiles upsert failed uid=$userId err=$e');
    }
  }

  @override
  Future<AppUser> signInWithEmailOrThixId({required String identifier, required String password, required bool rememberMe}) async {
    final id = identifier.trim();
    if (id.isEmpty) throw AuthException('Identifiant requis.');
    if (password.isEmpty) throw AuthException('Mot de passe requis.');

    // Supabase sign-in requires an email (unless you implement custom JWT/RPC).
    if (!id.contains('@')) {
      throw AuthException('Connexion via THIX ID non disponible. Utilisez votre email.');
    }

    try {
      final res = await _client.auth.signInWithPassword(email: id.toLowerCase(), password: password);
      final user = res.user;
      if (user == null) throw AuthException('Connexion échouée.');
      final hydrated = await _hydrateUser(user);
      _currentUser.value = hydrated;
      _bindProfileSync(user.id);
      return hydrated;
    } on AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } on AuthApiException catch (e, st) {
      debugPrint('SupabaseAuthManager: signIn AuthApiException status=${e.statusCode} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('SupabaseAuthManager: signIn failed err=$e');
      debugPrint('$st');
      throw AuthException('Connexion impossible.');
    }
  }

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    Map<String, dynamic>? profileDraft,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) throw AuthException('Email invalide.');
    if (password.trim().length < 8) throw AuthException('Le mot de passe doit contenir au moins 8 caractères.');

    try {
      final userMeta = <String, dynamic>{
        'display_name': displayName.trim().isEmpty ? 'Utilisateur THIX' : displayName.trim(),
        'account_type': accountType.name,
        ...?profileDraft,
      };

      final res = await _client.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: userMeta,
      );

      final session = res.session;
      final user = res.user;
      // IMPORTANT:
      // If email confirmation is enabled, Supabase returns a user but NO session.
      // Without a session, requests use the anon role and RLS will reject writes
      // to `public.profiles` (42501).
      if (user == null || session == null) {
        // Email confirmation enabled: metadata IS saved in Supabase Auth, but we
        // cannot write `public.profiles` yet due to missing JWT (RLS).
        throw AuthException(
          'Inscription enregistrée. Confirmez votre email puis connectez-vous: votre profil sera créé automatiquement.',
        );
      }

      final now = DateTime.now();
      final appUser = AppUser(
        id: user.id,
        thixId: 'THIX-PENDING',
        thixChat: '',
        thixScore: null,
        email: normalizedEmail,
        phone: user.phone,
        displayName: (() {
          final m = userMeta['display_name']?.toString().trim() ?? '';
          if (m.isNotEmpty) return m;
          final d = displayName.trim();
          return d.isEmpty ? 'Utilisateur THIX' : d;
        })(),
        accountType: accountType,
        photoUrl: null,
        bio: null,
        countryOrOrigin: (userMeta['country_or_origin'] ?? userMeta['countryOrOrigin'])?.toString(),
        contactPhone: (userMeta['contact_phone'] ?? userMeta['contactPhone'])?.toString(),
        maritalStatus: (userMeta['marital_status'] ?? userMeta['maritalStatus'])?.toString(),
        gender: userMeta['gender']?.toString(),
        occupation: userMeta['occupation']?.toString(),
        profession: userMeta['profession']?.toString(),
        dateOfBirth: (userMeta['date_of_birth'] ?? userMeta['dateOfBirth'])?.toString(),
        placeOfBirth: (userMeta['place_of_birth'] ?? userMeta['placeOfBirth'])?.toString(),
        nationality: userMeta['nationality']?.toString(),
        address: userMeta['address']?.toString(),
        fatherName: (userMeta['father_name'] ?? userMeta['fatherName'])?.toString(),
        motherName: (userMeta['mother_name'] ?? userMeta['motherName'])?.toString(),
        emergencyContactName: (userMeta['emergency_contact_name'] ?? userMeta['emergencyContactName'])?.toString(),
        emergencyContactPhone: (userMeta['emergency_contact_phone'] ?? userMeta['emergencyContactPhone'])?.toString(),
        emergencyContactRelation: (userMeta['emergency_contact_relation'] ?? userMeta['emergencyContactRelation'])?.toString(),
        education: const [],
        experience: const [],
        skills: const [],
        enrollments: const [],
        languages: (userMeta['languages'] is List) ? (userMeta['languages'] as List).whereType<String>().toList(growable: false) : const [],
        biometricsEnabled: true,
        twoFaEnabled: false,
        createdAt: now,
        updatedAt: now,
      );

      await _ensureProfileRow(userId: user.id, user: appUser);
      await _profiles.ensureProfileExists(user: appUser);

      _currentUser.value = appUser;
      return appUser;
    } on AuthApiException catch (e, st) {
      debugPrint('SupabaseAuthManager: register AuthApiException status=${e.statusCode} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('SupabaseAuthManager: register failed err=$e');
      debugPrint('$st');
      if (e is AuthException) rethrow;
      throw AuthException('Inscription impossible.');
    }
  }

  @override
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) async {
    throw AuthException('Connexion téléphone indisponible dans cette version.');
  }

  @override
  Future<AppUser> confirmPhoneCode({required PhoneAuthSession session, required String smsCode, String? displayName, AccountType accountType = AccountType.personal}) async {
    throw AuthException('Connexion téléphone indisponible dans cette version.');
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _profileSub?.cancel();
    _profileSub = null;
    _currentUser.value = null;
  }

  @override
  Future<void> deleteAccount() async {
    // Supabase client SDK cannot delete users with anon key.
    // This must be done via an Edge Function using service_role.
    throw AuthException('Suppression du compte indisponible (nécessite une fonction serveur).');
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final normalized = newEmail.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await _client.auth.updateUser(UserAttributes(email: normalized));
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await _client.auth.resetPasswordForEmail(normalized);
    } on AuthApiException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  @override
  Future<void> updateCurrentUser(AppUser user) async {
    final current = currentUser;
    if (current == null) throw AuthException('Session expirée.');
    if (current.id != user.id) throw AuthException('Utilisateur courant différent.');

    try {
      await _ensureProfileRow(userId: user.id, user: user);
      await _profiles.ensureProfileExists(user: user);
    } catch (e) {
      debugPrint('SupabaseAuthManager: updateCurrentUser failed uid=${user.id} err=$e');
    }
    _currentUser.value = user;
    _bindProfileSync(user.id);
  }

  String _mapAuthError(AuthApiException e) {
    final msg = (e.message).trim();
    final code = (e.statusCode ?? 0).toString();
    if (msg.toLowerCase().contains('invalid login credentials')) return 'Identifiant ou mot de passe incorrect.';
    if (msg.toLowerCase().contains('user already registered')) return 'Un compte existe déjà avec cet email.';
    if (msg.toLowerCase().contains('password')) return 'Mot de passe invalide.';
    return msg.isNotEmpty ? 'Erreur d’authentification ($code): $msg' : 'Erreur d’authentification.';
  }

  bool _isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}
