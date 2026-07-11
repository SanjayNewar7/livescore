import 'package:livescore/services/api_service.dart';
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/league_leader_model.dart';
import 'package:livescore/models/news_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/team_model.dart';
import '../models/search_model.dart';
import '../models/team_page_data.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/screens/game_detail_screen.dart'
    show MatchLineup, LineupPlayer, H2HResult;

class SportService {
  final ApiService   _api   = ApiService();
  final CacheService _cache = CacheService();

  String _currentLeagueCode = 'eng.1';

  // ─── CACHE KEYS ──────────────────────────────────────────────────────────
  static const String _teamPageCacheKeyPrefix = 'team_page_';
  static const Duration _teamPageCacheDuration = Duration(hours: 6);

  void setLeague(String leagueCode) => _currentLeagueCode = leagueCode;
  String get currentLeague => _currentLeagueCode;

  Future<List<Map<String, String>>> getAllLeagues() async =>
      _api.getAllLeagues();

  // ─── NEWS WITH TWO-PHASE LOADING ─────────────────────────────────────────────────
  // Phase 1: Load first 25 articles quickly (cached)
  // Phase 2: Load remaining 25 articles in background
  Future<List<NewsArticle>> getNewsWithTwoPhase({
    String? league,
    bool forceRefresh = false,
    Function(List<NewsArticle> initialNews)? onPhase1Complete,
    Function(List<NewsArticle> allNews)? onPhase2Complete,
  }) async {
    final cacheKeyFirstBatch = 'news_${league ?? 'all'}_first25';

    // Check cache for first batch
    if (!forceRefresh) {
      try {
        final cached = await _cache.getCachedNews(category: cacheKeyFirstBatch);
        if (cached != null && cached.isNotEmpty) {
          print('[SportService] Cache hit: ${cached.length} news articles (first batch)');

          // Return cached first batch immediately
          if (onPhase1Complete != null) {
            onPhase1Complete(cached);
          }

          // Still fetch fresh data in background
          _fetchFullNewsInBackground(league, onPhase2Complete);
          return cached;
        }
      } catch (e) {
        print('[SportService] Cache read error: $e');
      }
    }

    // No cache or force refresh - fetch phase 1 then phase 2
    try {
      // PHASE 1: Load first 25 articles quickly
      print('[SportService] Phase 1: Fetching first 25 articles...');
      final firstBatch = await _api.getNewsBatch(league: league, limit: 25);
      final footballFirst = firstBatch.where(_isFootballArticle).toList();

      // Cache first batch only
      if (footballFirst.isNotEmpty) {
        await _cache.cacheNews(footballFirst, category: cacheKeyFirstBatch);
      }

      if (onPhase1Complete != null) {
        onPhase1Complete(footballFirst);
      }

      // PHASE 2: Load remaining articles in background
      _fetchFullNewsInBackground(league, onPhase2Complete);

      return footballFirst;
    } catch (e) {
      print('[SportService] Error fetching news: $e');
      try {
        final cached = await _cache.getCachedNews(category: cacheKeyFirstBatch);
        if (cached != null && cached.isNotEmpty) {
          if (onPhase1Complete != null) onPhase1Complete(cached);
          return cached;
        }
      } catch (_) {}
      return [];
    }
  }

  Future<void> _fetchFullNewsInBackground(
      String? league,
      Function(List<NewsArticle> allNews)? onPhase2Complete,
      ) async {
    try {
      print('[SportService] Phase 2: Fetching remaining articles in background...');
      final secondBatch = await _api.getNewsBatch(league: league, limit: 50);

      // Get cached first batch to combine
      final cacheKeyFirstBatch = 'news_${league ?? 'all'}_first25';
      final cachedFirst = await _cache.getCachedNews(category: cacheKeyFirstBatch);
      final existingIds = cachedFirst?.map((a) => a.id).toSet() ?? {};

      final newArticles = secondBatch
          .where((a) => _isFootballArticle(a) && !existingIds.contains(a.id))
          .toList();

      final allArticles = [...?cachedFirst, ...newArticles];
      print('[SportService] Phase 2 complete: ${allArticles.length} total articles');

      if (onPhase2Complete != null) {
        onPhase2Complete(allArticles);
      }
    } catch (e) {
      print('[SportService] Phase 2 error: $e');
    }
  }

