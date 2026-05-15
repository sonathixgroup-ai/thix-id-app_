import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/local_user_store.dart';

class LocalAuthManager implements AuthManager {
  static const _kLockoutUntilMs = 'thix_auth_lockout_until_ms_v1';
  static const _kFailedAttempts = 'thix_auth_failed_attempts_v1';

  final LocalUserStore _store;
  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);
  List<AppUser> _users = const [];

  LocalAuthManager({LocalUserStore? store}) : _store = store ?? LocalUserStore();

  @override
  ValueListenable<AppUser?> get currentUserListenable => _currentUser;

  @override
  AppUser? get currentUser => _currentUser.value;

  @override
  Future<void> init() async {
    _users = await _store.loadUsers();
    final sessionId = await _store.loadSessionUserId();
    if (sessionId == null) {
      _currentUser.value = null;
      return;
    }
    _currentUser.value = _users.firstWhereOrNull((u) => u.id == sessionId);
  }

  @override
  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_kLockoutUntilMs);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lockoutUntil != null && lockoutUntil > nowMs) {
      final remaining = Duration(milliseconds: lockoutUntil - nowMs);
      throw AuthException('Compte temporairement verrouillé. Réessayez dans ${remaining.inSeconds}s.');
    }

    final normalized = identifier.trim().toLowerCase();
    final user = _users.firstWhere(
      (u) => u.email.toLowerCase() == normalized || u.thixId.toLowerCase() == normalized,
      orElse: () => throw AuthException('Identifiant introuvable.'),
    );

    final ok = _verifyPassword(password: password, saltB64: user.passwordSaltB64, expectedHashHex: user.passwordHashHex);
    if (!ok) {
      final attempts = (prefs.getInt(_kFailedAttempts) ?? 0) + 1;
      await prefs.setInt(_kFailedAttempts, attempts);
      if (attempts >= 5) {
        await prefs.setInt(_kLockoutUntilMs, DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch);
        await prefs.setInt(_kFailedAttempts, 0);
        throw AuthException('Trop de tentatives. Verrouillage 30s.');
      }
      throw AuthException('Mot de passe incorrect.');
    }

    await prefs.setInt(_kFailedAttempts, 0);
    await _store.saveSession(userId: user.id, rememberMe: rememberMe);
    _currentUser.value = user;
    return user;
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
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    if (password.trim().length < 8) throw AuthException('Le mot de passe doit contenir au moins 8 caractères.');
    if (_users.any((u) => u.email.toLowerCase() == normalized)) throw AuthException('Un compte existe déjà avec cet email.');

    // THIX UID is assigned only after payment activation.
    final thixId = 'THIX-PENDING';
    final salt = _randomBytes(16);
    final hashHex = _hashPassword(password: password, salt: salt);
    final now = DateTime.now();
    final user = AppUser(
      id: _randomId(),
      thixId: thixId,
      thixChat: '',
      thixScore: null,
      email: normalized,
      phone: null,
      displayName: displayName.trim().isEmpty ? 'Utilisateur THIX' : displayName.trim(),
      accountType: accountType,
      photoUrl: null,
      bio: null,
      countryOrOrigin: null,
      education: const [],
      experience: const [],
      skills: const [],
      enrollments: const [],
      languages: const [],
      biometricsEnabled: true,
      twoFaEnabled: false,
      createdAt: now,
      updatedAt: now,
      passwordSaltB64: base64Encode(salt),
      passwordHashHex: hashHex,
    );
    _users = [..._users, user];
    await _store.saveUsers(_users);
    await _store.saveSession(userId: user.id, rememberMe: rememberMe);
    _currentUser.value = user;
    return user;
  }

  @override
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) async {
    throw AuthException('Connexion téléphone indisponible en mode local.');
  }

  @override
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    throw AuthException('Connexion téléphone indisponible en mode local.');
  }

  @override
  Future<void> signOut() async {
    await _store.clearSession();
    _currentUser.value = null;
  }

  @override
  Future<void> deleteAccount() async {
    final u = currentUser;
    if (u == null) return;
    _users = _users.where((x) => x.id != u.id).toList(growable: false);
    await _store.saveUsers(_users);
    await signOut();
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final u = currentUser;
    if (u == null) throw AuthException('Session expirée.');
    final normalized = newEmail.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    if (_users.any((x) => x.email.toLowerCase() == normalized && x.id != u.id)) throw AuthException('Cet email est déjà utilisé.');

    _users = _users.map((x) {
      if (x.id != u.id) return x;
      return x.copyWith(email: normalized, updatedAt: DateTime.now());
    }).toList(growable: false);
    await _store.saveUsers(_users);
    _currentUser.value = _users.firstWhere((x) => x.id == u.id);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    // Local-only: no email service. In production, replace with backend provider.
    debugPrint('LocalAuthManager: password reset requested for $email (no-op in local mode)');
  }

  @override
  Future<void> updateCurrentUser(AppUser user) async {
    final current = currentUser;
    if (current == null) throw AuthException('Session expirée.');
    if (current.id != user.id) throw AuthException('Utilisateur courant différent.');
    _users = _users.map((u) => u.id == user.id ? user : u).toList(growable: false);
    await _store.saveUsers(_users);
    _currentUser.value = user;
  }

  bool _verifyPassword({required String password, required String saltB64, required String expectedHashHex}) {
    try {
      final salt = base64Decode(saltB64);
      final hashHex = _hashPassword(password: password, salt: salt);
      return hashHex == expectedHashHex;
    } catch (_) {
      return false;
    }
  }

  String _hashPassword({required String password, required List<int> salt}) {
    // SHA-256(salt || password). In production, prefer an adaptive KDF (Argon2/bcrypt/PBKDF2).
    final bytes = Uint8List.fromList([...salt, ...utf8.encode(password)]);
    return sha256.convert(bytes).toString();
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256), growable: false));
  }

  String _randomId() {
    final rnd = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(16, (_) => rnd.nextInt(256), growable: false));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  // Note: UID generation is now handled by Supabase after payment.

  bool _isValidEmail(String email) {
    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return r.hasMatch(email);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T) test) {
    for (final v in this) {
      if (test(v)) return v;
    }
    return null;
  }
}
