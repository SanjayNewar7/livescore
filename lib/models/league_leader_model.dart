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
}