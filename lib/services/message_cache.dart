// lib/services/message_cache.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class MessageCache {
  static const String _cacheKey = 'message_cache';
  static const Duration _cacheDuration = Duration(days: 7);

  // Išsaugoti žinutes į cache
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

  // Gauti žinutes iš cache
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

  // Išvalyti cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  // Išsaugoti vieną žinutę
  static Future<void> saveSingleMessage(
    int dayNumber,
    String message,
    String writerCode,
  ) async {
    try {
      final existingMessages = await getMessages(writerCode) ?? {};
      existingMessages[dayNumber] = message;
      await saveMessages(existingMessages, writerCode);
      debugPrint('✅ Išsaugota į cache: day$dayNumber = $message');
    } catch (e) {
      debugPrint('❌ Klaida išsaugant į cache: $e');
    }
  }

  // Ištrinti žinutę iš cache
  static Future<void> deleteMessage(int dayNumber, String writerCode) async {
    try {
      final existingMessages = await getMessages(writerCode);
      if (existingMessages != null) {
        existingMessages.remove(dayNumber);
        await saveMessages(existingMessages, writerCode);
      }
    } catch (e) {
      debugPrint('Klaida trinant žinutę iš cache: $e');
    }
  }
}
