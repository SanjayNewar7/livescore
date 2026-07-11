import 'package:hive_flutter/hive_flutter.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/league_leader_model.dart';
import 'package:livescore/models/team_page_data.dart';
import 'package:livescore/models/search_model.dart';

class CacheService {
  static const String _gamesBox      = 'cached_games';
  static const String _standingsBox  = 'cached_standings';
  static const String _newsBox       = 'cached_news';
  static const String _playersBox    = 'cached_players';
  static const String _leadersBox    = 'cached_leaders';
  static const String _headshotsBox  = 'cached_headshots';
  static const String _teamPageBox   = 'cached_team_pages';
  static const String _searchTeamsBox = 'search_teams';
  static const String _searchPlayersBox = 'search_players';

  static const Duration cacheDuration = Duration(minutes: 5);

  /// League stat leaders (top scorers/assists/cards) come from a
  /// rate-limited free API (100 requests/day). They also change slowly —
  /// a handful of goals across an entire league per day — so we cache them
  /// far longer than scores/standings to stay well within quota even with
  /// many users/screens hitting the Standings tab throughout the day.
  static const Duration leadersCacheDuration = Duration(hours: 3);

  /// Squad player headshots are fetched once per team per 7 days.
  ///
  /// Rationale: player photos change rarely (new signing or hair cut).
  /// A 7-day window dramatically cuts ESPN CDN / athlete-endpoint calls
  /// while still refreshing automatically on a weekly cycle. Individual
  /// player IDs that were previously missing a URL are also persisted,
  /// so the enrichment pass is only triggered for genuinely new players.
  static const Duration headshotsCacheDuration = Duration(days: 7);

  /// Team page data (matches, fixtures, squad, analytics) is cached for 6 hours.
  /// This data changes slowly (match results, upcoming fixtures) and doesn't
  /// need to be refreshed more frequently than every 6 hours.
  static const Duration teamPageCacheDuration = Duration(hours: 6);

  /// Search results (teams and players) are cached for 24 hours.
  /// Teams and players change very slowly (transfers, new signings, etc.)
  /// so a 24-hour cache is safe and significantly improves performance.
  static const Duration searchCacheDuration = Duration(hours: 24);

  /// Maximum number of news articles kept in any single cache slot.
  /// Set to 25 — enough for one full page (20) plus a small buffer.
  static const int _maxCachedNewsArticles = 25;

  late Box _gamesBoxRef;
  late Box _standingsBoxRef;
  late Box _newsBoxRef;
  late Box _playersBoxRef;
  late Box _leadersBoxRef;
  late Box _headshotsBoxRef;
  late Box _teamPageBoxRef;
  late Box _searchTeamsBoxRef;
  late Box _searchPlayersBoxRef;

  bool _isInitialized = false;

  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    _gamesBoxRef      = await Hive.openBox(_gamesBox);
    _standingsBoxRef  = await Hive.openBox(_standingsBox);
    _newsBoxRef       = await Hive.openBox(_newsBox);
    _playersBoxRef    = await Hive.openBox(_playersBox);
    _leadersBoxRef    = await Hive.openBox(_leadersBox);
    _headshotsBoxRef  = await Hive.openBox(_headshotsBox);
    _teamPageBoxRef   = await Hive.openBox(_teamPageBox);
    _searchTeamsBoxRef = await Hive.openBox(_searchTeamsBox);
    _searchPlayersBoxRef = await Hive.openBox(_searchPlayersBox);

