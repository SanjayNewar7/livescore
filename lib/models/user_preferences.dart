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

  UserPreferences({
    this.favoriteTeamIds = const [],
    this.favoriteLeagueIds = const [],
    this.hasCompletedOnboarding = false,
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.liveScoreAlerts = true,
    this.newsAlerts = true,
    this.lastSelectedLeague = 'eng.1',
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
    );
  }
}