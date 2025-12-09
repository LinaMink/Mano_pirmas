import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rate Limiter
/// Riboja vartotojo veiksmus tam tikru laiko periodu
/// Apsaugo nuo spam ir DOS atakų
class RateLimiter {
  // Saugoti paskutinius veiksmus
  static final Map<String, List<DateTime>> _actionHistory = {};

  // Saugoti paskutinį veiksmo laiką (paprastam rate limiting)
  static final Map<String, DateTime> _lastActions = {};

  /// Patikrinti ar galima atlikti veiksmą (paprastas - cooldown based)
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
  static bool canPerformActionAdvanced(
    String actionKey, {
    int maxAttempts = 5,
    int windowSeconds = 60,
  }) {
    final now = DateTime.now();
    final history = _actionHistory[actionKey] ?? [];

    final cutoffTime = now.subtract(Duration(seconds: windowSeconds));
    history.removeWhere((time) => time.isBefore(cutoffTime));

    if (history.length >= maxAttempts) {
      if (kDebugMode) {
        debugPrint(
          '❌ Rate limit BLOCKED: $actionKey (${history.length}/$maxAttempts in ${windowSeconds}s)',
        );
      }
      return false;
    }

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

    final cutoffTime = now.subtract(Duration(seconds: windowSeconds));
    final recentHistory = history
        .where((time) => time.isAfter(cutoffTime))
        .toList();

    return maxAttempts - recentHistory.length;
  }

  /// Atstatyti rate limit tam tikram veiksmui
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
      windowSeconds: 300,
    ),
  };

  /// Helper metodas su predefined config
  static bool checkWithConfig(String actionKey) {
    final config = configs[actionKey];
    if (config == null) {
      return canPerformAction(actionKey, cooldownSeconds: 5);
    }

    return canPerformActionAdvanced(
      actionKey,
      maxAttempts: config.maxAttempts,
      windowSeconds: config.windowSeconds,
    );
  }

  // ==================== DIENOS LIMITAS (PERSISTENT) ====================

  static const String _dailyEditCountKey = 'daily_edit_count';
  static const String _dailyEditDateKey = 'daily_edit_date';
  static const int maxDailyEdits = 3;

  /// Patikrinti ar galima redaguoti šiandien
  static Future<bool> canEditToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_dailyEditDateKey);

    if (savedDate != today) {
      return true;
    }

    final editsCount = prefs.getInt(_dailyEditCountKey) ?? 0;
    return editsCount < maxDailyEdits;
  }

  /// Gauti likusį redagavimų skaičių
  static Future<int> getRemainingDailyEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_dailyEditDateKey);

    if (savedDate != today) {
      return maxDailyEdits;
    }

    final editsCount = prefs.getInt(_dailyEditCountKey) ?? 0;
    return maxDailyEdits - editsCount;
  }

  /// Registruoti redagavimą
  static Future<bool> recordDailyEdit() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    final savedDate = prefs.getString(_dailyEditDateKey);

    int editsCount;

    if (savedDate != today) {
      editsCount = 0;
      await prefs.setString(_dailyEditDateKey, today);
    } else {
      editsCount = prefs.getInt(_dailyEditCountKey) ?? 0;
    }

    if (editsCount >= maxDailyEdits) {
      return false;
    }

    await prefs.setInt(_dailyEditCountKey, editsCount + 1);
    debugPrint('📝 Daily edit recorded: ${editsCount + 1}/$maxDailyEdits');
    return true;
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
