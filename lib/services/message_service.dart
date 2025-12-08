import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'message_cache.dart';
import '../data/default_messages.dart';
import 'input_validator.dart';
import 'error_handler.dart';
import 'rate_limiter.dart';
import 'analytics_service.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Gauti šiandienos dienos numerį (1-365)
  static int get todayDayNumber {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  // Gauti mėnesio pavadinimą
  static String getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Sausis';
      case 2:
        return 'Vasaris';
      case 3:
        return 'Kovas';
      case 4:
        return 'Balandis';
      case 5:
        return 'Gegužė';
      case 6:
        return 'Birželis';
      case 7:
        return 'Liepa';
      case 8:
        return 'Rugpjūtis';
      case 9:
        return 'Rugsėjis';
      case 10:
        return 'Spalis';
      case 11:
        return 'Lapkritis';
      case 12:
        return 'Gruodis';
      default:
        return '';
    }
  }

  // Gauti dienų skaičių mėnesyje
  static int getDaysInMonth(int year, int month) {
    if (month == 2) {
      return DateTime(year, 3, 0).day;
    } else if ([4, 6, 9, 11].contains(month)) {
      return 30;
    } else {
      return 31;
    }
  }

  // Gauti visus mėnesius
  static List<Month> getMonths() {
    final months = <Month>[];
    final year = DateTime.now().year;

    for (int month = 1; month <= 12; month++) {
      final monthName = getMonthName(month);
      final daysInMonth = getDaysInMonth(year, month);

      final days = <Day>[];
      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(year, month, day);
        final dayOfYear = date.difference(DateTime(year, 1, 1)).inDays + 1;

        days.add(Day(dayOfMonth: day, dayOfYear: dayOfYear, date: date));
      }

      months.add(Month(name: monthName, monthNumber: month, days: days));
    }

    return months;
  }

  // ✅ SUBCOLLECTION VERSION - Gauti žinutę
  // 🆕 Su dienos cache logika - žinutė atsinaujina tik vidurnaktį
  Future<String> getMessage(int dayNumber, String writerCode) async {
    if (kDebugMode) {
      debugPrint('🔍 Gaunama žinutė: day$dayNumber, writer: $writerCode');
    }

    try {
      // Validuoti inputs
      final dayValidation = InputValidator.validateDayNumber(dayNumber);
      if (!dayValidation.isValid) {
        if (kDebugMode) {
          debugPrint('❌ Invalid day number: ${dayValidation.message}');
        }
        return DefaultMessages.getMessage(1);
      }

      final codeValidation = InputValidator.validateWriterCode(writerCode);
      if (!codeValidation.isValid) {
        if (kDebugMode) {
          debugPrint('❌ Invalid writer code: ${codeValidation.message}');
        }
        return DefaultMessages.getMessage(dayNumber);
      }

      // 🆕 1. Patikrinti ar tai šiandienos žinutė ir ar jau buvo rodyta
      final isToday = dayNumber == todayDayNumber;

      if (isToday) {
        // Patikrinti dienos cache
        final cachedDailyMessage = await MessageCache.getCachedDailyMessage(
          dayNumber,
          writerCode,
        );

        if (cachedDailyMessage != null) {
          if (kDebugMode) {
            debugPrint('✅ Naudojama cached dienos žinutė (ta pati diena)');
          }
          return cachedDailyMessage;
        }
      }

      // 2. Tikrinti bendrą cache
      final cachedMessages = await MessageCache.getMessages(writerCode);
      if (kDebugMode) {
        debugPrint('📦 Cache dydis: ${cachedMessages?.length ?? 0}');
      }

      if (cachedMessages != null &&
          cachedMessages.isNotEmpty &&
          cachedMessages.containsKey(dayNumber)) {
        final message = cachedMessages[dayNumber]!;

        // 🆕 Jei šiandienos žinutė - išsaugoti į dienos cache
        if (isToday) {
          await MessageCache.cacheDailyMessage(dayNumber, message, writerCode);
        }

        if (kDebugMode) {
          debugPrint('✅ Rasta cache: $message');
        }
        return message;
      }

      // 3. ✅ SUBCOLLECTION: /couples/{writerCode}/messages/{dayNumber}
      if (kDebugMode) {
        debugPrint('☁️ Kreipiamasi į Firestore subcollection...');
      }

      final doc = await _firestore
          .collection('couples')
          .doc(writerCode)
          .collection('messages')
          .doc(dayNumber.toString())
          .get();

      if (doc.exists) {
        if (kDebugMode) {
          debugPrint('✅ Firestore dokumentas rastas');
        }
        final data = doc.data() as Map<String, dynamic>;
        final message = data['content'] as String?;

        if (message != null && message.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('🎯 Custom žinutė: $message');
          }

          // Išsaugoti į cache
          await MessageCache.saveSingleMessage(dayNumber, message, writerCode);

          // 🆕 Jei šiandienos žinutė - išsaugoti į dienos cache
          if (isToday) {
            await MessageCache.cacheDailyMessage(
              dayNumber,
              message,
              writerCode,
            );
          }

          return message;
        }
      } else {
        if (kDebugMode) {
          debugPrint('📝 Dokumentas nerastas - grąžinama default');
        }
      }

      // 4. Default žinutė
      final defaultMsg = DefaultMessages.getMessage(dayNumber);

      // 🆕 Jei šiandienos žinutė - išsaugoti default į dienos cache
      if (isToday) {
        await MessageCache.cacheDailyMessage(dayNumber, defaultMsg, writerCode);
      }

      if (kDebugMode) {
        debugPrint('⚡ Default: $defaultMsg');
      }
      return defaultMsg;
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'MessageService.getMessage',
        additionalData: {'dayNumber': dayNumber, 'writerCode': writerCode},
      );

      if (kDebugMode) {
        debugPrint('❌ Klaida: $e');
      }

      return DefaultMessages.getMessage(dayNumber);
    }
  }

  // 🔒 SECURITY: Validate message content
  Map<String, dynamic> validateMessage(String message) {
    if (message.trim().isEmpty) {
      return {
        'isValid': false,
        'reason': 'empty',
        'message': 'Žinutė negali būti tuščia',
      };
    }

    if (message.length > 500) {
      return {
        'isValid': false,
        'reason': 'too_long',
        'message': 'Žinutė negali būti ilgesnė nei 500 simbolių',
      };
    }

    final urlPatterns = [
      RegExp(r'https?:\/\/', caseSensitive: false),
      RegExp(r'www\.', caseSensitive: false),
      RegExp(r'\.com\b', caseSensitive: false),
      RegExp(r'\.lt\b', caseSensitive: false),
    ];

    for (final pattern in urlPatterns) {
      if (pattern.hasMatch(message)) {
        return {
          'isValid': false,
          'reason': 'url_detected',
          'message': 'Žinutė negali turėti nuorodų (URL)',
        };
      }
    }

    return {'isValid': true, 'reason': 'valid', 'message': 'Žinutė galioja'};
  }

  // ✅ SUBCOLLECTION VERSION - Išsaugoti žinutę
  // 🆕 Su 3 žinučių per dieną limitu
  Future<bool> saveCustomMessage({
    required String writerCode,
    required int dayNumber,
    required String message,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('💾 Saugoma žinutė: day$dayNumber, writer: $writerCode');
      }

      // 🆕 Patikrinti dienos limitą (max 3 žinutės per dieną)
      final canWrite = await MessageCache.canWriteMessage(writerCode);
      if (!canWrite) {
        final remaining = await MessageCache.getRemainingWrites(writerCode);
        if (kDebugMode) {
          debugPrint('❌ Daily write limit exceeded. Remaining: $remaining');
        }
        return false;
      }

      // Rate limiting (trumpalaikis)
      if (!RateLimiter.checkWithConfig('save_message')) {
        if (kDebugMode) debugPrint('❌ Rate limit exceeded');
        return false;
      }

      // Validuoti day number
      final dayValidation = InputValidator.validateDayNumber(dayNumber);
      if (!dayValidation.isValid) {
        if (kDebugMode) debugPrint('❌ Invalid day: ${dayValidation.message}');
        return false;
      }

      // Validuoti writer code
      final codeValidation = InputValidator.validateWriterCode(writerCode);
      if (!codeValidation.isValid) {
        if (kDebugMode) {
          debugPrint('❌ Invalid code: ${codeValidation.message}');
        }
        return false;
      }

      // Validuoti message
      final validation = validateMessage(message);
      if (!validation['isValid']) {
        if (kDebugMode) {
          debugPrint('❌ Invalid message: ${validation['reason']}');
        }
        return false;
      }

      // ✅ SUBCOLLECTION: Išsaugoti į /couples/{writerCode}/messages/{dayNumber}
      final messageData = {
        'dayNumber': dayNumber,
        'content': message,
        'writerCode': writerCode,
        'timestamp': FieldValue.serverTimestamp(),
        'isCustom': true,
      };

      await _firestore
          .collection('couples')
          .doc(writerCode)
          .collection('messages')
          .doc(dayNumber.toString())
          .set(messageData, SetOptions(merge: true));

      if (kDebugMode) {
        debugPrint('✅ Žinutė išsaugota Firestore');
      }

      // Išsaugoti į cache
      await MessageCache.saveSingleMessage(dayNumber, message, writerCode);

      // 🆕 Padidinti dienos rašymo skaitliuką
      await MessageCache.incrementWriteCount(writerCode);

      // 🆕 Priverstinai atnaujinti skaitytojo dienos cache (kad matytų naują žinutę)
      if (dayNumber == todayDayNumber) {
        await MessageCache.forceDailyMessageRefresh();
        await MessageCache.cacheDailyMessage(dayNumber, message, writerCode);
      }

      // Analytics
      try {
        await AnalyticsService.logMessageEdited(
          dayNumber: dayNumber,
          isCustom: true,
          messageLength: message.length,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Analytics warning: $e');
      }

      if (kDebugMode) {
        final remainingWrites = await MessageCache.getRemainingWrites(
          writerCode,
        );
        debugPrint('✅ Viskas išsaugota sėkmingai!');
        debugPrint('📝 Liko žinučių šiandien: $remainingWrites');
      }
      return true;
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'MessageService.saveCustomMessage',
        additionalData: {
          'dayNumber': dayNumber,
          'writerCode': writerCode,
          'messageLength': message.length,
        },
      );

      if (kDebugMode) {
        debugPrint('❌ Klaida išsaugant: $e');
      }
      return false;
    }
  }

  // ✅ SUBCOLLECTION VERSION - Ištrinti žinutę
  Future<bool> deleteCustomMessage({
    required String writerCode,
    required int dayNumber,
  }) async {
    try {
      // ✅ SUBCOLLECTION: Delete from /couples/{writerCode}/messages/{dayNumber}
      await _firestore
          .collection('couples')
          .doc(writerCode)
          .collection('messages')
          .doc(dayNumber.toString())
          .delete();

      // Ištrinti iš cache
      await MessageCache.deleteMessage(dayNumber, writerCode);

      if (kDebugMode) {
        debugPrint('✅ Žinutė ištrinta: day$dayNumber');
      }
      return true;
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'MessageService.deleteCustomMessage',
        additionalData: {'dayNumber': dayNumber, 'writerCode': writerCode},
      );

      // Offline fallback
      try {
        await MessageCache.deleteMessage(dayNumber, writerCode);
        return true;
      } catch (cacheError) {
        return false;
      }
    }
  }

  // ✅ SUBCOLLECTION VERSION - Gauti visas žinutes
  Future<Map<int, String>> getAllCustomMessages(String writerCode) async {
    try {
      // 1. Cache
      final cachedMessages = await MessageCache.getMessages(writerCode);
      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ Messages iš cache: ${cachedMessages.length}');
        }
        return cachedMessages;
      }

      // 2. ✅ SUBCOLLECTION: Get all from /couples/{writerCode}/messages
      if (kDebugMode) {
        debugPrint('☁️ Kraunamos žinutės iš Firestore...');
      }

      final snapshot = await _firestore
          .collection('couples')
          .doc(writerCode)
          .collection('messages')
          .get();

      final customMessages = <int, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dayNumber = data['dayNumber'] as int?;
        final content = data['content'] as String?;

        if (dayNumber != null &&
            dayNumber >= 1 &&
            dayNumber <= 365 &&
            content != null &&
            content.isNotEmpty) {
          customMessages[dayNumber] = content;
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Gauta iš Firestore: ${customMessages.length} žinučių');
      }

      // Išsaugoti į cache
      if (customMessages.isNotEmpty) {
        await MessageCache.saveMessages(customMessages, writerCode);
      }

      return customMessages;
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'MessageService.getAllCustomMessages',
        additionalData: {'writerCode': writerCode},
      );

      if (kDebugMode) {
        debugPrint('❌ Klaida gaunant žinutes: $e');
      }
      return {};
    }
  }
}

// Modeliai
class Month {
  final String name;
  final int monthNumber;
  final List<Day> days;

  Month({required this.name, required this.monthNumber, required this.days});
}

class Day {
  final int dayOfMonth;
  final int dayOfYear;
  final DateTime date;
  String? customMessage;
  bool get isCustom => customMessage != null;

  Day({
    required this.dayOfMonth,
    required this.dayOfYear,
    required this.date,
    this.customMessage,
  });
}
