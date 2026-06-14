import 'package:hive/hive.dart';
import 'team_model.dart';

part 'standing_model.g.dart';

@HiveType(typeId: 6)
class Standing {
  @HiveField(0)
  final int rank;

  @HiveField(1)
  final TeamInfo team;

  @HiveField(2)
  final String wins;

  @HiveField(3)
  final String losses;

  @HiveField(4)
  final String ties;

  @HiveField(5)
  final String winPercentage;

  @HiveField(6)
  final String pointsFor;

  @HiveField(7)
  final String pointsAgainst;

  @HiveField(8)
  final String streak;

  @HiveField(9)
  final bool clinchedPlayoffs;

  @HiveField(10)
  final String conference;

  @HiveField(11)
  final String division;

  @HiveField(12)
  final Map<String, String> stats;

  // NEW FIELDS for soccer standings
  @HiveField(13)
  final int? points;

  @HiveField(14)
  final int? goalsFor;

  @HiveField(15)
  final int? goalsAgainst;

  @HiveField(16)
  final int? goalDifference;

  @HiveField(17)
  final String? form;

  @HiveField(18)
  final int? matchesPlayed;

  Standing({
    required this.rank,
    required this.team,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.winPercentage,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.streak,
    required this.clinchedPlayoffs,
    required this.conference,
    required this.division,
    this.stats = const {},
    this.points,
    this.goalsFor,
    this.goalsAgainst,
    this.goalDifference,
    this.form,
    this.matchesPlayed,
  });

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'team': team.toJson(),
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'winPercentage': winPercentage,
      'pointsFor': pointsFor,
      'pointsAgainst': pointsAgainst,
      'streak': streak,
      'clinchedPlayoffs': clinchedPlayoffs,
      'conference': conference,
      'division': division,
      'stats': stats,
      'points': points,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'goalDifference': goalDifference,
      'form': form,
      'matchesPlayed': matchesPlayed,
    };
  }

  factory Standing.fromJson(Map<String, dynamic> json) {
    return Standing(
      rank: json['rank'] ?? 0,
      team: TeamInfo.fromJson(json['team'] ?? {}),
      wins: json['wins'] ?? '0',
      losses: json['losses'] ?? '0',
      ties: json['ties'] ?? '0',
      winPercentage: json['winPercentage'] ?? '.000',
      pointsFor: json['pointsFor'] ?? '0',
      pointsAgainst: json['pointsAgainst'] ?? '0',
      streak: json['streak'] ?? '0',
      clinchedPlayoffs: json['clinchedPlayoffs'] ?? false,
      conference: json['conference'] ?? '',
      division: json['division'] ?? '',
      stats: Map<String, String>.from(json['stats'] ?? {}),
      points: json['points'],
      goalsFor: json['goalsFor'],
      goalsAgainst: json['goalsAgainst'],
      goalDifference: json['goalDifference'],
      form: json['form'],
      matchesPlayed: json['matchesPlayed'],
    );
  }
}