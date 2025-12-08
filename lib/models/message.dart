import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DailyMessage {
  final String id;
  final int dayNumber;
  final String message;
  final bool isCustom;
  final DateTime? customDate;

  DailyMessage({
    required this.id,
    required this.dayNumber,
    required this.message,
    this.isCustom = false,
    this.customDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'message': message,
      'isCustom': isCustom,
      'customDate': customDate != null ? Timestamp.fromDate(customDate!) : null,
    };
  }

  factory DailyMessage.fromMap(String id, Map<String, dynamic> map) {
    return DailyMessage(
      id: id,
      dayNumber: (map['dayNumber'] as int?) ?? 1,
      message: map['message']?.toString() ?? '',
      isCustom: map['isCustom'] as bool? ?? false,
      customDate: _parseTimestamp(map['customDate']),
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
    } catch (e) {
      debugPrint('Klaida konvertuojant customDate: $e');
    }

    return null;
  }
}
