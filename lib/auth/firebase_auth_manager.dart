import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:thix_id/auth/auth_manager.dart';
import 'package:thix_id/models/app_user.dart';
import 'package:thix_id/services/thix_id_service.dart';

/// Firebase-backed auth + user profile persistence.
///
/// - Auth: Firebase Auth (email/password)
/// - Profile: Firestore `users/{uid}`
class FirebaseAuthManager implements AuthManager {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  final ValueNotifier<AppUser?> _currentUser = ValueNotifier<AppUser?>(null);
  StreamSubscription<fb.User?>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  FirebaseAuthManager({fb.FirebaseAuth? auth, FirebaseFirestore? db}) : _auth = auth ?? fb.FirebaseAuth.instance, _db = db ?? FirebaseFirestore.instance;

  Future<void> _logSecurityEvent({required String uid, required String type, String? label, Map<String, dynamic>? meta}) async {
    try {
      await _db.collection('users').doc(uid).collection('security_events').add({
        'type': type,
        'label': label,
        'meta': meta,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('FirebaseAuthManager: logSecurityEvent failed uid=$uid type=$type err=$e');
    }
  }

  @override
  ValueListenable<AppUser?> get currentUserListenable => _currentUser;

  @override
  AppUser? get currentUser => _currentUser.value;

  @override
  Future<void> init() async {
    // Web persistence helps prevent unexpected auth resets and reduces
    // some platform-channel edge cases.
    if (kIsWeb) {
      try {
        await _auth.setPersistence(fb.Persistence.LOCAL);
      } catch (e) {
        debugPrint('FirebaseAuthManager: setPersistence failed err=$e');
      }
    }
    await _sub?.cancel();
    await _profileSub?.cancel();
    _sub = _auth.authStateChanges().listen((u) async {
      if (u == null) {
        await _profileSub?.cancel();
        _profileSub = null;
        _currentUser.value = null;
        return;
      }

      await _profileSub?.cancel();
      _profileSub = _db.collection('users').doc(u.uid).snapshots().listen(
        (snap) {
          if (!snap.exists) {
            _currentUser.value = AppUser.firebase(uid: u.uid, email: u.email, phone: u.phoneNumber);
            return;
          }
          _currentUser.value = AppUser.fromFirestore(snap);
        },
        onError: (e) {
          debugPrint('FirebaseAuthManager: profile stream error uid=${u.uid} err=$e');
          _currentUser.value = AppUser.firebase(uid: u.uid, email: u.email, phone: u.phoneNumber);
        },
      );
    });
  }

  @override
  Future<AppUser> signInWithEmailOrThixId({required String identifier, required String password, required bool rememberMe}) async {
    final id = identifier.trim();
    if (id.isEmpty) throw AuthException('Identifiant requis.');
    if (password.isEmpty) throw AuthException('Mot de passe requis.');

    try {
      final email = id.contains('@') ? id : await _emailForThixId(id);
      if (email == null) throw AuthException('Identifiant introuvable.');
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final u = _auth.currentUser;
      if (u == null) throw AuthException('Connexion échouée.');

      final snap = await _db.collection('users').doc(u.uid).get();
      final appUser = snap.exists ? AppUser.fromFirestore(snap) : AppUser.firebase(uid: u.uid, email: u.email, phone: u.phoneNumber);
      _currentUser.value = appUser;
      unawaited(_logSecurityEvent(uid: u.uid, type: 'login', label: 'Connexion email/mot de passe'));
      return appUser;
    } on fb.FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthManager: signIn FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('FirebaseAuthManager: signIn failed. err=$e');
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
    if (!_isValidEmail(normalizedEmail) && !_looksLikePhone(normalizedEmail)) {
      throw AuthException('Email ou téléphone invalide.');
    }
    if (password.trim().length < 8) throw AuthException('Le mot de passe doit contenir au moins 8 caractères.');

    // If user typed a phone number into the "email" field we can't create phone+password
    // in Firebase Auth. We guide to phone flow handled in UI.
    if (_looksLikePhone(normalizedEmail)) {
      throw AuthException('Inscription par téléphone: utilisez la vérification SMS.');
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: normalizedEmail, password: password);
      final uid = cred.user?.uid;
      if (uid == null) throw AuthException('Création du compte échouée.');

      // THIX UID is assigned only after payment activation.
      final thixId = 'THIX-PENDING';
      final now = DateTime.now();
      final userDoc = AppUser(
        id: uid,
        thixId: thixId,
        thixChat: '',
        thixScore: null,
        email: normalizedEmail,
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
      );

      await _db.collection('users').doc(uid).set(userDoc.toFirestore());
      _currentUser.value = userDoc;
      unawaited(_logSecurityEvent(uid: uid, type: 'register', label: 'Création compte email'));
      return userDoc;
    } on fb.FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthManager: register FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('FirebaseAuthManager: register failed. err=$e');
      debugPrint('$st');
      throw AuthException('Inscription impossible.');
    }
  }

