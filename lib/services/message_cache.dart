// lib/services/message_cache.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class MessageCache {
  static const String _cacheKey = 'message_cache';
  static const String _lastShownDateKey = 'last_shown_date';
  static const String _dailyMessageKey = 'daily_message_cache';
  static const String _dailyWriteCountKey = 'daily_write_count';
  static const Duration _cacheDuration = Duration(days: 7);

  // 🆕 Maksimalus žinučių kiekis per dieną
  static const int maxWritesPerDay = 3;

  // ==================== DIENOS ŽINUTĖS LOGIKA ====================

  /// Patikrinti ar reikia atnaujinti dienos žinutę (ar pasikeitė diena)
  static Future<bool> shouldRefreshDailyMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShownDateStr = prefs.getString(_lastShownDateKey);

      if (lastShownDateStr == null) {
        // Pirmas kartas - reikia atnaujinti
        return true;
      }

      final lastShownDate = DateTime.parse(lastShownDateStr);
      final today = DateTime.now();

      // Patikrinti ar pasikeitė kalendorinė diena
      final isDifferentDay =
          lastShownDate.year != today.year ||
          lastShownDate.month != today.month ||
          lastShownDate.day != today.day;

      if (kDebugMode) {
        debugPrint(
          '📅 Last shown: ${lastShownDate.toString().substring(0, 10)}',
        );
        debugPrint('📅 Today: ${today.toString().substring(0, 10)}');
        debugPrint('📅 Should refresh: $isDifferentDay');
      }

      return isDifferentDay;
    } catch (e) {
      debugPrint('❌ Error checking daily refresh: $e');
      return true; // Jei klaida - atnaujinti
    }
  }

  /// Pažymėti, kad dienos žinutė buvo parodyta
  static Future<void> markDailyMessageShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String();
      await prefs.setString(_lastShownDateKey, today);

      if (kDebugMode) {
        debugPrint('✅ Marked daily message shown: $today');
      }
    } catch (e) {
      debugPrint('❌ Error marking daily message: $e');
    }
  }

  /// Gauti cached dienos žinutę (jei ta pati diena)
  static Future<String?> getCachedDailyMessage(
    int dayNumber,
    String writerCode,
  ) async {
    try {
      final shouldRefresh = await shouldRefreshDailyMessage();

      if (shouldRefresh) {
        // Nauja diena - grąžiname null, kad užkrautų iš naujo
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString(_dailyMessageKey);

      if (cacheStr == null) return null;

      final cache = json.decode(cacheStr) as Map<String, dynamic>;

      // Patikrinti ar tas pats dayNumber ir writerCode
      if (cache['dayNumber'] == dayNumber &&
          cache['writerCode'] == writerCode) {
        if (kDebugMode) {
          debugPrint('✅ Using cached daily message');
        }
        return cache['message'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached daily message: $e');
      return null;
    }
  }

  /// Išsaugoti dienos žinutę į cache
  static Future<void> cacheDailyMessage(
    int dayNumber,
    String message,
    String writerCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = {
        'dayNumber': dayNumber,
        'message': message,
        'writerCode': writerCode,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_dailyMessageKey, json.encode(cache));
      await markDailyMessageShown();

      if (kDebugMode) {
        debugPrint('✅ Cached daily message for day $dayNumber');
      }
    } catch (e) {
      debugPrint('❌ Error caching daily message: $e');
    }
  }

  /// Priverstinai atnaujinti dienos žinutę (kai rašytojas parašo naują)
  static Future<void> forceDailyMessageRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyMessageKey);

      if (kDebugMode) {
        debugPrint('🔄 Forced daily message refresh');
      }
    } catch (e) {
      debugPrint('❌ Error forcing refresh: $e');
    }
  }

  // ==================== RAŠYTOJO LIMITAS (3 PER DIENĄ) ====================

  /// Patikrinti ar rašytojas gali rašyti žinutę (max 3 per dieną)
  static Future<bool> canWriteMessage(String writerCode) async {
    try {
      final writeCount = await _getDailyWriteCount(writerCode);
      final canWrite = writeCount < maxWritesPerDay;

      if (kDebugMode) {
        debugPrint('📝 Daily writes: $writeCount/$maxWritesPerDay');
        debugPrint('📝 Can write: $canWrite');
      }

      return canWrite;
    } catch (e) {
      debugPrint('❌ Error checking write limit: $e');
      return true; // Jei klaida - leidžiam rašyti
    }
  }

  /// Gauti kiek liko žinučių šiandien
  static Future<int> getRemainingWrites(String writerCode) async {
    try {
      final writeCount = await _getDailyWriteCount(writerCode);
      return maxWritesPerDay - writeCount;
    } catch (e) {
      return maxWritesPerDay;
    }
  }

  /// Padidinti dienos rašymo skaitliuką
  static Future<void> incrementWriteCount(String writerCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final key = '${_dailyWriteCountKey}_$writerCode';

      final dataStr = prefs.getString(key);
      Map<String, dynamic> data = {};

      if (dataStr != null) {
        data = json.decode(dataStr) as Map<String, dynamic>;
      }

      // Jei kita diena - reset'inam skaitliuką
      if (data['date'] != today) {
        data = {'date': today, 'count': 0};
      }

      data['count'] = (data['count'] as int? ?? 0) + 1;

      await prefs.setString(key, json.encode(data));

      if (kDebugMode) {
        debugPrint(
          '📝 Write count incremented: ${data['count']}/$maxWritesPerDay',
        );
      }
    } catch (e) {
      debugPrint('❌ Error incrementing write count: $e');
    }
  }

  /// Gauti dienos rašymo skaitliuką (private)
  static Future<int> _getDailyWriteCount(String writerCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayString();
      final key = '${_dailyWriteCountKey}_$writerCode';

      final dataStr = prefs.getString(key);

      if (dataStr == null) return 0;

      final data = json.decode(dataStr) as Map<String, dynamic>;

      // Jei kita diena - skaitliukas yra 0
      if (data['date'] != today) {
        return 0;
      }

      return data['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Gauti šiandienos datą kaip string (yyyy-MM-dd)
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ==================== BENDRA CACHE LOGIKA ====================

  /// Išsaugoti žinutes į cache
  static Future<void> saveMessages(
    Map<int, String> messages,
    String writerCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'writerCode': writerCode,
        'messages': messages,
      };

      await prefs.setString(_cacheKey, json.encode(cacheData));
    } catch (e) {
      debugPrint('Klaida išsaugant cache: $e');
    }
  }

  /// Gauti žinutes iš cache
  static Future<Map<int, String>?> getMessages(String writerCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_cacheKey);

      if (cachedString == null || cachedString.isEmpty) return null;

      final cacheData = json.decode(cachedString) as Map<String, dynamic>;

      // Tikrinti ar cache dar galioja ir ar teisingas writerCode
      final timestamp = cacheData['timestamp'] as int?;
      final cachedWriterCode = cacheData['writerCode'] as String?;
      final cachedMessages = cacheData['messages'] as Map<String, dynamic>?;

      // 🛡️ PAPILDOMA VALIDACIJA
      if (timestamp == null ||
          cachedWriterCode == null ||
          cachedMessages == null) {
        await clearCache(); // Išvalyti sugadintą cache
        return null;
      }

      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );

      if (cacheAge > _cacheDuration) return null;
      if (cachedWriterCode != writerCode) return null;

      // Konvertuoti į Map<int, String> su validacija
      final messages = <int, String>{};

      for (final entry in cachedMessages.entries) {
        try {
          final key = int.parse(entry.key);
          final value = entry.value.toString();

          // Validuoti dienos numerį (1-365) ir žinutės ilgį (1-500)
          if (key >= 1 &&
              key <= 365 &&
              value.isNotEmpty &&
              value.length <= 500) {
            messages[key] = value;
          }
        } catch (e) {
          // Ignoruoti neteisingus įrašus
          debugPrint('Invalid cache entry: ${entry.key} = ${entry.value}');
        }
      }

      return messages;
    } catch (e) {
      debugPrint('Klaida gaunant cache: $e');
      return null;
    }
  }

  /// Išvalyti cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_dailyMessageKey);
    // Nereset'inam write count - tai svarbus limitas
  }

  /// Išvalyti visą cache (įskaitant write count) - tik logout metu
  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_dailyMessageKey);
    await prefs.remove(_lastShownDateKey);
    // Write count keys išvalomi atskirai pagal writerCode

    if (kDebugMode) {
      debugPrint('🗑️ All cache cleared');
    }
  }

  /// Išsaugoti vieną žinutę
  static Future<void> saveSingleMessage(
    int dayNumber,
    String message,
    String writerCode,
  ) async {
    try {
      final existingMessages = await getMessages(writerCode) ?? {};
      existingMessages[dayNumber] = message;
      await saveMessages(existingMessages, writerCode);

      // 🆕 Jei tai šiandienos žinutė - atnaujinti ir dienos cache
      final today = DateTime.now();
      final todayDayNumber =
          today.difference(DateTime(today.year, 1, 1)).inDays + 1;

      if (dayNumber == todayDayNumber) {
        await cacheDailyMessage(dayNumber, message, writerCode);
      }

      debugPrint('✅ Išsaugota į cache: day$dayNumber = $message');
    } catch (e) {
      debugPrint('❌ Klaida išsaugant į cache: $e');
    }
  }

  /// Ištrinti žinutę iš cache
  static Future<void> deleteMessage(int dayNumber, String writerCode) async {
    try {
      final existingMessages = await getMessages(writerCode);
      if (existingMessages != null) {
        existingMessages.remove(dayNumber);
        await saveMessages(existingMessages, writerCode);
      }

      // 🆕 Jei tai šiandienos žinutė - išvalyti dienos cache
      final today = DateTime.now();
      final todayDayNumber =
          today.difference(DateTime(today.year, 1, 1)).inDays + 1;

      if (dayNumber == todayDayNumber) {
        await forceDailyMessageRefresh();
      }
    } catch (e) {
      debugPrint('Klaida trinant žinutę iš cache: $e');
    }
  }
}
