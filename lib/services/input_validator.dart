/// Input Validator & Sanitizer
/// Validuoja ir valo visus user input duomenis
class InputValidator {
  // ==================== STRING VALIDATION ====================

  /// Validuoti ir išvalyti string (pašalinti HTML, control chars, etc.)
  static String sanitizeString(String input) {
    return input
        .trim()
        // Pašalinti HTML tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // Pašalinti < > simbolius
        .replaceAll(RegExp(r'[<>]'), '')
        // Pašalinti control characters (0x00-0x1F)
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Validuoti vardą (Writer/Reader name)
  static ValidationResult validateName(String name) {
    // 1. Išvalyti
    final sanitized = sanitizeString(name);

    // 2. Tikrinti ilgį
    if (sanitized.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'Vardas negali būti tuščias',
      );
    }

    if (sanitized.length < 2) {
      return ValidationResult(
        isValid: false,
        message: 'Vardas turi būti bent 2 simbolių',
      );
    }

    if (sanitized.length > 50) {
      return ValidationResult(
        isValid: false,
        message: 'Vardas negali būti ilgesnis nei 50 simbolių',
      );
    }

    // 3. Tikrinti ar turi bent vieną raidę
    if (!RegExp(
      r'[a-zA-ZÄ…Ä Ä™Ä—Ä¯Å³Å«Å¡Å¾Ä Ä„Ä˜Ä–Ä®Å²ÅªÅ Å½]',
    ).hasMatch(sanitized)) {
      return ValidationResult(
        isValid: false,
        message: 'Vardas turi turėti bent vieną raidę',
      );
    }

    // 4. Tikrinti ar nėra suspicous patterns
    if (RegExp(
      r'(script|javascript|onclick|onerror)',
      caseSensitive: false,
    ).hasMatch(sanitized)) {
      return ValidationResult(
        isValid: false,
        message: 'Neteisingas vardo formatas',
      );
    }

    return ValidationResult(isValid: true, sanitizedValue: sanitized);
  }

  /// Validuoti žinutę (Message content)
  static ValidationResult validateMessage(String message) {
    // 1. Išvalyti
    final sanitized = sanitizeString(message);

    // 2. Tikrinti ilgį
    if (sanitized.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'Žinutė negali būti tuščia',
      );
    }

    if (sanitized.isEmpty) {
      return ValidationResult(
        isValid: false,
        message: 'Žinutė turi būti bent 1 simbolio',
      );
    }

    if (sanitized.length > 500) {
      return ValidationResult(
        isValid: false,
        message: 'Žinutė negali būti ilgesnė nei 500 simbolių',
        sanitizedValue: sanitized.substring(0, 500), // Hard limit
      );
    }

    // 3. Tikrinti ar nėra spam patterns
    if (_isSpam(sanitized)) {
      return ValidationResult(
        isValid: false,
        message: 'Žinutė atrodo kaip spam',
      );
    }

    return ValidationResult(isValid: true, sanitizedValue: sanitized);
  }

  // ==================== CODE VALIDATION ====================

  /// Validuoti Writer Code formatą
  // input_validator.dart - Line ~158
  static ValidationResult validateWriterCode(String code) {
    final trimmed = code.trim().toUpperCase();

    // ✅ 12 simbolių
    if (!RegExp(r'^W-[A-F0-9]{12}$').hasMatch(trimmed)) {
      return ValidationResult(
        isValid: false,
        message: 'Neteisingas Writer Code formatas',
      );
    }

    return ValidationResult(isValid: true, sanitizedValue: trimmed);
  }

  static ValidationResult validateReaderCode(String code) {
    final trimmed = code.trim().toUpperCase();

    // ✅ 12 simbolių
    if (!RegExp(r'^R-[A-F0-9]{12}$').hasMatch(trimmed)) {
      return ValidationResult(
        isValid: false,
        message: 'Neteisingas Reader Code formatas',
      );
    }

    return ValidationResult(isValid: true, sanitizedValue: trimmed);
  }

  // ==================== NUMBER VALIDATION ====================

  /// Validuoti dienos numerį (1-365)
  static ValidationResult validateDayNumber(int dayNumber) {
    if (dayNumber < 1 || dayNumber > 365) {
      return ValidationResult(
        isValid: false,
        message: 'Dienos numeris turi būti tarp 1 ir 365',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ==================== HELPER FUNCTIONS ====================

  /// Tikrinti ar žinutė atrodo kaip spam
  static bool _isSpam(String text) {
    final lower = text.toLowerCase();

    // Spam keywords
    final spamKeywords = [
      'click here',
      'free money',
      'buy now',
      'limited offer',
      'act now',
      'viagra',
      'casino',
      'lottery',
    ];

    for (final keyword in spamKeywords) {
      if (lower.contains(keyword)) return true;
    }

    // Per daug URL'ų
    final urlCount = RegExp(r'https?://').allMatches(text).length;
    if (urlCount > 2) return true;

    // Per daug specialių simbolių
    final specialChars = RegExp(
      r'[!@#$%^&*()_+=\[\]{};:"|,.<>?]',
    ).allMatches(text).length;
    if (specialChars > text.length * 0.3) return true; // >30% special chars

    // Per daug CAPS
    final capsCount = RegExp(
      r'[A-ZĄĮĘĖŲŪŠŽČāįęėųūšžč]',
    ).allMatches(text).length;
    if (capsCount > text.length * 0.7) return true; // >70% caps

    return false;
  }

  /// Tikrinti ar string turi tik leistinus simbolius
  static bool hasOnlyAllowedCharacters(String text, {String? allowedPattern}) {
    final pattern =
        allowedPattern ?? r'^[a-zA-ZĄĮĘĖŲŪŠŽČąįęėųūšžč0-9\s.,!?-]+$';
    return RegExp(pattern).hasMatch(text);
  }

  /// Pašalinti visus emoji (jei reikia)
  static String removeEmojis(String text) {
    return text.replaceAll(
      RegExp(
        r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
      ),
      '',
    );
  }

  /// Sutrumpinti tekstą su ...
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }
}

/// Validation Result klasė
class ValidationResult {
  final bool isValid;
  final String? message;
  final String? sanitizedValue;

  ValidationResult({required this.isValid, this.message, this.sanitizedValue});

  /// Quick helper - throw exception jei invalid
  void throwIfInvalid() {
    if (!isValid) {
      throw ValidationException(message ?? 'Neteisingi duomenys');
    }
  }
}

/// Custom Validation Exception
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => message;
}
