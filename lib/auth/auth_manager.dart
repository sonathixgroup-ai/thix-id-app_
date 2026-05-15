import 'package:flutter/foundation.dart';
import 'package:thix_id/models/app_user.dart';

/// AuthManager defines the contract for authentication implementations.
///
/// In this project we provide a local-first implementation (no backend).
/// Later you can swap this for Firebase/Supabase while keeping the same API.
abstract class AuthManager {
  ValueListenable<AppUser?> get currentUserListenable;

  AppUser? get currentUser;

  Future<void> init();

  Future<AppUser> signInWithEmailOrThixId({
    required String identifier,
    required String password,
    required bool rememberMe,
  });

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required AccountType accountType,
    required bool rememberMe,
    /// Optional additional profile fields to persist during sign-up.
    ///
    /// For Supabase, these values are stored in Auth `user_metadata` when email
    /// confirmation is enabled (session can be null). They will then be copied
    /// into `public.profiles` at first authenticated login.
    Map<String, dynamic>? profileDraft,
  });

  /// Starts a phone sign-in / registration flow.
  ///
  /// UI should call this first to send SMS, then call [confirmPhoneCode].
  Future<PhoneAuthSession> startPhoneAuth({required String phoneNumber});

  /// Confirms SMS code and returns the authenticated user.
  ///
  /// If the user profile doc doesn't exist yet, it will be created with
  /// the provided [displayName] and [accountType].
  Future<AppUser> confirmPhoneCode({
    required PhoneAuthSession session,
    required String smsCode,
    String? displayName,
    AccountType accountType = AccountType.personal,
  });

  Future<void> signOut();

  Future<void> deleteAccount();

  Future<void> updateEmail(String newEmail);

  Future<void> requestPasswordReset(String email);

  /// Updates the current user locally (and remotely when applicable).
  ///
  /// Used when backend activation assigns a new THIX UID, photo, etc.
  Future<void> updateCurrentUser(AppUser user);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class PhoneAuthSession {
  final String phoneNumber;
  final String? verificationId;
  final int? forceResendingToken;
  final Object? webConfirmationResult;

  const PhoneAuthSession({
    required this.phoneNumber,
    required this.verificationId,
    required this.forceResendingToken,
    required this.webConfirmationResult,
  });
}
