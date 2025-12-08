import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/couple.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'error_handler.dart';
import 'input_validator.dart';
import 'rate_limiter.dart';

class CoupleService {
  static final CoupleService _instance = CoupleService._internal();
  factory CoupleService() => _instance;
  CoupleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // ==================== INICIALIZACIJA ====================

  Future<void> initialize() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      await _authService.ensureAuthenticated();
      _isInitialized = true;
      debugPrint('✅ CoupleService initialized');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // ==================== PORŲ VALDYMAS ====================

  /// Sukurti naują porą (Rašytojas)
  Future<Map<String, dynamic>> createCouple(String writerName) async {
    try {
      await _ensureInitialized();

      // 1. Rate Limiting
      if (!RateLimiter.checkWithConfig('create_couple')) {
        final remaining = RateLimiter.getRemainingCooldown(
          'create_couple',
          cooldownSeconds: 10,
        );
        return {
          'success': false,
          'error': 'Per daug bandymų. Palaukite $remaining sekundžių.',
        };
      }

      // 2. Validuoti vardą
      final nameValidation = InputValidator.validateName(writerName);
      if (!nameValidation.isValid) {
        return {'success': false, 'error': nameValidation.message};
      }
      final sanitizedName = nameValidation.sanitizedValue!;

      // 3. Patikrinti auth
      final userId = _authService.currentUserId;
      if (userId == null) {
        await _authService.signInAnonymously();
        final newUserId = _authService.currentUserId;
        if (newUserId == null) {
          return {
            'success': false,
            'error': 'Nepavyko prisijungti. Patikrinkite internetą.',
          };
        }
      }

      // 4. Generuoti kodus
      final writerCode = _generateSecureCode('W');
      final readerCode = _generateSecureCode('R');

      // 5. Sukurti Couple objektą
      final couple = Couple(
        writerCode: writerCode,
        readerCode: readerCode,
        writerName: sanitizedName,
        isActive: true,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        userId: _authService.currentUserId,
      );

      // 6. BATCH WRITE - Couple + ReaderCode index
      final batch = _firestore.batch();

      final coupleRef = _firestore.collection('couples').doc(writerCode);
      batch.set(coupleRef, couple.toMap());

      final readerCodeRef = _firestore
          .collection('readerCodes')
          .doc(readerCode);
      batch.set(readerCodeRef, {
        'writerCode': writerCode,
        'createdBy': _authService.currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('✅ Couple + ReaderCode index created: $writerCode');

      // 7. Išsaugoti lokaliai
      await _saveToLocalStorage(
        writerCode: writerCode,
        readerCode: readerCode,
        isWriter: true,
        writerName: sanitizedName,
      );

      // 8. Analytics
      try {
        await AnalyticsService.logCoupleCreated();
      } catch (e) {
        debugPrint('Analytics warning: $e');
      }

      return {
        'success': true,
        'writerCode': writerCode,
        'readerCode': readerCode,
      };
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'createCouple',
        additionalData: {'writerName': writerName},
      );

      return {
        'success': false,
        'error': ErrorHandler.getUserFriendlyMessage(e),
      };
    }
  }

  /// Prisijungti prie poros (Skaitytojas)
  Future<Map<String, dynamic>> joinCouple(String readerCode) async {
    try {
      await _ensureInitialized();

      // 1. Rate Limiting
      if (!RateLimiter.checkWithConfig('join_couple')) {
        final remaining = RateLimiter.getRemainingCooldown(
          'join_couple',
          cooldownSeconds: 5,
        );
        return {
          'success': false,
          'error': 'Per daug bandymų. Palaukite $remaining sekundžių.',
        };
      }

      // 2. Validuoti reader code
      final codeValidation = InputValidator.validateReaderCode(readerCode);
      if (!codeValidation.isValid) {
        return {'success': false, 'error': codeValidation.message};
      }
      final sanitizedCode = codeValidation.sanitizedValue!;

      // 3. Patikrinti auth
      await _authService.ensureAuthenticated();

      final currentUserId = _authService.currentUserId;
      if (currentUserId == null) {
        return {
          'success': false,
          'error': 'Nepavyko prisijungti. Patikrinkite internetą.',
        };
      }

      // 4. Gauti writerCode iš readerCodes index
      debugPrint('🔍 Ieškoma readerCode index: $sanitizedCode');

      final readerCodeDoc = await _firestore
          .collection('readerCodes')
          .doc(sanitizedCode)
          .get();

      if (!readerCodeDoc.exists) {
        debugPrint('❌ ReaderCode index nerastas');
        return {'success': false, 'error': 'Kodas nerastas'};
      }

      final indexData = readerCodeDoc.data()!;
      final writerCode = indexData['writerCode'] as String;

      debugPrint('✅ Rastas writerCode: $writerCode');

      // 5. Gauti couple dokumentą
      final coupleDoc = await _firestore
          .collection('couples')
          .doc(writerCode)
          .get();

      if (!coupleDoc.exists) {
        return {'success': false, 'error': 'Pora nerasta'};
      }

      final coupleData = coupleDoc.data()!;

      // 6. Patikrinti ar pora aktyvi
      final isActive = coupleData['isActive'] as bool? ?? false;
      if (!isActive) {
        return {'success': false, 'error': 'Ši pora nebėra aktyvi'};
      }

      final writerName = coupleData['writerName'] as String;
      final readerJoined = coupleData['readerJoined'] as bool? ?? false;

      // ✅ 7. NAUJAS: Patikrinti ar tai PIRMAS JOIN ar REJOIN
      if (readerJoined) {
        // REJOIN - reader jau buvo prisijungęs, atnaujinti userId
        debugPrint('🔄 Reader REJOIN - atnaujinamas userId');

        try {
          await coupleDoc.reference.update({
            'readerUserId': currentUserId,
            'readerJoinedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Reader userId atnaujintas (rejoin)');
        } catch (firestoreError) {
          debugPrint('❌ Firestore update error: $firestoreError');
          return {
            'success': false,
            'error': 'Nepavyko prisijungti. Bandykite dar kartą.',
          };
        }
      } else {
        // PIRMAS JOIN - naujas reader
        debugPrint('🆕 Reader PIRMAS prisijungimas');

        try {
          await coupleDoc.reference.update({
            'readerJoined': true,
            'readerUserId': currentUserId,
            'readerJoinedAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Reader prisijungė pirmą kartą');
        } catch (firestoreError) {
          debugPrint('❌ Firestore update error: $firestoreError');
          return {
            'success': false,
            'error': 'Nepavyko išsaugoti duomenų. Bandykite dar kartą.',
          };
        }
      }

      // 8. Išsaugoti lokaliai
      await _saveToLocalStorage(
        writerCode: writerCode,
        readerCode: sanitizedCode,
        isWriter: false,
        writerName: writerName,
      );

      // 9. Analytics
      try {
        await AnalyticsService.logReaderJoined();
      } catch (e) {
        debugPrint('Analytics warning: $e');
      }

      debugPrint('✅ Reader joined successfully');

      return {
        'success': true,
        'writerCode': writerCode,
        'writerName': writerName,
      };
    } catch (e, stack) {
      await ErrorHandler.logError(
        e,
        stack,
        context: 'joinCouple',
        additionalData: {'readerCode': readerCode},
      );

      return {
        'success': false,
        'error': ErrorHandler.getUserFriendlyMessage(e),
      };
    }
  }

  /// Patikrinti ar pora egzistuoja
  Future<Map<String, dynamic>> checkCoupleExists(String writerCode) async {
    try {
      final codeValidation = InputValidator.validateWriterCode(writerCode);
      if (!codeValidation.isValid) {
        return {
          'success': false,
          'error': codeValidation.message,
          'exists': false,
        };
      }
      final sanitizedCode = codeValidation.sanitizedValue!;

      final doc = await _firestore
          .collection('couples')
          .doc(sanitizedCode)
          .get();

      if (!doc.exists) {
        return {'success': false, 'error': 'Poros nerasta', 'exists': false};
      }

      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] ?? false;

      return {
        'success': true,
        'exists': true,
        'isActive': isActive,
        'writerName': data['writerName'],
        'readerCode': data['readerCode'],
      };
    } catch (e, stack) {
      await ErrorHandler.logError(e, stack, context: 'checkCoupleExists');

      return {
        'success': false,
        'error': ErrorHandler.getUserFriendlyMessage(e),
      };
    }
  }

  /// Disable pora
  Future<bool> disableCouple(String writerCode) async {
    try {
      await _firestore.collection('couples').doc(writerCode).update({
        'isActive': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Couple disabled: $writerCode');
      return true;
    } catch (e, stack) {
      await ErrorHandler.logError(e, stack, context: 'disableCouple');
      return false;
    }
  }

  // ==================== LOKALUS DUOMENYS ====================

  Future<void> _saveToLocalStorage({
    required String writerCode,
    required String readerCode,
    required bool isWriter,
    required String writerName,
  }) async {
    await _prefs.setString('writerCode', writerCode);
    await _prefs.setString('readerCode', readerCode);
    await _prefs.setBool('isWriter', isWriter);
    await _prefs.setString('writerName', writerName);
    await _prefs.setBool('isPaired', true);
    await _prefs.setString('pairedAt', DateTime.now().toIso8601String());
  }

  Future<void> saveToLocalStorage({
    required String writerCode,
    required String readerCode,
    required bool isWriter,
    required String writerName,
  }) async {
    await _ensureInitialized();
    await _saveToLocalStorage(
      writerCode: writerCode,
      readerCode: readerCode,
      isWriter: isWriter,
      writerName: writerName,
    );
  }

  Future<bool> isPaired() async {
    await _ensureInitialized();
    return _prefs.getBool('isPaired') ?? false;
  }

  Future<bool> isWriter() async {
    await _ensureInitialized();
    return _prefs.getBool('isWriter') ?? false;
  }

  Future<String?> getWriterCode() async {
    await _ensureInitialized();
    return _prefs.getString('writerCode');
  }

  Future<String?> getReaderCode() async {
    await _ensureInitialized();
    return _prefs.getString('readerCode');
  }

  Future<String?> getWriterName() async {
    await _ensureInitialized();
    return _prefs.getString('writerName');
  }

  Future<Map<String, dynamic>> getPairingInfo() async {
    await _ensureInitialized();

    return {
      'isPaired': _prefs.getBool('isPaired') ?? false,
      'isWriter': _prefs.getBool('isWriter') ?? false,
      'writerCode': _prefs.getString('writerCode'),
      'readerCode': _prefs.getString('readerCode'),
      'writerName': _prefs.getString('writerName'),
      'pairedAt': _prefs.getString('pairedAt'),
    };
  }

  Future<void> logout() async {
    await _ensureInitialized();

    await _prefs.remove('writerCode');
    await _prefs.remove('readerCode');
    await _prefs.remove('isWriter');
    await _prefs.remove('writerName');
    await _prefs.remove('isPaired');
    await _prefs.remove('pairedAt');

    RateLimiter.clearAll();

    debugPrint('✅ Logged out');
  }

  // ==================== CODE GENERATION ====================

  String _generateSecureCode(String prefix) {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomValue = random.nextInt(999999999);

    final combined = '$timestamp-$randomValue-${random.nextInt(999999999)}';
    final hash = sha256.convert(utf8.encode(combined));

    final code = hash.toString().substring(0, 12).toUpperCase();

    return '$prefix-$code';
  }

  // ==================== HELPER METHODS ====================

  Future<bool> coupleExists(String writerCode) async {
    try {
      final result = await checkCoupleExists(writerCode);
      return result['exists'] == true && result['isActive'] == true;
    } catch (e) {
      return false;
    }
  }
}
