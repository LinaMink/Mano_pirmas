import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Couple {
  final String writerCode;
  final String readerCode;
  final String writerName;
  final String? readerName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final String relationshipType;
  final String? userId;
  final String? readerUserId;

  // ✅ PRIDĖTI ŠIŲ LAUKŲ:
  final bool readerJoined;
  final DateTime? readerJoinedAt;

  Couple({
    required this.writerCode,
    required this.readerCode,
    required this.writerName,
    this.readerName,
    required this.isActive,
    required this.createdAt,
    required this.lastUpdated,
    this.relationshipType = 'romantic',
    this.userId,
    this.readerUserId,
    this.readerJoined = false, // ✅ DEFAULT false
    this.readerJoinedAt, // ✅ NAUJAS
  });

  Map<String, dynamic> toMap() {
    return {
      'writerCode': writerCode,
      'readerCode': readerCode,
      'writerName': writerName,
      'readerName': readerName,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'relationshipType': relationshipType,
      'userId': userId,
      'readerUserId': readerUserId,
      'readerJoined': readerJoined, // ✅ PRIDĖTI
      'readerJoinedAt': readerJoinedAt != null
          ? Timestamp.fromDate(readerJoinedAt!)
          : null, // ✅ PRIDĖTI
    };
  }

  factory Couple.fromMap(Map<String, dynamic> map) {
    return Couple(
      writerCode: map['writerCode']?.toString() ?? '',
      readerCode: map['readerCode']?.toString() ?? '',
      writerName: map['writerName']?.toString() ?? 'Rašytojas',
      readerName: map['readerName']?.toString(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']),
      lastUpdated: _parseTimestamp(map['lastUpdated']),
      relationshipType: map['relationshipType']?.toString() ?? 'romantic',
      userId: map['userId']?.toString(),
      readerUserId: map['readerUserId']?.toString(),
      readerJoined: map['readerJoined'] as bool? ?? false, // ✅ PRIDĖTI
      readerJoinedAt: map['readerJoinedAt'] != null
          ? _parseTimestamp(map['readerJoinedAt'])
          : null, // ✅ PRIDĖTI
    );
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    try {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Klaida konvertuojant timestamp: $e');
    }

    return DateTime.now();
  }

  factory Couple.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Couple.fromMap(data);
  }
}