  bool _isFootballArticle(NewsArticle a) {
    const footballKeywords = [
      'football', 'soccer', 'fifa', 'uefa', 'premier league', 'la liga',
      'serie a', 'bundesliga', 'ligue 1', 'champions league', 'europa league',
      'world cup', 'nations league', 'mls', 'liga mx', 'brasileirao',
      'eredivisie', 'primeira liga', 'goal', 'match', 'striker', 'midfielder',
      'goalkeeper', 'winger', 'defender', 'offside', 'penalty', 'hat-trick',
      'transfer', 'manager', 'coach', 'squad', 'fixture', 'standings',
    ];
    final searchText = [
      a.headline,
      a.description,
      ...a.categories,
    ].join(' ').toLowerCase();
    return footballKeywords.any((kw) => searchText.contains(kw));
  }

  Future<List<NewsArticle>> getNewsWithPagination({
    String? league,
    int page = 1,
    int pageSize = 50,
    bool forceRefresh = false,
  }) async {
    final result = await getNewsWithTwoPhase(league: league, forceRefresh: forceRefresh);
    return result;
  }

  Future<List<NewsArticle>> getNews({bool forceRefresh = false, String? league}) async {
    return await getNewsWithTwoPhase(league: league, forceRefresh: forceRefresh);
  }

