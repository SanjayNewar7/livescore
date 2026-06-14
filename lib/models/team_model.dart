import 'package:hive/hive.dart';

part 'team_model.g.dart';

@HiveType(typeId: 9)
class TeamInfo {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String displayName;

  @HiveField(3)
  final String abbreviation;

  @HiveField(4)
  final String logo;

  @HiveField(5)
  final String color;

  @HiveField(6)
  final String alternateColor;

  @HiveField(7)
  final String record;

  @HiveField(8)
  final String? venueName;

  @HiveField(9)
  final String? coach;

  @HiveField(10)
  final int? foundedYear;

  TeamInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.abbreviation,
    required this.logo,
    required this.color,
    required this.alternateColor,
    required this.record,
    this.venueName,
    this.coach,
    this.foundedYear,
  });

  // Factory method to create from JSON
  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
      logo: json['logo'] ?? '',
      color: json['color'] ?? '#000000',
      alternateColor: json['alternateColor'] ?? '#FFFFFF',
      record: json['record']?.toString() ?? '0-0',
      venueName: json['venue']?['fullName'],
      coach: json['coaches']?.isNotEmpty == true ? json['coaches'][0]['fullName'] : null,
      foundedYear: json['foundedYear'],
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'abbreviation': abbreviation,
      'logo': logo,
      'color': color,
      'alternateColor': alternateColor,
      'record': record,
      'venueName': venueName,
      'coach': coach,
      'foundedYear': foundedYear,
    };
  }

  // Copy with method for updates
  TeamInfo copyWith({
    String? id,
    String? name,
    String? displayName,
    String? abbreviation,
    String? logo,
    String? color,
    String? alternateColor,
    String? record,
    String? venueName,
    String? coach,
    int? foundedYear,
  }) {
    return TeamInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      abbreviation: abbreviation ?? this.abbreviation,
      logo: logo ?? this.logo,
      color: color ?? this.color,
      alternateColor: alternateColor ?? this.alternateColor,
      record: record ?? this.record,
      venueName: venueName ?? this.venueName,
      coach: coach ?? this.coach,
      foundedYear: foundedYear ?? this.foundedYear,
    );
  }

  @override
  String toString() {
    return 'TeamInfo{displayName: $displayName, abbreviation: $abbreviation, record: $record}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}