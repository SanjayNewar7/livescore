// lib/models/league_leader_model.dart
// Lightweight model for league-wide stat leaders (top scorer, top assist,
// most yellow cards, most red cards) pulled from ESPN's core API.

class LeaderEntry {
  final String athleteId;
  final String name;
  final String headshot;
  final String teamId;
  final String teamAbbreviation;
  final String teamLogo;
  final num value;

  const LeaderEntry({
    required this.athleteId,
    required this.name,
    required this.headshot,
    required this.teamId,
    required this.teamAbbreviation,
    required this.teamLogo,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'athleteId': athleteId,
    'name': name,
    'headshot': headshot,
    'teamId': teamId,
    'teamAbbreviation': teamAbbreviation,
    'teamLogo': teamLogo,
    'value': value,
  };

  factory LeaderEntry.fromJson(Map<String, dynamic> json) => LeaderEntry(
    athleteId: json['athleteId']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    headshot: json['headshot']?.toString() ?? '',
    teamId: json['teamId']?.toString() ?? '',
    teamAbbreviation: json['teamAbbreviation']?.toString() ?? '',
    teamLogo: json['teamLogo']?.toString() ?? '',
    value: json['value'] is num ? json['value'] as num : num.tryParse(json['value']?.toString() ?? '0') ?? 0,
  );
}

class LeagueLeaders {
  final List<LeaderEntry> topScorers;
  final List<LeaderEntry> topAssists;
  final List<LeaderEntry> mostYellowCards;
  final List<LeaderEntry> mostRedCards;

  const LeagueLeaders({
    this.topScorers = const [],
    this.topAssists = const [],
    this.mostYellowCards = const [],
    this.mostRedCards = const [],
  });

  bool get isEmpty =>
      topScorers.isEmpty &&
          topAssists.isEmpty &&
          mostYellowCards.isEmpty &&
          mostRedCards.isEmpty;

  static const empty = LeagueLeaders();

  Map<String, dynamic> toJson() => {
    'topScorers': topScorers.map((e) => e.toJson()).toList(),
    'topAssists': topAssists.map((e) => e.toJson()).toList(),
    'mostYellowCards': mostYellowCards.map((e) => e.toJson()).toList(),
    'mostRedCards': mostRedCards.map((e) => e.toJson()).toList(),
  };

  factory LeagueLeaders.fromJson(Map<String, dynamic> json) {
    List<LeaderEntry> parseList(dynamic raw) {
      if (raw is! List) return [];
      return raw
          .map((e) => LeaderEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return LeagueLeaders(
      topScorers: parseList(json['topScorers']),
      topAssists: parseList(json['topAssists']),
      mostYellowCards: parseList(json['mostYellowCards']),
      mostRedCards: parseList(json['mostRedCards']),
    );
  }
}