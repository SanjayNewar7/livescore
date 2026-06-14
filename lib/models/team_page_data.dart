// lib/models/team_page_data.dart
// Complete aggregated data model for TeamDetailScreen.

class TeamRecentMatch {
  final String opponentId;
  final String opponentName;
  final String opponentLogo;
  final String opponentAbbr;
  final String score;
  final String result; // 'win' | 'draw' | 'loss'
  final String date;
  final String competition;
  final String leagueFlag;
  final bool isHome;
  final int goalsFor;
  final int goalsAgainst;
  final int yellowCards;
  final int redCards;
  final double? possession;
  final double? shots;
  final double? shotsOnTarget;

  const TeamRecentMatch({
    required this.opponentId,
    required this.opponentName,
    required this.opponentLogo,
    required this.opponentAbbr,
    required this.score,
    required this.result,
    required this.date,
    required this.competition,
    required this.leagueFlag,
    required this.isHome,
    required this.goalsFor,
    required this.goalsAgainst,
    this.yellowCards = 0,
    this.redCards = 0,
    this.possession,
    this.shots,
    this.shotsOnTarget,
  });
}

class TeamUpcomingFixture {
  final String opponentId;
  final String opponentName;
  final String opponentLogo;
  final String opponentAbbr;
  final String competition;
  final String leagueFlag;
  final String date;
  final bool isHome;

  const TeamUpcomingFixture({
    required this.opponentId,
    required this.opponentName,
    required this.opponentLogo,
    required this.opponentAbbr,
    required this.competition,
    required this.leagueFlag,
    required this.date,
    required this.isHome,
  });
}

class TeamSquadPlayer {
  final String id;
  final String name;
  final String jersey;
  final String position;
  final String positionCategory;
  final String nationality;
  final int? age;
  final String headshotUrl;
  final double? rating;

  const TeamSquadPlayer({
    required this.id,
    required this.name,
    required this.jersey,
    required this.position,
    required this.positionCategory,
    required this.nationality,
    this.age,
    required this.headshotUrl,
    this.rating,
  });
}

class TeamAnalytics {
  final int last5Wins;
  final int last5Draws;
  final int last5Losses;
  final int last5GoalsFor;
  final int last5GoalsAgainst;
  final int last5YellowCards;
  final int last5RedCards;
  final double? avgPossession;
  final double? avgShotsPerGame;
  final double? avgShotsOnTarget;
  final double? shotConversionRate;
  final double attackScore;
  final double midfieldScore;
  final double defenseScore;
  final double possessionScore;
  final double disciplineScore;
  final TeamSquadPlayer? bestPlayer;
  final double? bestPlayerRating;
  final int bestPlayerGoals;
  final int bestPlayerAssists;
  final String bestPlayerPerformanceNote;

  const TeamAnalytics({
    required this.last5Wins,
    required this.last5Draws,
    required this.last5Losses,
    required this.last5GoalsFor,
    required this.last5GoalsAgainst,
    required this.last5YellowCards,
    required this.last5RedCards,
    this.avgPossession,
    this.avgShotsPerGame,
    this.avgShotsOnTarget,
    this.shotConversionRate,
    required this.attackScore,
    required this.midfieldScore,
    required this.defenseScore,
    required this.possessionScore,
    required this.disciplineScore,
    this.bestPlayer,
    this.bestPlayerRating,
    this.bestPlayerGoals = 0,
    this.bestPlayerAssists = 0,
    this.bestPlayerPerformanceNote = '',
  });

  static const empty = TeamAnalytics(
    last5Wins: 0, last5Draws: 0, last5Losses: 0,
    last5GoalsFor: 0, last5GoalsAgainst: 0,
    last5YellowCards: 0, last5RedCards: 0,
    attackScore: 50, midfieldScore: 50, defenseScore: 50,
    possessionScore: 50, disciplineScore: 50,
  );
}

class TeamStandingInfo {
  final int? rank;
  final int? points;
  final String? groupName;
  const TeamStandingInfo({this.rank, this.points, this.groupName});
}

class TeamPageData {
  final String leagueCode;
  final TeamStandingInfo standingInfo;
  final List<TeamRecentMatch> recentMatches;
  final List<TeamUpcomingFixture> upcoming;
  final List<TeamSquadPlayer> squad;
  final TeamAnalytics analytics;
  final String? headCoach;

  const TeamPageData({
    required this.leagueCode,
    required this.standingInfo,
    required this.recentMatches,
    required this.upcoming,
    required this.squad,
    required this.analytics,
    this.headCoach,
  });

  static TeamPageData empty(String leagueCode) => TeamPageData(
    leagueCode: leagueCode,
    standingInfo: const TeamStandingInfo(),
    recentMatches: const [],
    upcoming: const [],
    squad: const [],
    analytics: TeamAnalytics.empty,
  );
}