import 'package:flutter/foundation.dart';

/// Rate Limiter
/// Riboja vartotojo veiksmus tam tikru laiko periodu
/// Apsaugo nuo spam ir DOS atakų
class RateLimiter {
  // Saugoti paskutinius veiksmus
  static final Map<String, List<DateTime>> _actionHistory = {};

  // Saugoti paskutinį veiksmo laiką (paprastam rate limiting)
  static final Map<String, DateTime> _lastActions = {};

  /// Patikrinti ar galima atlikti veiksmą (paprastas - cooldown based)
  ///
  /// [actionKey] - unikalus veiksmo identifikatorius (pvz. 'create_couple', 'save_message')
  /// [cooldownSeconds] - kiek sekundžių reikia palaukti tarp veiksmų
  ///
  /// Returns: true jei galima, false jei per anksti
  static bool canPerformAction(String actionKey, {int cooldownSeconds = 5}) {
    final now = DateTime.now();
    final lastAction = _lastActions[actionKey];

    if (lastAction == null) {
      _lastActions[actionKey] = now;
      if (kDebugMode) {
        debugPrint('✅ Rate limit OK: $actionKey (first time)');
      }
      return true;
    }

    final timeSince = now.difference(lastAction);
    if (timeSince.inSeconds >= cooldownSeconds) {
      _lastActions[actionKey] = now;
      if (kDebugMode) {
        debugPrint(
          '✅ Rate limit OK: $actionKey (${timeSince.inSeconds}s passed)',
        );
      }
      return true;
    }

    final remainingSeconds = cooldownSeconds - timeSince.inSeconds;
    if (kDebugMode) {
      debugPrint(
        '❌ Rate limit BLOCKED: $actionKey (wait ${remainingSeconds}s)',
      );
    }
    return false;
  }

  /// Patikrinti ar galima atlikti veiksmą (advanced - sliding window)
  ///
  /// [actionKey] - unikalus veiksmo identifikatorius
  /// [maxAttempts] - maksimalus bandymų skaičius
  /// [windowSeconds] - laiko langas sekundėmis
  ///
  /// Example: canPerformActionAdvanced('login', maxAttempts: 5, windowSeconds: 60)
  ///   = max 5 bandymai per 60 sekundžių
  static bool canPerformActionAdvanced(
    String actionKey, {
    int maxAttempts = 5,
    int windowSeconds = 60,
  }) {
    final now = DateTime.now();
    final history = _actionHistory[actionKey] ?? [];

    // Išvalyti senus įrašus už lango
    final cutoffTime = now.subtract(Duration(seconds: windowSeconds));
    history.removeWhere((time) => time.isBefore(cutoffTime));

    // Patikrinti ar viršytas limitas
    if (history.length >= maxAttempts) {
      if (kDebugMode) {
        debugPrint(
          '❌ Rate limit BLOCKED: $actionKey (${history.length}/$maxAttempts in ${windowSeconds}s)',
        );
      }
      return false;
    }

    // Pridėti dabartinį veiksmą
    history.add(now);
    _actionHistory[actionKey] = history;

    if (kDebugMode) {
      debugPrint(
        '✅ Rate limit OK: $actionKey (${history.length}/$maxAttempts in ${windowSeconds}s)',
      );
    }
    return true;
  }

  /// Gauti likusį cooldown laiką sekundėmis
  static int getRemainingCooldown(String actionKey, {int cooldownSeconds = 5}) {
    final lastAction = _lastActions[actionKey];
    if (lastAction == null) return 0;

    final timeSince = DateTime.now().difference(lastAction);
    final remaining = cooldownSeconds - timeSince.inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  /// Gauti likusių bandymų skaičių
  static int getRemainingAttempts(
    String actionKey, {
    int maxAttempts = 5,
    int windowSeconds = 60,
  }) {
    final now = DateTime.now();
    final history = _actionHistory[actionKey] ?? [];

    // Išvalyti senus įrašus
    final cutoffTime = now.subtract(Duration(seconds: windowSeconds));
    final recentHistory = history
        .where((time) => time.isAfter(cutoffTime))
        .toList();

    return maxAttempts - recentHistory.length;
  }

  /// Atstatyti rate limit tam tikram veiksmui (admin funkcija)
  static void resetAction(String actionKey) {
    _lastActions.remove(actionKey);
    _actionHistory.remove(actionKey);
    if (kDebugMode) {
      debugPrint('🔄 Rate limit reset: $actionKey');
    }
  }

  /// Išvalyti visus rate limits (logout)
  static void clearAll() {
    _lastActions.clear();
    _actionHistory.clear();
    if (kDebugMode) {
      debugPrint('🔄 All rate limits cleared');
    }
  }

  /// Predefined rate limit configs
  static const Map<String, RateLimitConfig> configs = {
    'create_couple': RateLimitConfig(
      cooldownSeconds: 10,
      maxAttempts: 3,
      windowSeconds: 60,
    ),
    'join_couple': RateLimitConfig(
      cooldownSeconds: 5,
      maxAttempts: 5,
      windowSeconds: 60,
    ),
    'save_message': RateLimitConfig(
      cooldownSeconds: 2,
      maxAttempts: 10,
      windowSeconds: 60,
    ),
    'login': RateLimitConfig(
      cooldownSeconds: 3,
      maxAttempts: 5,
      windowSeconds: 300, // 5 minutes
    ),
  };

  /// Helper metodas su predefined config
  static bool checkWithConfig(String actionKey) {
    final config = configs[actionKey];
    if (config == null) {
      // Default: 5 second cooldown
      return canPerformAction(actionKey, cooldownSeconds: 5);
    }

    // Naudoti advanced rate limiting su config
    return canPerformActionAdvanced(
      actionKey,
      maxAttempts: config.maxAttempts,
      windowSeconds: config.windowSeconds,
    );
  }
}

/// Rate Limit Configuration
class RateLimitConfig {
  final int cooldownSeconds;
  final int maxAttempts;
  final int windowSeconds;

  const RateLimitConfig({
    required this.cooldownSeconds,
    required this.maxAttempts,
    required this.windowSeconds,
  });
}

/// Rate Limit Exception
class RateLimitException implements Exception {
  final String message;
  final int remainingSeconds;

  RateLimitException(this.message, [this.remainingSeconds = 0]);

  @override
  String toString() => message;
}

/// Helper Extension
extension RateLimitedAction on Function {
  /// Wrapper funkcija su rate limiting
  Future<T> withRateLimit<T>(
    String actionKey, {
    int cooldownSeconds = 5,
  }) async {
    if (!RateLimiter.canPerformAction(
      actionKey,
      cooldownSeconds: cooldownSeconds,
    )) {
      final remaining = RateLimiter.getRemainingCooldown(
        actionKey,
        cooldownSeconds: cooldownSeconds,
      );
      throw RateLimitException(
        'Per daug bandymų. Palaukite $remaining sekundžių.',
        remaining,
      );
    }

    return await this() as T;
  }
}
