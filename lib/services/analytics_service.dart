import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // 1. POROS SUKŪRIMAS
  static Future<void> logCoupleCreated() async {
    await _analytics.logEvent(
      name: 'couple_created',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // 2. ŽINUTĖS REDAGAVIMAS
  static Future<void> logMessageEdited({
    required int dayNumber,
    required bool isCustom,
    required int messageLength,
  }) async {
    await _analytics.logEvent(
      name: 'message_edited',
      parameters: {
        'day_number': dayNumber,
        'is_custom': isCustom,
        'message_length': messageLength,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // 3. KALENDORIAUS ATIDARYMAS
  static Future<void> logCalendarOpened() async {
    await _analytics.logEvent(
      name: 'calendar_opened',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // 4. KLAIDOS ĮVYKIS
  static Future<void> logError({
    required String errorType,
    required String screen,
    String? errorMessage,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_type': errorType,
        'screen': screen,
        'error_message': errorMessage ?? 'N/A',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // 5. OFFLINE ĮVYKIS
  static Future<void> logOfflineAction({
    required String action,
    required bool success,
  }) async {
    await _analytics.logEvent(
      name: 'offline_action',
      parameters: {
        'action': action,
        'success': success,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // 6. SKAITYTOJO PRISIJUNGIMAS (TRŪKSTA - PRIDĖTI!)
  static Future<void> logReaderJoined() async {
    await _analytics.logEvent(
      name: 'reader_joined',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // 7. RAŠYTOJO PRISIJUNGIMAS (TRŪKSTA - PRIDĖTI!)
  static Future<void> logWriterLoggedIn() async {
    await _analytics.logEvent(
      name: 'writer_logged_in',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  // 8. GENERIC EVENT LOGGING (TRŪKSTA - PRIDĖTI!)
  static Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    final params = parameters ?? {};
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch;

    await _analytics.logEvent(name: eventName, parameters: params);
  }
}
