import 'package:hive/hive.dart';

part 'user_preferences.g.dart';

@HiveType(typeId: 11)
class UserPreferences {
  @HiveField(0)
  final List<String> favoriteTeamIds;

  @HiveField(1)
  final List<String> favoriteLeagueIds;

  @HiveField(2)
  final bool hasCompletedOnboarding;

  @HiveField(3)
  final bool isDarkMode;

  @HiveField(4)
  final bool notificationsEnabled;

  @HiveField(5)
  final bool liveScoreAlerts;

  @HiveField(6)
  final bool newsAlerts;

  @HiveField(7)
  final String lastSelectedLeague;

  /// Up to 4 favorite players, each stored as {id, name, image, team}.
  /// Kept as a list of string maps (rather than a single id) so the UI can
  /// render a favorite player without a separate player-by-id lookup —
  /// mirrors how favoriteTeamIds/favoriteLeagueIds are simple, but players
  /// don't have a local team-style cache to resolve from an id alone.
  @HiveField(8)
  final List<Map<String, String>> favoritePlayers;

  UserPreferences({
    this.favoriteTeamIds = const [],
    this.favoriteLeagueIds = const [],
    this.hasCompletedOnboarding = false,
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.liveScoreAlerts = true,
    this.newsAlerts = true,
    this.lastSelectedLeague = 'eng.1',
    this.favoritePlayers = const [],
  });

  UserPreferences copyWith({
    List<String>? favoriteTeamIds,
    List<String>? favoriteLeagueIds,
    bool? hasCompletedOnboarding,
    bool? isDarkMode,
    bool? notificationsEnabled,
    bool? liveScoreAlerts,
    bool? newsAlerts,
    String? lastSelectedLeague,
    List<Map<String, String>>? favoritePlayers,
  }) {
    return UserPreferences(
      favoriteTeamIds: favoriteTeamIds ?? this.favoriteTeamIds,
      favoriteLeagueIds: favoriteLeagueIds ?? this.favoriteLeagueIds,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      liveScoreAlerts: liveScoreAlerts ?? this.liveScoreAlerts,
      newsAlerts: newsAlerts ?? this.newsAlerts,
      lastSelectedLeague: lastSelectedLeague ?? this.lastSelectedLeague,
      favoritePlayers: favoritePlayers ?? this.favoritePlayers,
    );
  }
}