  // ─── GAMES ─────────────────────────────────────────────────────────────────
  Future<List<Game>> getTodaysMatchesProgressive({
    bool forceRefresh = false,
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    const cacheKey = 'today_all';

    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached today games: ${cached.length}');
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
    }

    try {
      print('Fetching fresh today games progressively');
      final games = await _api.getAllTodaysMatchesProgressive(
        onPartialUpdate: onPartialUpdate,
      );
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games total');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<List<Game>> getGamesByDateFromAllLeaguesProgressive(
      String dateStr, {
        bool forceRefresh = false,
        Function(List<Game> partialGames)? onPartialUpdate,
      }) async {
    final cacheKey = 'custom_$dateStr';

    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached custom date games: ${cached.length}');
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
    }

    try {
      print('Fetching fresh custom date games progressively for: $dateStr');
      final games = await _api.getAllGamesByDateStringProgressive(
        dateStr,
        onPartialUpdate: onPartialUpdate,
      );
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games for custom date');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<List<Game>> getTodaysMatches({bool forceRefresh = false}) async {
    const cacheKey = 'today_all';
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached today games (ALL leagues): ${cached.length}');
        return cached;
      }
    }
    try {
      print('Fetching fresh today games from API (ALL 42 leagues)');
      final games = await _api.getAllTodaysMatches();
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games from ALL leagues');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Game>> getYesterdaysMatches({bool forceRefresh = false}) async {
    const cacheKey = 'yesterday_all';
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached yesterday games (ALL leagues): ${cached.length}');
        return cached;
      }
    }
    try {
      print('Fetching fresh yesterday games from API (ALL 42 leagues)');
      final games = await _api.getAllYesterdaysMatches();
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games from ALL leagues');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Game>> getTomorrowsMatches({bool forceRefresh = false}) async {
    const cacheKey = 'tomorrow_all';
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached tomorrow games (ALL leagues): ${cached.length}');
        return cached;
      }
    }
    try {
      print('Fetching fresh tomorrow games from API (ALL 42 leagues)');
      final games = await _api.getAllTomorrowsMatches();
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games from ALL leagues');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Game>> getGamesByDateFromAllLeagues(String dateStr,
      {bool forceRefresh = false}) async {
    final cacheKey = 'custom_$dateStr';
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached custom date games: ${cached.length}');
        return cached;
      }
    }
    try {
      print('Fetching fresh custom date games from API for date: $dateStr');
      final games = await _api.getAllGamesByDateString(dateStr);
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games for custom date');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Game>> getAllLiveMatches({bool forceRefresh = false}) async {
    const cacheKey = 'all_live';
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached live games: ${cached.length}');
        return cached;
      }
    }
    try {
      print('Fetching fresh live games from API');
      final games = await _api.getAllLiveMatches();
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} live games');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Game>> getLiveScores(
      {bool forceRefresh = false, String? date}) async {
    if (!forceRefresh) {
      final cached = await _safeGetCache(date: date, leagueCode: _currentLeagueCode);
      if (cached != null && cached.isNotEmpty) return cached;
    }
    try {
      final games = await _api.getScoreboard(
          leagueCode: _currentLeagueCode, date: date);
      await _cache.cacheGames(games, date: date, leagueCode: _currentLeagueCode);
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: date, leagueCode: _currentLeagueCode);
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<Standing>> getStandings({bool forceRefresh = false, String? season}) async {
    if (!forceRefresh) {
      try {
        final cached = await _cache.getCachedStandings(leagueCode: '${_currentLeagueCode}_${season ?? 'current'}');
        if (cached != null && cached.isNotEmpty) return cached;
      } catch (e) {
        print('Cache read error: $e');
      }
    }
    try {
      final standings = await _api.getStandings(_currentLeagueCode, season: season);
      await _cache.cacheStandings(standings, leagueCode: '${_currentLeagueCode}_${season ?? 'current'}');
      return standings;
    } catch (e) {
      try {
        final cached = await _cache.getCachedStandings(leagueCode: '${_currentLeagueCode}_${season ?? 'current'}');
        if (cached != null && cached.isNotEmpty) return cached;
      } catch (_) {}
      rethrow;
    }
  }

  Future<LeagueLeaders> getLeagueLeaders({String? season, bool forceRefresh = false}) async {
    final cacheKey = '${_currentLeagueCode}_${season ?? 'current'}';

    if (!forceRefresh) {
      final cached = await _cache.getCachedLeagueLeaders(leagueCode: cacheKey);
      if (cached != null) {
        print('[SportService] Using cached leaders for $cacheKey');
        return cached;
      }
    }

    try {
      final leaders = await _api.getLeagueLeaders(_currentLeagueCode, season: season);
      if (!leaders.isEmpty) {
        await _cache.cacheLeagueLeaders(leaders, leagueCode: cacheKey);
      }
      return leaders;
    } catch (e) {
      print('Error fetching league leaders: $e');
      // Fall back to a stale cache entry rather than nothing, if one exists.
      final stale = await _cache.getCachedLeagueLeaders(leagueCode: cacheKey);
      return stale ?? LeagueLeaders.empty;
    }
  }

  Future<GameDetail> getGameDetail(String gameId) async =>
      _api.getGameDetail(gameId);

  Future<List<Game>> getGamesWithDetails(List<Game> games) async {
    final List<Game> updated = [];
    for (final game in games) {
      try {
        final detail = await getGameDetail(game.id);
        updated.add(Game(
          id: game.id,
          status: game.status,
          shortDetail: game.shortDetail,
          awayTeam: game.awayTeam,
          homeTeam: game.homeTeam,
          awayScore: game.awayScore,
          homeScore: game.homeScore,
          awayLineScores: game.awayLineScores,
          homeLineScores: game.homeLineScores,
          venue: game.venue,
          date: game.date,
          clock: game.clock,
          period: game.period,
          leagueName: game.leagueName,
          leagueFlag: game.leagueFlag,
          goalScorers: detail.game.goalScorers,
          awayTeamFullName: detail.game.awayTeamFullName,
          homeTeamFullName: detail.game.homeTeamFullName,
        ));
      } catch (_) {
        updated.add(game);
      }
    }
    return updated;
  }

  Future<List<TeamInfo>> getAllTeams() async =>
      _api.getAllTeams(_currentLeagueCode);

  Future<List<Player>> getTeamRoster(String teamId) async =>
      _api.getTeamRoster(teamId, _currentLeagueCode);

  Future<MatchLineup?> getMatchLineup(String gameId) async =>
      _api.getMatchLineup(gameId);



  Future<List<Game>> getYesterdaysMatchesProgressive({
    bool forceRefresh = false,
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    const cacheKey = 'yesterday_all';

    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached yesterday games: ${cached.length}');
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
    }

    try {
      print('Fetching fresh yesterday games progressively');
      final games = await _api.getAllYesterdaysMatchesProgressive(
        onPartialUpdate: onPartialUpdate,
      );
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games total');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<List<Game>> getTomorrowsMatchesProgressive({
    bool forceRefresh = false,
    Function(List<Game> partialGames)? onPartialUpdate,
  }) async {
    const cacheKey = 'tomorrow_all';

    if (!forceRefresh) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        print('Returning cached tomorrow games: ${cached.length}');
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
    }

    try {
      print('Fetching fresh tomorrow games progressively');
      final games = await _api.getAllTomorrowsMatchesProgressive(
        onPartialUpdate: onPartialUpdate,
      );
      await _cache.cacheGames(games, date: cacheKey, leagueCode: 'all');
      print('Fetched ${games.length} games total');
      return games;
    } catch (e) {
      final cached = await _safeGetCache(date: cacheKey, leagueCode: 'all');
      if (cached != null && cached.isNotEmpty) {
        if (onPartialUpdate != null) onPartialUpdate(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<void> clearTodayCache() async {
    await _cache.clearAllCache();
    print('Cache cleared for all data');
  }

  Future<List<Game>?> _safeGetCache({String? date, String? leagueCode}) async {
    try {
      return await _cache.getCachedGames(date: date, leagueCode: leagueCode);
    } catch (e) {
      print('Cache read error: $e');
      return null;
    }
  }

  // ─── TEAM PAGE DATA WITH 6-HOUR CACHING ────────────────────────────────────
  Future<TeamPageData> getTeamPageData(
      String teamId, {
        String? leagueCode,
        bool forceRefresh = false,
      }) async {
    final resolvedLeague = leagueCode ?? _currentLeagueCode;
    final cacheKey = '${_teamPageCacheKeyPrefix}${teamId}_${resolvedLeague}';

    // Check cache first (6 hours)
    if (!forceRefresh) {
      try {
        final cached = await _cache.getCachedTeamPageData(cacheKey);
        if (cached != null) {
          print('[SportService] ✅ Team page cache HIT for $teamId');
          return cached;
        }
      } catch (e) {
        print('[SportService] Team page cache read error: $e');
      }
    }

    try {
      print('[SportService] Fetching fresh team page data for $teamId');
      final data = await _api.getTeamPageData(teamId, leagueCode: resolvedLeague);

      // Cache the data for 6 hours
      await _cache.cacheTeamPageData(cacheKey, data);
      print('[SportService] ✅ Team page data cached for $teamId (6 hours)');

      return data;
    } catch (e) {
      print('[SportService] getTeamPageData error: $e');
      // Try to return stale cache if available
      try {
        final cached = await _cache.getCachedTeamPageData(cacheKey);
        if (cached != null) {
          print('[SportService] ⚠️ Returning stale cache for $teamId');
          return cached;
        }
      } catch (_) {}
      return TeamPageData.empty(resolvedLeague);
    }
  }

  /// Returns true when the given league code represents national teams
  /// (World Cup, qualifiers, nations league, etc.).
  bool isNationalTeamLeague(String leagueCode) =>
      AppConstants.isNationalTeamLeague(leagueCode);

  Future<SearchResponse> search(String query) async {
    return _api.search(query);
  }

  Future<List<Game>> getTodaysMatchesSilent() async {
    try {
      return await _api.getAllTodaysMatches();
    } catch (e) {
      print('[SportService] silentRefresh error: $e');
      return [];
    }
  }
}