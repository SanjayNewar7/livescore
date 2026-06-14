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
    );
  }
}