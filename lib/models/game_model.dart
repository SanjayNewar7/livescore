import 'package:hive/hive.dart';
import 'team_model.dart';

part 'game_model.g.dart';

@HiveType(typeId: 14)
class GoalScorer {
  @HiveField(0)
  final String playerId;

  @HiveField(1)
  final String playerName;

  @HiveField(2)
  final int minute;

  @HiveField(3)
  final bool isHomeTeam;

  @HiveField(4)
  final int? addedTime;

  @HiveField(5)
  final String? assistPlayerName;

  @HiveField(6)
  final bool isPenalty;

  @HiveField(7)
  final bool isOwnGoal;

  GoalScorer({
    required this.playerId,
    required this.playerName,
    required this.minute,
    required this.isHomeTeam,
    this.addedTime,
    this.assistPlayerName,
    this.isPenalty = false,
    this.isOwnGoal = false,
  });

  String get minuteDisplay {
    if (addedTime != null && addedTime! > 0) {
      return "$minute+$addedTime'";
    }
    return "$minute'";
  }

  String get displayText {
    String text = playerName;
    if (isPenalty) text += " (P)";
    if (isOwnGoal) text += " (OG)";
    if (assistPlayerName != null && assistPlayerName!.isNotEmpty) {
      text += " (ast: $assistPlayerName)";
    }
    return text;
  }

  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'minute': minute,
      'isHomeTeam': isHomeTeam,
      'addedTime': addedTime,
      'assistPlayerName': assistPlayerName,
      'isPenalty': isPenalty,
      'isOwnGoal': isOwnGoal,
    };
  }

  factory GoalScorer.fromJson(Map<String, dynamic> json) {
    return GoalScorer(
      playerId: json['playerId'] ?? '',
      playerName: json['playerName'] ?? '',
      minute: json['minute'] ?? 0,
      isHomeTeam: json['isHomeTeam'] ?? false,
      addedTime: json['addedTime'],
      assistPlayerName: json['assistPlayerName'],
      isPenalty: json['isPenalty'] ?? false,
      isOwnGoal: json['isOwnGoal'] ?? false,
    );
  }
}

@HiveType(typeId: 0)
class Game {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String status;

  @HiveField(2)
  final String shortDetail;

  @HiveField(3)
  final TeamInfo awayTeam;

  @HiveField(4)
  final TeamInfo homeTeam;

  @HiveField(5)
  final String awayScore;

  @HiveField(6)
  final String homeScore;

  @HiveField(7)
  final List<int> awayLineScores;

  @HiveField(8)
  final List<int> homeLineScores;

  @HiveField(9)
  final Venue venue;

  @HiveField(10)
  final String date;

  @HiveField(11)
  final String clock;

  @HiveField(12)
  final String period;

  @HiveField(13)
  final String leagueName;

  @HiveField(14)
  final String leagueFlag;

  @HiveField(15)
  final List<GoalScorer> goalScorers;

  @HiveField(16)
  final String awayTeamFullName;

  @HiveField(17)
  final String homeTeamFullName;

  @HiveField(18)
  final String awayTeamShortName;

  @HiveField(19)
  final String homeTeamShortName;

  Game({
    required this.id,
    required this.status,
    required this.shortDetail,
    required this.awayTeam,
    required this.homeTeam,
    required this.awayScore,
    required this.homeScore,
    required this.awayLineScores,
    required this.homeLineScores,
    required this.venue,
    required this.date,
    required this.clock,
    required this.period,
    this.leagueName = '',
    this.leagueFlag = '',
    this.goalScorers = const [],
    this.awayTeamFullName = '',
    this.homeTeamFullName = '',
    this.awayTeamShortName = '',
    this.homeTeamShortName = '',
  });

  // Helper getters
  List<GoalScorer> get awayTeamGoals => goalScorers.where((g) => !g.isHomeTeam).toList();
  List<GoalScorer> get homeTeamGoals => goalScorers.where((g) => g.isHomeTeam).toList();

  bool get hasGoals => goalScorers.isNotEmpty;

  String get formattedDate {
    try {
      final gameDate = DateTime.parse(date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final gameDay = DateTime(gameDate.year, gameDate.month, gameDate.day);

      if (gameDay == today) return 'Today';
      if (gameDay == tomorrow) return 'Tomorrow';

      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[gameDate.month - 1]} ${gameDate.day}, ${gameDate.year}';
    } catch (e) {
      return '';
    }
  }

  String get formattedDateTime {
    try {
      final gameDate = DateTime.parse(date);
      return '$formattedDate • ${_formatTime(gameDate)}';
    } catch (e) {
      return '';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $ampm';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'shortDetail': shortDetail,
      'awayTeam': awayTeam.toJson(),
      'homeTeam': homeTeam.toJson(),
      'awayScore': awayScore,
      'homeScore': homeScore,
      'awayLineScores': awayLineScores,
      'homeLineScores': homeLineScores,
      'venue': venue.toJson(),
      'date': date,
      'clock': clock,
      'period': period,
      'leagueName': leagueName,
      'leagueFlag': leagueFlag,
      'goalScorers': goalScorers.map((g) => g.toJson()).toList(),
      'awayTeamFullName': awayTeamFullName,
      'homeTeamFullName': homeTeamFullName,
      'awayTeamShortName': awayTeamShortName,
      'homeTeamShortName': homeTeamShortName,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      shortDetail: json['shortDetail'] ?? '',
      awayTeam: TeamInfo.fromJson(json['awayTeam'] ?? {}),
      homeTeam: TeamInfo.fromJson(json['homeTeam'] ?? {}),
      awayScore: json['awayScore'] ?? '0',
      homeScore: json['homeScore'] ?? '0',
      awayLineScores: List<int>.from(json['awayLineScores'] ?? []),
      homeLineScores: List<int>.from(json['homeLineScores'] ?? []),
      venue: Venue.fromJson(json['venue'] ?? {}),
      date: json['date'] ?? '',
      clock: json['clock'] ?? '',
      period: json['period'] ?? '',
      leagueName: json['leagueName'] ?? '',
      leagueFlag: json['leagueFlag'] ?? '',
      goalScorers: (json['goalScorers'] as List?)
          ?.map((g) => GoalScorer.fromJson(g))
          .toList() ?? [],
      awayTeamFullName: json['awayTeamFullName'] ?? '',
      homeTeamFullName: json['homeTeamFullName'] ?? '',
      awayTeamShortName: json['awayTeamShortName'] ?? '',
      homeTeamShortName: json['homeTeamShortName'] ?? '',
    );
  }
}

