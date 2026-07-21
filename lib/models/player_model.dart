// lib/models/player_model.dart

import 'dart:ui';

import 'package:hive/hive.dart';

part 'player_model.g.dart';

@HiveType(typeId: 7)
class Player {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String displayName;

  @HiveField(3)
  final String headshot;

  @HiveField(4)
  final String jersey;

  @HiveField(5)
  final String position;

  @HiveField(6)
  final String teamId;

  @HiveField(7)
  final String teamName;

  @HiveField(8)
  final int height;

  @HiveField(9)
  final int weight;

  @HiveField(10)
  final int age;

  @HiveField(11)
  final String college;

  @HiveField(12)
  final Map<String, dynamic> statistics;

  @HiveField(13)
  final String? injuryStatus;

  // ─── NEW FIELDS ──────────────────────────────────────────────────────────────

  @HiveField(14)
  final String? nationality;

  @HiveField(15)
  final String? birthDate;

  @HiveField(16)
  final String? foot;

  @HiveField(17)
  final String? preferredPosition;

  @HiveField(18)
  final double? marketValue;

  @HiveField(19)
  final String? contractExpiry;

  @HiveField(20)
  final Map<String, dynamic>? seasonStats;

  @HiveField(21)
  final List<Map<String, dynamic>>? careerStats;

  Player({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.headshot,
    required this.jersey,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.height,
    required this.weight,
    required this.age,
    required this.college,
    required this.statistics,
    this.injuryStatus,
    this.nationality,
    this.birthDate,
    this.foot,
    this.preferredPosition,
    this.marketValue,
    this.contractExpiry,
    this.seasonStats,
    this.careerStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'displayName': displayName,
      'headshot': headshot,
      'jersey': jersey,
      'position': position,
      'teamId': teamId,
      'teamName': teamName,
      'height': height,
      'weight': weight,
      'age': age,
      'college': college,
      'statistics': statistics,
      'injuryStatus': injuryStatus,
      'nationality': nationality,
      'birthDate': birthDate,
      'foot': foot,
      'preferredPosition': preferredPosition,
      'marketValue': marketValue,
      'contractExpiry': contractExpiry,
      'seasonStats': seasonStats,
      'careerStats': careerStats,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      displayName: json['displayName'] ?? '',
      headshot: json['headshot'] ?? '',
      jersey: json['jersey'] ?? '',
      position: json['position'] ?? '',
      teamId: json['teamId'] ?? '',
      teamName: json['teamName'] ?? '',
      height: json['height'] ?? 0,
      weight: json['weight'] ?? 0,
      age: json['age'] ?? 0,
      college: json['college'] ?? '',
      statistics: json['statistics'] ?? {},
      injuryStatus: json['injuryStatus'],
      nationality: json['nationality'],
      birthDate: json['birthDate'],
      foot: json['foot'],
      preferredPosition: json['preferredPosition'],
      marketValue: json['marketValue']?.toDouble(),
      contractExpiry: json['contractExpiry'],
      seasonStats: json['seasonStats'],
      careerStats: json['careerStats']?.cast<Map<String, dynamic>>(),
    );
  }

  Player copyWith({
    String? id,
    String? fullName,
    String? displayName,
    String? headshot,
    String? jersey,
    String? position,
    String? teamId,
    String? teamName,
    int? height,
    int? weight,
    int? age,
    String? college,
    Map<String, dynamic>? statistics,
    String? injuryStatus,
    String? nationality,
    String? birthDate,
    String? foot,
    String? preferredPosition,
    double? marketValue,
    String? contractExpiry,
    Map<String, dynamic>? seasonStats,
    List<Map<String, dynamic>>? careerStats,
  }) {
    return Player(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      displayName: displayName ?? this.displayName,
      headshot: headshot ?? this.headshot,
      jersey: jersey ?? this.jersey,
      position: position ?? this.position,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      age: age ?? this.age,
      college: college ?? this.college,
      statistics: statistics ?? this.statistics,
      injuryStatus: injuryStatus ?? this.injuryStatus,
      nationality: nationality ?? this.nationality,
      birthDate: birthDate ?? this.birthDate,
      foot: foot ?? this.foot,
      preferredPosition: preferredPosition ?? this.preferredPosition,
      marketValue: marketValue ?? this.marketValue,
      contractExpiry: contractExpiry ?? this.contractExpiry,
      seasonStats: seasonStats ?? this.seasonStats,
      careerStats: careerStats ?? this.careerStats,
    );
  }

  // ─── HELPER GETTERS ──────────────────────────────────────────────────────────

  String get displayHeight {
    if (height <= 0) return 'N/A';
    final feet = height ~/ 12;
    final inches = height % 12;
    return "$feet'$inches\"";
  }

  String get displayWeight {
    if (weight <= 0) return 'N/A';
    return '$weight lbs';
  }

  String get displayAge {
    if (age <= 0) return 'N/A';
    return '$age years';
  }

  String get displayNameWithNumber {
    if (jersey.isNotEmpty) {
      return '#$jersey $displayName';
    }
    return displayName;
  }

  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  String get positionDisplay {
    if (position.isEmpty) return 'N/A';
    return position.toUpperCase();
  }

  /// Birth place from nationality
  String get birthPlace {
    if (nationality != null && nationality!.isNotEmpty) {
      return nationality!;
    }
    return 'N/A';
  }

  /// Experience in years (approx)
  String get experienceDisplay {
    if (age <= 0) return 'N/A';
    final years = age - 16; // Approximate pro years
    if (years <= 0) return 'Rookie';
    return '$years years pro';
  }

  bool get hasInjury => injuryStatus != null &&
      !injuryStatus!.toLowerCase().contains('healthy') &&
      !injuryStatus!.toLowerCase().contains('active');

  String get injuryLabel {
    if (injuryStatus == null) return 'Available';
    final s = injuryStatus!.toLowerCase();
    if (s.contains('healthy') || s.contains('active')) return 'Available';
    if (s.contains('questionable') || s.contains('day-to-day')) return 'Questionable';
    if (s.contains('out') || s.contains('injured')) return 'Out';
    return injuryStatus!;
  }

  Color get injuryColor {
    if (injuryStatus == null) return const Color(0xFF16A34A);
    final s = injuryStatus!.toLowerCase();
    if (s.contains('healthy') || s.contains('active')) return const Color(0xFF16A34A);
    if (s.contains('questionable') || s.contains('day-to-day')) return const Color(0xFFCA8A04);
    if (s.contains('out') || s.contains('injured')) return const Color(0xFFDC2626);
    return const Color(0xFF6B7A96);
  }

  /// Get market value formatted
  String get marketValueDisplay {
    if (marketValue == null || marketValue! <= 0) return 'N/A';
    if (marketValue! >= 100) {
      return '€${(marketValue! / 100).toStringAsFixed(1)}B';
    }
    if (marketValue! >= 1) {
      return '€${marketValue!.toStringAsFixed(1)}M';
    }
    return '€${(marketValue! * 1000).toStringAsFixed(0)}K';
  }

  /// Get contract expiry formatted
  String get contractDisplay {
    if (contractExpiry == null || contractExpiry!.isEmpty) return 'N/A';
    return contractExpiry!;
  }

  @override
  String toString() {
    return 'Player{id: $id, displayName: $displayName, teamName: $teamName, position: $position}';
  }
}