    _isInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await init();
  }

  // ── Deep-cast helpers (Hive returns _Map<dynamic,dynamic>) ──────────────────
  static Map<String, dynamic> _castMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return (raw as Map).map((k, v) {
      if (v is Map) return MapEntry(k.toString(), _castMap(v));
      if (v is List) return MapEntry(k.toString(), _castList(v));
      return MapEntry(k.toString(), v);
    });
  }

  static List<dynamic> _castList(dynamic raw) {
    if (raw is! List) return [];
    return (raw as List).map((item) {
      if (item is Map) return _castMap(item);
      if (item is List) return _castList(item);
      return item;
    }).toList();
  }

  // ── Games ────────────────────────────────────────────────────────────────────
  Future<void> cacheGames(List<Game> games,
      {String? date, String? leagueCode}) async {
    await _ensureInitialized();
    final key = '${leagueCode ?? 'all'}_${date ?? 'today'}';
    await _gamesBoxRef.put(key, {
      'data': games.map((g) => g.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Game>?> getCachedGames(
      {String? date, String? leagueCode}) async {
    await _ensureInitialized();
    final key = '${leagueCode ?? 'all'}_${date ?? 'today'}';
    final raw = _gamesBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final gamesData = _castList(cached['data']);
      return gamesData.map((g) => Game.fromJson(_castMap(g))).toList();
    } catch (e) {
      print('Cache read error (games): $e');
      return null;
    }
  }

  // ── Standings ─────────────────────────────────────────────────────────────────
  Future<void> cacheStandings(List<Standing> standings,
      {String? leagueCode}) async {
    await _ensureInitialized();
    final key = 'standings_${leagueCode ?? 'all'}';
    await _standingsBoxRef.put(key, {
      'data': standings.map((s) => s.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Standing>?> getCachedStandings({String? leagueCode}) async {
    await _ensureInitialized();
    final key = 'standings_${leagueCode ?? 'all'}';
    final raw = _standingsBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final standingsData = _castList(cached['data']);
      return standingsData.map((s) => Standing.fromJson(_castMap(s))).toList();
    } catch (e) {
      print('Cache read error (standings): $e');
      return null;
    }
  }

  // ── News — capped at [_maxCachedNewsArticles] per category key ───────────────
  //
  // Strategy:
  //   • Always store the LATEST [_maxCachedNewsArticles] articles.
  //   • On write, if more articles are provided the list is trimmed to the
  //     first [_maxCachedNewsArticles] (ESPN returns newest-first).
  //   • Old cached articles beyond that limit are automatically discarded.
  //
  Future<void> cacheNews(List<NewsArticle> news, {String? category}) async {
    await _ensureInitialized();
    final key = category ?? 'all';

    // Cap to newest [_maxCachedNewsArticles] articles
    final trimmed = news.length > _maxCachedNewsArticles
        ? news.sublist(0, _maxCachedNewsArticles)
        : news;

    await _newsBoxRef.put(key, {
      'data': trimmed.map((n) => n.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    print('[CacheService] Cached ${trimmed.length} news articles for key "$key"'
        ' (limit=$_maxCachedNewsArticles)');
  }

  Future<List<NewsArticle>?> getCachedNews({String? category}) async {
    await _ensureInitialized();
    final key = category ?? 'all';
    final raw = _newsBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          cacheDuration.inMilliseconds) return null;
      final newsData = _castList(cached['data']);
      // Only return up to the cap (guards against stale data from before this version)
      final articles  = newsData.map((n) => NewsArticle.fromJson(_castMap(n))).toList();
      return articles.length > _maxCachedNewsArticles
          ? articles.sublist(0, _maxCachedNewsArticles)
          : articles;
    } catch (e) {
      print('Cache read error (news): $e');
      return null;
    }
  }

  /// Clears every news entry in the cache box (all categories).
  Future<void> clearNewsCache() async {
    await _ensureInitialized();
    await _newsBoxRef.clear();
    print('[CacheService] News cache cleared.');
  }

  // ── League Stat Leaders ──────────────────────────────────────────────────────
  //
  // Cached for [leadersCacheDuration] (3 hours) — far longer than games/
  // standings — because this data comes from a rate-limited free API
  // (100 requests/day). A long cache window means many users opening the
  // Standings screen throughout the day share the same small handful of
  // daily API calls instead of each one spending its own quota.
  Future<void> cacheLeagueLeaders(LeagueLeaders leaders, {required String leagueCode}) async {
    await _ensureInitialized();
    await _leadersBoxRef.put(leagueCode, {
      'data': leaders.toJson(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<LeagueLeaders?> getCachedLeagueLeaders({required String leagueCode}) async {
    await _ensureInitialized();
    final raw = _leadersBoxRef.get(leagueCode);
    if (raw == null) return null;

    try {
      final cached    = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          leadersCacheDuration.inMilliseconds) return null;
      return LeagueLeaders.fromJson(_castMap(cached['data']));
    } catch (e) {
      print('Cache read error (leaders): $e');
      return null;
    }
  }

  // ── Squad Player Headshots ───────────────────────────────────────────────────
  //
  // Stores a Map<playerId, headshotUrl> per team, cached for 7 days.
  //
  // Strategy:
  //   • Key = 'headshots_$teamId' (one entry per team).
  //   • On write the FULL id→url map is persisted, including players whose URL
  //     is currently empty — that lets the enrichment pass skip re-fetching
  //     players that are genuinely missing a photo.
  //   • On read, only the id→url map is returned (caller decides what to do
  //     with empty strings).
  //   • 7-day TTL means the full enrichment pass runs at most once a week per
  //     team, keeping ESPN CDN / athlete-endpoint calls to a minimum.
  //
  Future<void> cacheSquadHeadshots(
      String teamId, Map<String, String> headshotMap) async {
    await _ensureInitialized();
    final key = 'headshots_$teamId';
    await _headshotsBoxRef.put(key, {
      'data': headshotMap,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    final hits = headshotMap.values.where((v) => v.isNotEmpty).length;
    print('[CacheService] Cached ${headshotMap.length} headshot entries '
        '($hits with URL) for team "$teamId"');
  }

  /// Returns the cached headshot map for [teamId] if it exists and is
  /// within [headshotsCacheDuration] (7 days).  Returns null on miss/expired.
  Future<Map<String, String>?> getCachedSquadHeadshots(String teamId) async {
    await _ensureInitialized();
    final key = 'headshots_$teamId';
    final raw = _headshotsBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          headshotsCacheDuration.inMilliseconds) {
        print('[CacheService] Headshot cache EXPIRED for team "$teamId"');
        return null;
      }
      // The stored data is a Map<String, String> serialised by Hive.
      final rawData = cached['data'];
      if (rawData is! Map) return null;
      final result = <String, String>{};
      rawData.forEach((k, v) {
        result[k.toString()] = v?.toString() ?? '';
      });
      final hits = result.values.where((v) => v.isNotEmpty).length;
      print('[CacheService] Headshot cache HIT for team "$teamId": '
          '${result.length} entries, $hits with URL');
      return result;
    } catch (e) {
      print('Cache read error (headshots): $e');
      return null;
    }
  }

  /// Clears headshot cache for a specific team (e.g. after a major squad change).
  Future<void> clearTeamHeadshotCache(String teamId) async {
    await _ensureInitialized();
    await _headshotsBoxRef.delete('headshots_$teamId');
    print('[CacheService] Headshot cache cleared for team "$teamId"');
  }

  // ── Team Page Data Cache (6 hours) ─────────────────────────────────────────
  //
  // Stores complete TeamPageData for a team, cached for 6 hours.
  // This includes recent matches, upcoming fixtures, squad, and analytics.
  // The data changes slowly (match results, upcoming fixtures) so 6 hours
  // is a reasonable balance between freshness and performance.
  //
  Future<void> cacheTeamPageData(String key, TeamPageData data) async {
    await _ensureInitialized();

    // Convert TeamPageData to a serializable map
    final serialized = {
      'leagueCode': data.leagueCode,
      'standingInfo': {
        'rank': data.standingInfo.rank,
        'points': data.standingInfo.points,
        'groupName': data.standingInfo.groupName,
      },
      'recentMatches': data.recentMatches.map((m) => {
        'opponentId': m.opponentId,
        'opponentName': m.opponentName,
        'opponentLogo': m.opponentLogo,
        'opponentAbbr': m.opponentAbbr,
        'score': m.score,
        'result': m.result,
        'date': m.date,
        'competition': m.competition,
        'leagueFlag': m.leagueFlag,
        'isHome': m.isHome,
        'goalsFor': m.goalsFor,
        'goalsAgainst': m.goalsAgainst,
        'yellowCards': m.yellowCards,
        'redCards': m.redCards,
        'possession': m.possession,
        'shots': m.shots,
        'shotsOnTarget': m.shotsOnTarget,
      }).toList(),
      'upcoming': data.upcoming.map((f) => {
        'opponentId': f.opponentId,
        'opponentName': f.opponentName,
        'opponentLogo': f.opponentLogo,
        'opponentAbbr': f.opponentAbbr,
        'competition': f.competition,
        'leagueFlag': f.leagueFlag,
        'date': f.date,
        'isHome': f.isHome,
      }).toList(),
      'squad': data.squad.map((p) => {
        'id': p.id,
        'name': p.name,
        'jersey': p.jersey,
        'position': p.position,
        'positionCategory': p.positionCategory,
        'nationality': p.nationality,
        'age': p.age,
        'headshotUrl': p.headshotUrl,
        'rating': p.rating,
      }).toList(),
      'analytics': {
        'last5Wins': data.analytics.last5Wins,
        'last5Draws': data.analytics.last5Draws,
        'last5Losses': data.analytics.last5Losses,
        'last5GoalsFor': data.analytics.last5GoalsFor,
        'last5GoalsAgainst': data.analytics.last5GoalsAgainst,
        'last5YellowCards': data.analytics.last5YellowCards,
        'last5RedCards': data.analytics.last5RedCards,
        'avgPossession': data.analytics.avgPossession,
        'avgShotsPerGame': data.analytics.avgShotsPerGame,
        'avgShotsOnTarget': data.analytics.avgShotsOnTarget,
        'shotConversionRate': data.analytics.shotConversionRate,
        'attackScore': data.analytics.attackScore,
        'midfieldScore': data.analytics.midfieldScore,
        'defenseScore': data.analytics.defenseScore,
        'possessionScore': data.analytics.possessionScore,
        'disciplineScore': data.analytics.disciplineScore,
        'bestPlayerId': data.analytics.bestPlayer?.id,
        'bestPlayerRating': data.analytics.bestPlayerRating,
        'bestPlayerGoals': data.analytics.bestPlayerGoals,
        'bestPlayerAssists': data.analytics.bestPlayerAssists,
        'bestPlayerPerformanceNote': data.analytics.bestPlayerPerformanceNote,
      },
      'headCoach': data.headCoach,
    };

    await _teamPageBoxRef.put(key, {
      'data': serialized,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    print('[CacheService] Cached team page data for key: $key '
        '(${data.recentMatches.length} recent, ${data.upcoming.length} upcoming, ${data.squad.length} squad)');
  }

  /// Retrieves cached TeamPageData for a team if it exists and is within
  /// [teamPageCacheDuration] (6 hours). Returns null on miss/expired.
  Future<TeamPageData?> getCachedTeamPageData(String key) async {
    await _ensureInitialized();
    final raw = _teamPageBoxRef.get(key);
    if (raw == null) return null;

    try {
      final cached = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          teamPageCacheDuration.inMilliseconds) {
        print('[CacheService] Team page cache EXPIRED for key: $key');
        return null;
      }

      final data = cached['data'] as Map<String, dynamic>;

      // ── Reconstruct TeamPageData from cached JSON ──────────────────────

      // Recent matches
      final recentMatches = (data['recentMatches'] as List).map((m) => TeamRecentMatch(
        opponentId: m['opponentId']?.toString() ?? '',
        opponentName: m['opponentName']?.toString() ?? '',
        opponentLogo: m['opponentLogo']?.toString() ?? '',
        opponentAbbr: m['opponentAbbr']?.toString() ?? '',
        score: m['score']?.toString() ?? '',
        result: m['result']?.toString() ?? '',
        date: m['date']?.toString() ?? '',
        competition: m['competition']?.toString() ?? '',
        leagueFlag: m['leagueFlag']?.toString() ?? '',
        isHome: m['isHome'] ?? false,
        goalsFor: m['goalsFor'] ?? 0,
        goalsAgainst: m['goalsAgainst'] ?? 0,
        yellowCards: m['yellowCards'] ?? 0,
        redCards: m['redCards'] ?? 0,
        possession: m['possession']?.toDouble(),
        shots: m['shots']?.toDouble(),
        shotsOnTarget: m['shotsOnTarget']?.toDouble(),
      )).toList();

      // Upcoming fixtures
      final upcoming = (data['upcoming'] as List).map((f) => TeamUpcomingFixture(
        opponentId: f['opponentId']?.toString() ?? '',
        opponentName: f['opponentName']?.toString() ?? '',
        opponentLogo: f['opponentLogo']?.toString() ?? '',
        opponentAbbr: f['opponentAbbr']?.toString() ?? '',
        competition: f['competition']?.toString() ?? '',
        leagueFlag: f['leagueFlag']?.toString() ?? '',
        date: f['date']?.toString() ?? '',
        isHome: f['isHome'] ?? false,
      )).toList();

      // Squad
      final squad = (data['squad'] as List).map((p) => TeamSquadPlayer(
        id: p['id']?.toString() ?? '',
        name: p['name']?.toString() ?? '',
        jersey: p['jersey']?.toString() ?? '',
        position: p['position']?.toString() ?? '',
        positionCategory: p['positionCategory']?.toString() ?? '',
        nationality: p['nationality']?.toString() ?? '',
        age: p['age'],
        headshotUrl: p['headshotUrl']?.toString() ?? '',
        rating: p['rating']?.toDouble(),
      )).toList();

      // Analytics
      final analyticsJson = data['analytics'] as Map<String, dynamic>;

      // Find best player from squad - using a safe approach
      TeamSquadPlayer? bestPlayer;
      final bestPlayerId = analyticsJson['bestPlayerId'] as String?;
      if (bestPlayerId != null && bestPlayerId.isNotEmpty) {
        try {
          bestPlayer = squad.firstWhere(
                (p) => p.id == bestPlayerId,
          );
        } catch (e) {
          // Player not found in squad, leave as null
          bestPlayer = null;
        }
      }

      // If best player wasn't found but there's a rating, try to find by rating
      if (bestPlayer == null && squad.isNotEmpty) {
        final bestRating = analyticsJson['bestPlayerRating']?.toDouble();
        if (bestRating != null) {
          try {
            bestPlayer = squad.firstWhere(
                  (p) => p.rating == bestRating,
            );
          } catch (e) {
            // No player with that rating, leave as null
          }
        }
      }

      final analytics = TeamAnalytics(
        last5Wins: analyticsJson['last5Wins'] ?? 0,
        last5Draws: analyticsJson['last5Draws'] ?? 0,
        last5Losses: analyticsJson['last5Losses'] ?? 0,
        last5GoalsFor: analyticsJson['last5GoalsFor'] ?? 0,
        last5GoalsAgainst: analyticsJson['last5GoalsAgainst'] ?? 0,
        last5YellowCards: analyticsJson['last5YellowCards'] ?? 0,
        last5RedCards: analyticsJson['last5RedCards'] ?? 0,
        avgPossession: analyticsJson['avgPossession']?.toDouble(),
        avgShotsPerGame: analyticsJson['avgShotsPerGame']?.toDouble(),
        avgShotsOnTarget: analyticsJson['avgShotsOnTarget']?.toDouble(),
        shotConversionRate: analyticsJson['shotConversionRate']?.toDouble(),
        attackScore: (analyticsJson['attackScore'] ?? 50).toDouble(),
        midfieldScore: (analyticsJson['midfieldScore'] ?? 50).toDouble(),
        defenseScore: (analyticsJson['defenseScore'] ?? 50).toDouble(),
        possessionScore: (analyticsJson['possessionScore'] ?? 50).toDouble(),
        disciplineScore: (analyticsJson['disciplineScore'] ?? 50).toDouble(),
        bestPlayer: bestPlayer,
        bestPlayerRating: analyticsJson['bestPlayerRating']?.toDouble(),
        bestPlayerGoals: analyticsJson['bestPlayerGoals'] ?? 0,
        bestPlayerAssists: analyticsJson['bestPlayerAssists'] ?? 0,
        bestPlayerPerformanceNote: analyticsJson['bestPlayerPerformanceNote']?.toString() ?? '',
      );

      // Standing info
      final standingInfoJson = data['standingInfo'] as Map<String, dynamic>;
      final standingInfo = TeamStandingInfo(
        rank: standingInfoJson['rank'],
        points: standingInfoJson['points'],
        groupName: standingInfoJson['groupName']?.toString(),
      );

      final result = TeamPageData(
        leagueCode: data['leagueCode']?.toString() ?? 'eng.1',
        standingInfo: standingInfo,
        recentMatches: recentMatches,
        upcoming: upcoming,
        squad: squad,
        analytics: analytics,
        headCoach: data['headCoach']?.toString(),
      );

      print('[CacheService] Team page cache HIT for key: $key '
          '(${result.recentMatches.length} recent, ${result.upcoming.length} upcoming)');
      return result;
    } catch (e) {
      print('[CacheService] Team page cache parse error: $e');
      return null;
    }
  }

  /// Clears cached team page data for a specific team.
  Future<void> clearTeamPageCache(String key) async {
    await _ensureInitialized();
    await _teamPageBoxRef.delete(key);
    print('[CacheService] Team page cache cleared for key: $key');
  }

  // ─── Search Cache (24 hours) ─────────────────────────────────────────────────
  //
  // Teams and players change very slowly (transfers, new signings, etc.)
  // so a 24-hour cache is safe and significantly improves search performance.
  // The first search may be slow, but subsequent searches will be instant.
  //
  Future<void> cacheSearchTeams(List<SearchResult> teams) async {
    await _ensureInitialized();
    await _searchTeamsBoxRef.put('data', {
      'data': teams.map((t) => t.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('[CacheService] Cached ${teams.length} search teams for 24 hours');
  }

  Future<List<SearchResult>?> getCachedSearchTeams() async {
    await _ensureInitialized();
    final raw = _searchTeamsBoxRef.get('data');
    if (raw == null) return null;

    try {
      final cached = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          searchCacheDuration.inMilliseconds) {
        print('[CacheService] Search teams cache EXPIRED');
        return null;
      }
      final data = _castList(cached['data']);
      final results = data.map((t) => SearchResult.fromJson(_castMap(t))).toList();
      print('[CacheService] Search teams cache HIT: ${results.length} teams');
      return results;
    } catch (e) {
      print('[CacheService] Search teams cache read error: $e');
      return null;
    }
  }

  Future<void> cacheSearchPlayers(List<SearchResult> players) async {
    await _ensureInitialized();
    await _searchPlayersBoxRef.put('data', {
      'data': players.map((p) => p.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('[CacheService] Cached ${players.length} search players for 24 hours');
  }

  Future<List<SearchResult>?> getCachedSearchPlayers() async {
    await _ensureInitialized();
    final raw = _searchPlayersBoxRef.get('data');
    if (raw == null) return null;

    try {
      final cached = _castMap(raw);
      final timestamp = cached['timestamp'] as int;
      if (DateTime.now().millisecondsSinceEpoch - timestamp >
          searchCacheDuration.inMilliseconds) {
        print('[CacheService] Search players cache EXPIRED');
        return null;
      }
      final data = _castList(cached['data']);
      final results = data.map((p) => SearchResult.fromJson(_castMap(p))).toList();
      print('[CacheService] Search players cache HIT: ${results.length} players');
      return results;
    } catch (e) {
      print('[CacheService] Search players cache read error: $e');
      return null;
    }
  }

  /// Clears search cache (teams and players).
  Future<void> clearSearchCache() async {
    await _ensureInitialized();
    await _searchTeamsBoxRef.clear();
    await _searchPlayersBoxRef.clear();
    print('[CacheService] Search cache cleared.');
  }

  // ── Full wipe ─────────────────────────────────────────────────────────────────
  Future<void> clearAllCache() async {
    await _ensureInitialized();
    await _gamesBoxRef.clear();
    await _standingsBoxRef.clear();
    await _newsBoxRef.clear();
    await _playersBoxRef.clear();
    await _leadersBoxRef.clear();
    await _headshotsBoxRef.clear();
    await _teamPageBoxRef.clear();
    await _searchTeamsBoxRef.clear();
    await _searchPlayersBoxRef.clear();
    print('[CacheService] All cache cleared.');
  }

  /// Clears specific cache by name
  Future<void> clearCache(String boxName) async {
    await _ensureInitialized();
    switch (boxName) {
      case _gamesBox:
        await _gamesBoxRef.clear();
        break;
      case _standingsBox:
        await _standingsBoxRef.clear();
        break;
      case _newsBox:
        await _newsBoxRef.clear();
        break;
      case _playersBox:
        await _playersBoxRef.clear();
        break;
      case _leadersBox:
        await _leadersBoxRef.clear();
        break;
      case _headshotsBox:
        await _headshotsBoxRef.clear();
        break;
      case _teamPageBox:
        await _teamPageBoxRef.clear();
        break;
      case _searchTeamsBox:
        await _searchTeamsBoxRef.clear();
        break;
      case _searchPlayersBox:
        await _searchPlayersBoxRef.clear();
        break;
      default:
        print('[CacheService] Unknown cache box: $boxName');
    }
    print('[CacheService] Cache cleared: $boxName');
  }
}