@HiveType(typeId: 2)
class Venue {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fullName;

  @HiveField(2)
  final String city;

  @HiveField(3)
  final String state;

  @HiveField(4)
  final int capacity;

  @HiveField(5)
  final String? imageUrl;

  Venue({
    required this.id,
    required this.fullName,
    required this.city,
    required this.state,
    required this.capacity,
    this.imageUrl,
  });

  String get locationDisplay {
    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city, $state';
    } else if (city.isNotEmpty) {
      return city;
    } else if (state.isNotEmpty) {
      return state;
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'city': city,
      'state': state,
      'capacity': capacity,
      'imageUrl': imageUrl,
    };
  }

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      capacity: json['capacity'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }
}

@HiveType(typeId: 3)
class WinProbability {
  @HiveField(0)
  final String gameId;

  @HiveField(1)
  final int quarter;

  @HiveField(2)
  final String time;

  @HiveField(3)
  final double awayWinPercentage;

  @HiveField(4)
  final double homeWinPercentage;

  @HiveField(5)
  final int awayScore;

  @HiveField(6)
  final int homeScore;

  WinProbability({
    required this.gameId,
    required this.quarter,
    required this.time,
    required this.awayWinPercentage,
    required this.homeWinPercentage,
    required this.awayScore,
    required this.homeScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameId': gameId,
      'quarter': quarter,
      'time': time,
      'awayWinPercentage': awayWinPercentage,
      'homeWinPercentage': homeWinPercentage,
      'awayScore': awayScore,
      'homeScore': homeScore,
    };
  }

  factory WinProbability.fromJson(Map<String, dynamic> json) {
    return WinProbability(
      gameId: json['gameId'] ?? '',
      quarter: json['quarter'] ?? 0,
      time: json['time'] ?? '0:00',
      awayWinPercentage: (json['awayWinPercentage'] ?? 0.0).toDouble(),
      homeWinPercentage: (json['homeWinPercentage'] ?? 0.0).toDouble(),
      awayScore: json['awayScore'] ?? 0,
      homeScore: json['homeScore'] ?? 0,
    );
  }
}

@HiveType(typeId: 4)
class GameDetail {
  @HiveField(0)
  final Game game;

  @HiveField(1)
  final List<WinProbability> winProbabilities;

  @HiveField(2)
  final Map<String, dynamic> boxScore;

  @HiveField(3)
  final List<Play> plays;

  GameDetail({
    required this.game,
    required this.winProbabilities,
    required this.boxScore,
    required this.plays,
  });

  Map<String, dynamic> toJson() {
    return {
      'game': game.toJson(),
      'winProbabilities': winProbabilities.map((w) => w.toJson()).toList(),
      'boxScore': boxScore,
      'plays': plays.map((p) => p.toJson()).toList(),
    };
  }

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    return GameDetail(
      game: Game.fromJson(json['game'] ?? {}),
      winProbabilities: (json['winProbabilities'] as List?)
          ?.map((w) => WinProbability.fromJson(w))
          .toList() ?? [],
      boxScore: json['boxScore'] ?? {},
      plays: (json['plays'] as List?)
          ?.map((p) => Play.fromJson(p))
          .toList() ?? [],
    );
  }
}

@HiveType(typeId: 5)
class Play {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int quarter;

  @HiveField(2)
  final String time;

  @HiveField(3)
  final String text;

  @HiveField(4)
  final String type;

  @HiveField(5)
  final int awayScore;

  @HiveField(6)
  final int homeScore;

  @HiveField(7)
  final String? playerName;

  @HiveField(8)
  final String? playerId;

  Play({
    required this.id,
    required this.quarter,
    required this.time,
    required this.text,
    required this.type,
    required this.awayScore,
    required this.homeScore,
    this.playerName,
    this.playerId,
  });

  bool get isGoal => type.toLowerCase().contains('goal') ||
      text.toLowerCase().contains('goal') ||
      text.toLowerCase().contains('scored');

  bool get isCard => type.toLowerCase().contains('card') ||
      text.toLowerCase().contains('yellow') ||
      text.toLowerCase().contains('red');

  bool get isSubstitution => type.toLowerCase().contains('substitution') ||
      text.toLowerCase().contains('substitutes');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quarter': quarter,
      'time': time,
      'text': text,
      'type': type,
      'awayScore': awayScore,
      'homeScore': homeScore,
      'playerName': playerName,
      'playerId': playerId,
    };
  }

  factory Play.fromJson(Map<String, dynamic> json) {
    return Play(
      id: json['id'] ?? '',
      quarter: json['quarter'] ?? 0,
      time: json['time'] ?? '0:00',
      text: json['text'] ?? '',
      type: json['type'] ?? 'play',
      awayScore: json['awayScore'] ?? 0,
      homeScore: json['homeScore'] ?? 0,
      playerName: json['playerName'],
      playerId: json['playerId'],
    );
  }
}