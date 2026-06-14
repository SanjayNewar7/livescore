import 'package:hive/hive.dart';
import 'team_model.dart';

part 'team_detail_model.g.dart';

@HiveType(typeId: 10)
class TeamDetail {
  @HiveField(0)
  final TeamInfo basicInfo;

  @HiveField(1)
  final String? stadiumName;

  @HiveField(2)
  final String? stadiumCity;

  @HiveField(3)
  final String? stadiumState;

  @HiveField(4)
  final int? stadiumCapacity;

  @HiveField(5)
  final String? headCoach;

  @HiveField(6)
  final String? generalManager;

  @HiveField(7)
  final String? owner;

  @HiveField(8)
  final String? conference;

  @HiveField(9)
  final String? division;

  @HiveField(10)
  final List<String>? championships;

  @HiveField(11)
  final Map<String, dynamic>? seasonStats;

  @HiveField(12)
  final List<Map<String, dynamic>>? upcomingGames;

  @HiveField(13)
  final List<Map<String, dynamic>>? pastGames;

  TeamDetail({
    required this.basicInfo,
    this.stadiumName,
    this.stadiumCity,
    this.stadiumState,
    this.stadiumCapacity,
    this.headCoach,
    this.generalManager,
    this.owner,
    this.conference,
    this.division,
    this.championships,
    this.seasonStats,
    this.upcomingGames,
    this.pastGames,
  });

  factory TeamDetail.fromJson(Map<String, dynamic> json, TeamInfo basicInfo) {
    final venue = json['venue'];

    return TeamDetail(
      basicInfo: basicInfo,
      stadiumName: venue?['fullName'],
      stadiumCity: venue?['address']?['city'],
      stadiumState: venue?['address']?['state'],
      stadiumCapacity: venue?['capacity'],
      headCoach: json['coaches']?.isNotEmpty == true
          ? json['coaches'][0]['fullName']
          : null,
      generalManager: json['generalManager'],
      owner: json['owner'],
      conference: json['conference']?['name'],
      division: json['division']?['name'],
      championships: json['championships']?.cast<String>(),
      seasonStats: json['record'],
      upcomingGames: json['nextEvents']?.cast<Map<String, dynamic>>(),
      pastGames: json['pastEvents']?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basicInfo': basicInfo.toJson(),
      'stadiumName': stadiumName,
      'stadiumCity': stadiumCity,
      'stadiumState': stadiumState,
      'stadiumCapacity': stadiumCapacity,
      'headCoach': headCoach,
      'generalManager': generalManager,
      'owner': owner,
      'conference': conference,
      'division': division,
      'championships': championships,
      'seasonStats': seasonStats,
      'upcomingGames': upcomingGames,
      'pastGames': pastGames,
    };
  }
}