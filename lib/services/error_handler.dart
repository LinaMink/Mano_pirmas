import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'analytics_service.dart';

/// Centralizuotas Error Handler
/// Konvertuoja technines klaidas į user-friendly pranešimus
/// Logina klaidas į Crashlytics ir Analytics
class ErrorHandler {
  /// Konvertuoti klaidą į vartotojui suprantamą pranešimą
  /// NIEKADA nerodyti tikrųjų error details vartotojui!
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return 'Nežinoma klaida';

    final errorString = error.toString().toLowerCase();

    // Firebase klaidos
    if (errorString.contains('permission') ||
        errorString.contains('denied') ||
        errorString.contains('unauthorized')) {
      return 'Prieigos klaida. Patikrinkite interneto ryšį.';
    }

    if (errorString.contains('unauthenticated')) {
      return 'Autentifikacijos klaida. Bandykite prisijungti iš naujo.';
    }

    // Network klaidos
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return 'Nėra interneto ryšio. Patikrinkite savo ryšį.';
    }

    if (errorString.contains('timeout')) {
      return 'Užklausa užtruko per ilgai. Bandykite dar kartą.';
    }

    // Firestore klaidos
    if (errorString.contains('not-found') || errorString.contains('notfound')) {
      return 'Duomenys nerasti.';
    }

    if (errorString.contains('already-exists') ||
        errorString.contains('alreadyexists')) {
      return 'Duomenys jau egzistuoja.';
    }

    if (errorString.contains('quota-exceeded') ||
        errorString.contains('resource-exhausted')) {
      return 'Pasiektas limitas. Bandykite vėliau.';
    }

    // Validation klaidos
    if (errorString.contains('invalid') || errorString.contains('validation')) {
      return 'Neteisingi duomenys. Patikrinkite ir bandykite dar kartą.';
    }

    // Auth klaidos
    if (errorString.contains('user-not-found')) {
      return 'Vartotojas nerastas.';
    }

    if (errorString.contains('wrong-password')) {
      return 'Neteisingas slaptažodis.';
    }

    if (errorString.contains('email-already-in-use')) {
      return 'Šis el. paštas jau naudojamas.';
    }

    if (errorString.contains('weak-password')) {
      return 'Slaptažodis per silpnas.';
    }

    // Generic klaida - NIEKADA nerodyti tikros error žinutės
    return 'Įvyko klaida. Bandykite dar kartą.';
  }

  /// Logginti klaidą į Crashlytics ir Analytics
  static Future<void> logError(
    dynamic error,
    StackTrace? stack, {
    required String context,
    Map<String, dynamic>? additionalData,
    bool fatal = false,
  }) async {
    try {
      // 1. Debug console (tik development)
      if (kDebugMode) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('❌ ERROR in $context');
        debugPrint('Error: $error');
        if (stack != null) {
          debugPrint(
            'Stack: ${stack.toString().split('\n').take(5).join('\n')}',
          );
        }
        if (additionalData != null) {
          debugPrint('Additional: $additionalData');
        }
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // 2. Firebase Crashlytics
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
        fatal: fatal,
        information:
            additionalData?.entries
                .map((e) => '${e.key}: ${e.value}')
                .toList() ??
            [],
      );

      // 3. Firebase Analytics
      await AnalyticsService.logError(
        errorType: error.runtimeType.toString(),
        screen: context,
        errorMessage: _truncateErrorMessage(error.toString()),
      );
    } catch (loggingError) {
      // Jei nepavyksta logginti - bent debugPrint
      debugPrint('❌ Failed to log error: $loggingError');
    }
  }

  /// Trumpinti error message (max 100 simbolių Analytics)
  static String _truncateErrorMessage(String message) {
    if (message.length <= 100) return message;
    return '${message.substring(0, 97)}...';
  }

  /// Custom Exception klasė su user-friendly message
  static Exception createException(String message, {String? technicalDetails}) {
    if (kDebugMode && technicalDetails != null) {
      debugPrint('Exception details: $technicalDetails');
    }
    return Exception(message);
  }
}

/// Custom Exception klasės
class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Nėra interneto ryšio']);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Autentifikacijos klaida']);

  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException([this.message = 'Neteisingi duomenys']);

  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'Duomenys nerasti']);

  @override
  String toString() => message;
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException([this.message = 'Per daug bandymų. Palaukite.']);

  @override
  String toString() => message;
}
