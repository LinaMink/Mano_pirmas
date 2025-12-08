import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Authentication Service
/// Valdo Firebase Authentication (Anonymous + būsimas Google Sign-In)
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream vartotojo būsenai sekti
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Dabartinis vartotojas
  User? get currentUser => _auth.currentUser;

  // Dabartinis user ID (null jei neprisijungęs)
  String? get currentUserId => _auth.currentUser?.uid;

  // Ar vartotojas prisijungęs
  bool get isAuthenticated => _auth.currentUser != null;

  /// Prisijungti anonymiškai (default metodas)
  /// Grąžina User jei sėkminga, null jei klaida
  Future<User?> signInAnonymously() async {
    try {
      debugPrint('🔐 Bandoma prisijungti anonymously...');

      final UserCredential result = await _auth.signInAnonymously();
      final User? user = result.user;

      if (user != null) {
        debugPrint('✅ Anonymous auth sėkminga: ${user.uid}');

        // Log į Crashlytics
        await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      }

      return user;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('❌ Auth klaida: ${e.code} - ${e.message}');
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'signInAnonymously failed',
      );
      return null;
    } catch (e, stack) {
      debugPrint('❌ Nežinoma auth klaida: $e');
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'signInAnonymously unknown error',
      );
      return null;
    }
  }

  /// Prisijungti su Google (būsimas funkcionalumas)

  Future<User?> signInWithGoogle() async {
    // Reikės įdiegti google_sign_in package integration
    throw UnimplementedError('Google Sign-In dar neįdiegtas');
  }

  /// Atsijungti
  Future<void> signOut() async {
    try {
      debugPrint('🔓 Atsijungiama...');
      await _auth.signOut();
      debugPrint('✅ Atsijungta sėkmingai');
    } catch (e, stack) {
      debugPrint('❌ SignOut klaida: $e');
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'signOut failed',
      );
    }
  }

  /// Ištrinti vartotojo account (jei reikia)
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.delete();
      debugPrint('✅ Account ištrintas');
      return true;
    } catch (e, stack) {
      debugPrint('❌ Delete account klaida: $e');
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'deleteAccount failed',
      );
      return false;
    }
  }

  /// Užtikrinti kad user prisijungęs
  /// Jei ne - automatiškai prisijungia anonymously
  Future<User?> ensureAuthenticated() async {
    if (isAuthenticated) {
      return currentUser;
    }

    return await signInAnonymously();
  }

  /// Get User Token (naudoti API requests jei reikia)
  Future<String?> getUserToken() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      return await user.getIdToken();
    } catch (e) {
      debugPrint('❌ Get token klaida: $e');
      return null;
    }
  }
}