  @override
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber}) async {
    final phone = phoneNumber.trim();
    if (phone.isEmpty) throw AuthException('Téléphone requis.');
    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPhoneNumber(phone);
        return PhoneAuthSession(phoneNumber: phone, verificationId: null, forceResendingToken: null, webConfirmationResult: result);
      }

      final completer = Completer<PhoneAuthSession>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          try {
            await _auth.signInWithCredential(cred);
          } catch (e) {
            debugPrint('FirebaseAuthManager: auto phone verification sign-in failed err=$e');
          }
        },
        verificationFailed: (e) {
          if (!completer.isCompleted) completer.completeError(AuthException('Vérification téléphone échouée.'));
        },
        codeSent: (verificationId, forceResendingToken) {
          if (!completer.isCompleted) {
            completer.complete(PhoneAuthSession(phoneNumber: phone, verificationId: verificationId, forceResendingToken: forceResendingToken, webConfirmationResult: null));
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!completer.isCompleted) {
            completer.complete(PhoneAuthSession(phoneNumber: phone, verificationId: verificationId, forceResendingToken: null, webConfirmationResult: null));
          }
        },
      );
      return await completer.future;
    } on fb.FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthManager: startPhoneAuth FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('FirebaseAuthManager: startPhoneAuth failed err=$e');
      debugPrint('$st');
      throw AuthException('Impossible d’envoyer le SMS.');
    }
  }

  @override
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  }) async {
    final code = smsCode.trim();
    if (code.isEmpty) throw AuthException('Code SMS requis.');
    try {
      fb.UserCredential cred;
      if (kIsWeb) {
        final result = session.webConfirmationResult;
        if (result is! fb.ConfirmationResult) throw AuthException('Session SMS invalide.');
        cred = await result.confirm(code);
      } else {
        final vid = session.verificationId;
        if (vid == null || vid.isEmpty) throw AuthException('Session SMS invalide.');
        final phoneCred = fb.PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
        cred = await _auth.signInWithCredential(phoneCred);
      }

      final uid = cred.user?.uid;
      final phone = cred.user?.phoneNumber;
      if (uid == null) throw AuthException('Connexion échouée.');

      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) {
        final thixId = await _generateUniqueThixId(uid: uid);
        final now = DateTime.now();
        final u = AppUser(
          id: uid,
          thixId: thixId,
          thixChat: '',
          thixScore: null,
          email: '',
          phone: phone,
          displayName: (displayName ?? '').trim().isEmpty ? 'Utilisateur THIX' : displayName!.trim(),
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
        );
        await ref.set(u.toFirestore());
        _currentUser.value = u;
        unawaited(_logSecurityEvent(uid: uid, type: 'register', label: 'Création compte téléphone'));
        return u;
      }

      final u = AppUser.fromFirestore(snap);
      if ((phone ?? '').isNotEmpty && u.phone != phone) {
        await ref.set({'phone': phone, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
      _currentUser.value = u;
      unawaited(_logSecurityEvent(uid: uid, type: 'login', label: 'Connexion téléphone'));
      return u;
    } on fb.FirebaseAuthException catch (e, st) {
      debugPrint('FirebaseAuthManager: confirmPhoneCode FirebaseAuthException code=${e.code} message=${e.message}');
      debugPrint('$st');
      throw AuthException(_mapAuthError(e));
    } catch (e, st) {
      debugPrint('FirebaseAuthManager: confirmPhoneCode failed err=$e');
      debugPrint('$st');
      throw AuthException('Code SMS invalide.');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser.value = null;
  }

  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await _db.collection('users').doc(u.uid).delete();
    } catch (e) {
      debugPrint('FirebaseAuthManager: failed to delete profile doc. uid=${u.uid} err=$e');
    }
    await u.delete();
    _currentUser.value = null;
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException('Session expirée.');
    final normalized = newEmail.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await u.verifyBeforeUpdateEmail(normalized);
      await _db.collection('users').doc(u.uid).update({'email': normalized, 'updatedAt': FieldValue.serverTimestamp()});
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) throw AuthException('Email invalide.');
    try {
      await _auth.sendPasswordResetEmail(email: normalized);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  Future<String?> _emailForThixId(String thixId) async {
    final normalized = thixId.trim().toUpperCase();
    final q = await _db.collection('users').where('thixId', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) return null;
    final data = q.docs.first.data();
    final email = data['email'];
    return email is String ? email : null;
  }

  bool _looksLikePhone(String s) => RegExp(r'^\+?[0-9][0-9\s\-]{7,}$').hasMatch(s.trim());

  bool _isValidEmail(String email) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  String _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'channel-error':
        return 'Erreur d’authentification (channel-error). Vérifiez que Firebase Auth est activé (Email/Mot de passe) dans votre projet Firebase, puis réessayez. Si vous testez dans la Preview web, privilégiez l’inscription par email (le SMS peut nécessiter une configuration reCAPTCHA sur le Web).';
      case 'invalid-email':
        return 'Email invalide.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Identifiant ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'weak-password':
        return 'Mot de passe trop faible.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      case 'operation-not-allowed':
        return 'Méthode de connexion non activée. Activez Email/Mot de passe (ou Téléphone) dans Firebase Auth.';
      default:
        // Preserve any server-provided details when available.
        final msg = (e.message ?? '').trim();
        if (msg.isNotEmpty) return 'Erreur d’authentification (${e.code}): $msg';
        return 'Erreur d’authentification (${e.code}).';
    }
  }

  Future<String> _generateUniqueThixId({required String uid}) async {
    final cc = ThixIdService.inferCountryCode();
    for (var i = 0; i < 24; i++) {
      final candidate = ThixIdService.generate(countryCode: cc);
      final index = _db.collection('thix_ids').doc(candidate);
      try {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(index);
          if (snap.exists) throw Exception('duplicate');
          tx.set(
            index,
            {
              'uid': uid,
              'thixId': candidate,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        });
        return candidate;
      } catch (_) {
        continue;
      }
    }
    return ThixIdService.generate(countryCode: cc);
  }

  @override
  Future<void> updateCurrentUser(AppUser user) async {
    final current = currentUser;
    if (current == null) throw AuthException('Session expirée.');
    if (current.id != user.id) throw AuthException('Utilisateur courant différent.');

    try {
      await _db.collection('users').doc(user.id).set(user.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseAuthManager: updateCurrentUser failed uid=${user.id} err=$e');
    }
    _currentUser.value = user;
  }
}
