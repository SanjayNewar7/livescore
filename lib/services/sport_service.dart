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
import 'package:livescore/utils/predefined_data.dart';
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
  Future<List<NewsArticle>> getNewsWithTwoPhase({
    String? league,
    bool forceRefresh = false,
    Function(List<NewsArticle> initialNews)? onPhase1Complete,
    Function(List<NewsArticle> allNews)? onPhase2Complete,
  }) async {
    final cacheKeyFirstBatch = 'news_${league ?? 'all'}_first25';

    if (!forceRefresh) {
      try {
        final cached = await _cache.getCachedNews(category: cacheKeyFirstBatch);
        if (cached != null && cached.isNotEmpty) {
          print('[SportService] Cache hit: ${cached.length} news articles (first batch)');

          if (onPhase1Complete != null) {
            onPhase1Complete(cached);
          }

          _fetchFullNewsInBackground(league, onPhase2Complete);
          return cached;
        }
      } catch (e) {
        print('[SportService] Cache read error: $e');
      }
    }

    try {
      print('[SportService] Phase 1: Fetching first 25 articles...');
      final firstBatch = await _api.getNewsBatch(league: league, limit: 25);
      final footballFirst = firstBatch.where(_isFootballArticle).toList();

      if (footballFirst.isNotEmpty) {
        await _cache.cacheNews(footballFirst, category: cacheKeyFirstBatch);
      }

      if (onPhase1Complete != null) {
        onPhase1Complete(footballFirst);
      }

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

  // ─── PLAYER DETAILS ──────────────────────────────────────────────────────

  /// Get detailed player information from ESPN API
  Future<Player> getPlayerDetails(String playerId, {String? leagueCode}) async {
    final league = leagueCode ?? _currentLeagueCode;
    return await _api.getPlayerDetails(playerId, leagueCode: league);
  }

  /// Hybrid player details: ESPN primary, TheSportsDB as fallback/enrichment
// ─── PLAYER DETAILS ──────────────────────────────────────────────────────

  /// Hybrid player details: ESPN primary, TheSportsDB as fallback/enrichment
  Future<Player> getPlayerDetailsHybrid(String playerId, {String? leagueCode}) async {
    final league = leagueCode ?? _currentLeagueCode;
    print('[SportService] 🔍 Hybrid fetch for player: $playerId');

    // ─── STEP 1: Try ESPN API (primary source) ──────────────────────────────
    Player? espnPlayer;
    String? playerName;

    try {
      espnPlayer = await _api.getPlayerDetails(playerId, leagueCode: league);
      if (espnPlayer.id.isNotEmpty && espnPlayer.displayName.isNotEmpty) {
        playerName = espnPlayer.displayName;
        print('[SportService] ✅ ESPN data loaded for: ${espnPlayer.displayName}');
        print('[SportService]    Headshot: ${espnPlayer.headshot}');
        print('[SportService]    Nationality: ${espnPlayer.nationality}');
        print('[SportService]    BirthDate: ${espnPlayer.birthDate}');
        print('[SportService]    Stats: ${espnPlayer.statistics}');
        print('[SportService]    SeasonStats: ${espnPlayer.seasonStats}');
      }
    } catch (e) {
      print('[SportService] ⚠️ ESPN fetch failed: $e');
    }

    // ✅ FIX: `playerId` is not always a real ESPN id. The predefined seed
    // dataset (predefined_data.dart) uses synthetic ids like 'fp_vitinha'
    // for the ~90 famous players we don't have a verified ESPN id for —
    // by design, ESPN's lookup can NEVER succeed for those, so `playerName`
    // stays null and STEP 2 below used to be skipped entirely, meaning
    // SportsDB was never even searched by name for these players. If this
    // id matches one of our seed players, use ITS known name so SportsDB
    // enrichment (headshot, bio) can still run even though ESPN has
    // nothing for this id.
    Map<String, dynamic>? famousSeed;
    if (playerName == null || playerName.isEmpty) {
      famousSeed = findFamousPlayerById(playerId);
      if (famousSeed != null) {
        playerName = famousSeed['name'] as String?;
        print('[SportService] ℹ️ No ESPN match for $playerId — using seed '
            'name "$playerName" so SportsDB can still be searched');
      }
    }

    // ─── STEP 2 + STEP 3.5: TheSportsDB enrichment and API-Football season
    // stats, fetched in parallel ─────────────────────────────────────────────
    // Both are independent lookups keyed off the player's name (and
    // team/league for the stats call) already resolved in STEP 1 above —
    // neither needs the other's result, so firing them one after another (as
    // this used to) just adds a second full network round-trip on top of the
    // first for no reason. This hybrid fetch used to be 3 sequential
    // round-trips (ESPN, then SportsDB, then API-Football); it's 2 now.
    //
    // ✅ FIX: the base `merged` object used to require `espnPlayer.id
    // .isNotEmpty`, which is never true for our synthetic 'fp_*' seed ids —
    // meaning every one of the ~90 predefined-only players (everything past
    // the original top 10, which happen to have real ESPN ids) skipped the
    // whole merge block below, including STEP 3.6's predefined-stats
    // fallback, and fell through to the "no data found" sentinel in STEP 5
    // instead. Now a known seed player (`famousSeed`, resolved above) also
    // builds a `merged` object, seeded from predefined_data.dart's bio
    // fields instead of ESPN.
    final hasEspnPlayer = espnPlayer != null && espnPlayer.id.isNotEmpty;
    Player? merged = hasEspnPlayer
        ? espnPlayer!
        : (famousSeed != null
        ? Player(
      id: playerId,
      fullName: famousSeed['name'] as String? ?? '',
      displayName: famousSeed['name'] as String? ?? '',
      headshot: (famousSeed['imageUrl'] as String?) ?? '',
      jersey: (famousSeed['jersey'] as String?) ?? '',
      position: (famousSeed['position'] as String?) ?? '',
      teamId: (famousSeed['teamId'] as String?) ?? '',
      teamName: (famousSeed['teamName'] as String?) ?? '',
      height: 0,
      weight: 0,
      age: 0,
      college: '',
      statistics: const {},
      nationality: famousSeed['nationality'] as String?,
    )
        : null);

    // Declared at this outer scope (not inside the `if (merged != null)`
    // block below) because STEP 4 further down still reads it as a
    // last-resort fallback for the case where neither ESPN nor the
    // predefined seed matched at all.
    Player? sportsDbPlayer;

    final mergedBase = merged;
    if (mergedBase != null) {
      // Shadows the outer nullable `merged` with a non-null local of the
      // same name. Dart can't retain a plain `if (merged != null)`
      // null-check promotion across this block, because `merged` gets
      // captured by local closures further down (isMeaninglessCareerStats,
      // liveStatsImplausiblyLow, the roster-fallback `orElse` lambda) —
      // once that happens the analyzer treats every later use as nullable
      // again. A separate non-null local sidesteps that entirely.
      var merged = mergedBase;
      Map<String, dynamic>? sportsDbData;
      Map<String, dynamic>? afStats;

      final wantsSportsDb = playerName != null && playerName.isNotEmpty;
      final wantsAfStats = merged.displayName.isNotEmpty;

      if (wantsSportsDb || wantsAfStats) {
        final results = await Future.wait<Map<String, dynamic>?>([
          wantsSportsDb
              ? _api.searchSportsDbPlayer(playerName!).catchError((e) {
            print('[SportService] ⚠️ TheSportsDB fetch failed: $e');
            return null;
          })
              : Future.value(null),
          wantsAfStats
              ? _api.getPlayerSeasonStatsApiFootball(
            playerName: merged.displayName,
            leagueCode: league,
            teamName: merged.teamName,
          ).catchError((e) {
            print('[SportService] ⚠️ API-Football season stats fetch failed: $e');
            return null;
          })
              : Future.value(null),
        ]);
        sportsDbData = results[0];
        afStats = results[1];
      } else {
        print('[SportService] ⚠️ Cannot search SportsDB without player name');
      }

      if (sportsDbData != null) {
        print('[SportService] ✅ TheSportsDB data loaded for: $playerName');
        sportsDbPlayer = _parseSportsDbPlayer(sportsDbData);
        print('[SportService]    SportsDB Headshot: ${sportsDbPlayer?.headshot}');
        print('[SportService]    SportsDB Stats: ${sportsDbPlayer?.statistics}');
        print('[SportService]    SportsDB Nationality: ${sportsDbPlayer?.nationality}');
        print('[SportService]    SportsDB Foot: ${sportsDbPlayer?.foot}');
        print('[SportService]    SportsDB Market Value: ${sportsDbPlayer?.marketValue}');
      }

      // ─── STEP 3: Merge data (ESPN primary, SportsDB for missing fields) ────
      // Merge SportsDB data where ESPN is missing or incomplete
      if (sportsDbPlayer != null) {
        // Headshot - prefer SportsDB cutout (transparent PNG)
        if ((merged.headshot.isEmpty || merged.headshot.contains('combiner')) &&
            sportsDbPlayer.headshot.isNotEmpty) {
          merged = merged.copyWith(headshot: sportsDbPlayer.headshot);
          print('[SportService] ✅ Added SportsDB headshot');
        }

        // Statistics - merge if ESPN stats are empty
        if (merged.statistics.isEmpty && sportsDbPlayer.statistics.isNotEmpty) {
          merged = merged.copyWith(statistics: sportsDbPlayer.statistics);
          print('[SportService] ✅ Added SportsDB stats');
        }

        // Season stats - merge if ESPN season stats are empty
        if ((merged.seasonStats == null || merged.seasonStats!.isEmpty) &&
            sportsDbPlayer.seasonStats != null &&
            sportsDbPlayer.seasonStats!.isNotEmpty) {
          merged = merged.copyWith(seasonStats: sportsDbPlayer.seasonStats);
          print('[SportService] ✅ Added SportsDB season stats');
        }

        // Career stats - merge if ESPN career stats are empty
        if ((merged.careerStats == null || merged.careerStats!.isEmpty) &&
            sportsDbPlayer.careerStats != null &&
            sportsDbPlayer.careerStats!.isNotEmpty) {
          merged = merged.copyWith(careerStats: sportsDbPlayer.careerStats);
          print('[SportService] ✅ Added SportsDB career stats');
        }

        // Nationality - use SportsDB if ESPN missing
        if ((merged.nationality == null || merged.nationality!.isEmpty) &&
            sportsDbPlayer.nationality != null) {
          merged = merged.copyWith(nationality: sportsDbPlayer.nationality);
        }

        // Birth date - use SportsDB if ESPN missing
        if ((merged.birthDate == null || merged.birthDate!.isEmpty) &&
            sportsDbPlayer.birthDate != null) {
          merged = merged.copyWith(birthDate: sportsDbPlayer.birthDate);
        }

        // Foot - SportsDB has this, ESPN doesn't
        if (sportsDbPlayer.foot != null && sportsDbPlayer.foot!.isNotEmpty) {
          merged = merged.copyWith(foot: sportsDbPlayer.foot);
          print('[SportService] ✅ Added foot: ${sportsDbPlayer.foot}');
        }

        // Market value - SportsDB has this
        if (sportsDbPlayer.marketValue != null && sportsDbPlayer.marketValue! > 0) {
          merged = merged.copyWith(marketValue: sportsDbPlayer.marketValue);
          print('[SportService] ✅ Added market value: ${sportsDbPlayer.marketValue}');
        }

        // Preferred position - use SportsDB if more specific
        if (sportsDbPlayer.preferredPosition != null &&
            sportsDbPlayer.preferredPosition!.isNotEmpty) {
          merged = merged.copyWith(preferredPosition: sportsDbPlayer.preferredPosition);
        }
      }

      // ─── STEP 3.5: Season statistics from API-Football ────────────────────
      // Neither of the sources above can actually supply this: ESPN's
      // soccer athlete payload has no statistics/seasonStats/careerStats
      // fields, and TheSportsDB's free key locks its one stats endpoint to
      // a single demo player (see sportsdb_service.dart). API-Football's
      // `/players` endpoint is the real source for goals/shots/passes/
      // tackles etc., scoped to the league this player is actually playing
      // in — this is expected to run regardless of whether ESPN/SportsDB
      // left seasonStats empty, not a fallback path. The actual fetch
      // already happened above (in parallel with SportsDB); this just
      // applies the result.
      if (afStats != null && afStats.isNotEmpty) {
        final mergedSeasonStats = <String, dynamic>{
          ...afStats,
          ...?merged.seasonStats, // ESPN/SportsDB values win if present
        };
        merged = merged.copyWith(seasonStats: mergedSeasonStats);

        // Backfill the top-line Goals/Assists/Apps grid too, since
        // ESPN's `statistics` map is empty for soccer in practice.
        if (merged.statistics.isEmpty) {
          merged = merged.copyWith(statistics: {
            'goals': afStats['goals'],
            'assists': afStats['assists'],
            'appearances': afStats['appearances'],
          });
        }
        print('[SportService] ✅ Added API-Football season stats '
            '(${afStats['statsLeague']} ${afStats['statsSeason']})');
      } else if (wantsAfStats) {
        print('[SportService] ⚠️ No API-Football season stats found for '
            '${merged.displayName} in $league');
      }

      // ─── STEP 3.6: Predefined stats fallback for well-known players ──────
      // The bug: ESPN/SportsDB can succeed (name, photo, nationality, DOB
      // all populate fine) while API-Football's stats call comes back
      // empty because the daily rate limit was hit. That leaves `merged`
      // non-null/non-empty overall, so the "hybrid fetch totally failed"
      // fallback in STEP 4/5 below never runs — it only triggers when
      // `espnPlayer` itself is null. We need a check here that looks
      // specifically at whether the *stats* are empty, independent of
      // whether the bio fields succeeded.
      bool isMeaninglessCareerStats(List<Map<String, dynamic>>? cs) {
        if (cs == null || cs.isEmpty) return true;
        // Treat as empty if every entry has goals/assists/appearances all
        // zero (the shape SportsDB fabricates when it only knows the
        // player's team/season name but has no real numbers).
        return cs.every((row) {
          final g = num.tryParse('${row['goals'] ?? 0}') ?? 0;
          final a = num.tryParse('${row['assists'] ?? 0}') ?? 0;
          final ap = num.tryParse('${row['appearances'] ?? 0}') ?? 0;
          return g == 0 && a == 0 && ap == 0;
        });
      }

      final statsAreEmpty = merged.statistics.isEmpty &&
          (merged.seasonStats == null || merged.seasonStats!.isEmpty) &&
          isMeaninglessCareerStats(merged.careerStats);

      // ✅ FIX: "empty" was the only trigger for this fallback, which is
      // why a wrongly-matched player's real-but-tiny stat line (0G/1A/32
      // apps attached to Cristiano Ronaldo) never got replaced — the map
      // wasn't empty, just wrong. `_bestApiFootballPlayerMatch` is now
      // stricter about what counts as a confident match (see api_service),
      // which fixes the root cause. This is a second, independent check:
      // if we already have verified predefined data for this player and
      // the live-fetched numbers are far below it, that's a strong signal
      // the live match was for a different person (career totals only go
      // up), so prefer the known-good data instead of the smaller number.
      bool liveStatsImplausiblyLow() {
        final predefined = predefinedPlayerStats[playerId];
        if (predefined == null) return false;
        final knownGoals = num.tryParse('${predefined['careerGoals'] ?? 0}') ?? 0;
        final knownApps = num.tryParse('${predefined['careerAppearances'] ?? 0}') ?? 0;
        if (knownGoals <= 0 && knownApps <= 0) return false;

        final liveGoals = num.tryParse('${merged.statistics['goals'] ?? 0}') ?? 0;
        final liveApps = num.tryParse('${merged.statistics['appearances'] ?? 0}') ?? 0;

        // A believable single-season/competition slice can legitimately be
        // smaller than a whole career total — so only flag it when the
        // live numbers are so far below the known career totals that they
        // can't plausibly be this player at all (e.g. 32 apps for someone
        // with 1000+ known appearances and near-zero goals for a career
        // goalscorer of Ronaldo's caliber).
        final goalsImplausible = knownGoals >= 50 && liveGoals == 0;
        final appsImplausible = knownApps >= 200 && liveApps > 0 && liveApps < 50;
        return goalsImplausible && appsImplausible;
      }

      if (statsAreEmpty || liveStatsImplausiblyLow()) {
        final predefined = predefinedPlayerStats[playerId];
        if (predefined != null) {
          print('[SportService] ⚠️ Live stats for $playerId are empty or '
              'implausible — applying predefined stats fallback');

          final careerStatsFallback = (predefined['careerStats'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final seasonStatsFallback =
          Map<String, dynamic>.from(predefined['seasonStats'] as Map);

          merged = merged.copyWith(
            statistics: {
              'goals': predefined['careerGoals'],
              'assists': predefined['careerAssists'],
              'appearances': predefined['careerAppearances'],
            },
            seasonStats: seasonStatsFallback,
            careerStats: careerStatsFallback,
          );

          print('[SportService] ✅ Applied predefined stats fallback for '
              '${merged.displayName}');
        } else {
          print('[SportService] ⚠️ No predefined stats available for '
              '$playerId either — stats will remain empty');
        }
      }

      // If still no headshot, try to get from team roster
      if (merged.headshot.isEmpty && merged.teamId.isNotEmpty) {
        try {
          final teamRoster = await _api.getTeamRoster(merged.teamId, league);
          final teamPlayer = teamRoster.firstWhere(
                (p) => p.id == playerId || p.displayName == merged.displayName,
            orElse: () => Player(
              id: playerId,
              fullName: merged.fullName,
              displayName: merged.displayName,
              headshot: '',
              jersey: '',
              position: '',
              teamId: '',
              teamName: '',
              height: 0,
              weight: 0,
              age: 0,
              college: '',
              statistics: {},
            ),
          );
          if (teamPlayer.headshot.isNotEmpty) {
            merged = merged.copyWith(headshot: teamPlayer.headshot);
            print('[SportService] ✅ Found headshot in team roster');
          }
        } catch (_) {}
      }

      print('[SportService] ✅ Final merged player: ${merged.displayName}');
      print('[SportService]    Headshot: ${merged.headshot}');
      print('[SportService]    Nationality: ${merged.nationality}');
      print('[SportService]    Stats: ${merged.statistics}');
      print('[SportService]    SeasonStats: ${merged.seasonStats}');
      return merged;
    }

    // ─── STEP 4: Fallback to SportsDB if ESPN failed ──────────────────────
    if (sportsDbPlayer != null && sportsDbPlayer.id.isNotEmpty) {
      print('[SportService] ✅ Using SportsDB as fallback for: ${sportsDbPlayer.displayName}');
      return sportsDbPlayer;
    }

    // ─── STEP 5: Return empty player ────────────────────────────────────────
    // ✅ FIX: `id` used to be set to `playerId` here even though nothing
    // was actually found — a non-empty id on an otherwise-blank Player.
    // Callers (e.g. players_screen.dart's `_loadPlayerDetails`) check
    // `playerDetails.id.isNotEmpty` to decide whether the hybrid fetch
    // succeeded; that always evaluated to true here, so total failure was
    // reported as success, and the caller's own good local fallback
    // (`_createPlayerFromPitchPlayer`, which correctly checks
    // predefinedPlayerStats) never ran. `id` is genuinely empty now so
    // callers can tell this apart from a real result.
    print('[SportService] ❌ No data found for player: $playerId');
    return Player(
      id: '',
      fullName: '',
      displayName: '',
      headshot: '',
      jersey: '',
      position: '',
      teamId: '',
      teamName: '',
      height: 0,
      weight: 0,
      age: 0,
      college: '',
      statistics: {},
    );
  }

  /// Parse SportsDB player data to our Player model
  Player _parseSportsDbPlayer(Map<String, dynamic> data) {
    final id = data['idPlayer']?.toString() ?? '';
    final name = data['strPlayer']?.toString() ?? '';
    final fullName = data['strFullName']?.toString() ?? name;
    final displayName = name.isNotEmpty ? name : fullName;

    // Headshot - prefer cutout (transparent PNG) then thumb
    String headshot = data['strCutout']?.toString() ?? '';
    if (headshot.isEmpty) {
      headshot = data['strThumb']?.toString() ?? '';
    }

    // Add size modifier for smaller images
    if (headshot.isNotEmpty && !headshot.contains('/tiny') && !headshot.contains('/small')) {
      headshot = '$headshot/small';
    }

    final jersey = data['strNumber']?.toString() ?? '';
    final position = data['strPosition']?.toString() ?? '';
    final teamName = data['strTeam']?.toString() ?? '';
    final teamId = data['idTeam']?.toString() ?? '';

    // Height in cm -> inches
    int height = 0;
    final heightStr = data['strHeight']?.toString() ?? '';
    if (heightStr.isNotEmpty) {
      final cm = double.tryParse(heightStr.replaceAll(' cm', '').trim()) ?? 0;
      height = (cm / 2.54).round();
    }

    // Weight in kg -> lbs
    int weight = 0;
    final weightStr = data['strWeight']?.toString() ?? '';
    if (weightStr.isNotEmpty) {
      final kg = double.tryParse(weightStr.replaceAll(' kg', '').trim()) ?? 0;
      weight = (kg * 2.20462).round();
    }

    // Age
    int age = 0;
    final birthDate = data['dateBorn']?.toString() ?? '';
    if (birthDate.isNotEmpty) {
      try {
        final birth = DateTime.parse(birthDate);
        final now = DateTime.now();
        age = now.year - birth.year;
        if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
          age--;
        }
      } catch (_) {}
    }

    final nationality = data['strNationality']?.toString() ?? '';
    final foot = data['strFoot']?.toString() ?? '';

    // Market value
    double? marketValue;
    final valueStr = data['strValue']?.toString() ?? '';
    if (valueStr.isNotEmpty) {
      final clean = valueStr.replaceAll('€', '').replaceAll('M', '').replaceAll('B', '').trim();
      final val = double.tryParse(clean);
      if (val != null) {
        if (valueStr.contains('B')) {
          marketValue = val * 1000;
        } else {
          marketValue = val;
        }
      }
    }

    // ─── Build statistics map from SportsDB ──────────────────────────────────
    final stats = <String, dynamic>{};

    // Basic stats
    if (data['intGoals'] != null) stats['goals'] = data['intGoals'];
    if (data['intAssists'] != null) stats['assists'] = data['intAssists'];
    if (data['intAppearances'] != null) stats['appearances'] = data['intAppearances'];
    if (data['intShots'] != null) stats['shots'] = data['intShots'];
    if (data['intShotsOnTarget'] != null) stats['shotsOnTarget'] = data['intShotsOnTarget'];
    if (data['intPasses'] != null) stats['passes'] = data['intPasses'];
    if (data['intTackles'] != null) stats['tackles'] = data['intTackles'];
    if (data['intClearances'] != null) stats['clearances'] = data['intClearances'];
    if (data['intYellowCards'] != null) stats['yellowCards'] = data['intYellowCards'];
    if (data['intRedCards'] != null) stats['redCards'] = data['intRedCards'];

    // ─── Build season stats ───────────────────────────────────────────────────
    final seasonStats = <String, dynamic>{};
    // SportsDB doesn't have season-specific stats in the same format,
    // but we can use the career stats or create a season summary
    if (data['intGoals'] != null) seasonStats['goals'] = data['intGoals'];
    if (data['intAssists'] != null) seasonStats['assists'] = data['intAssists'];
    if (data['intAppearances'] != null) seasonStats['appearances'] = data['intAppearances'];

    // ─── Build career stats from SportsDB data ──────────────────────────────
    List<Map<String, dynamic>>? careerStats;
    // SportsDB has a different structure for career stats. IMPORTANT: only
    // fabricate an entry when at least one real numeric stat is present.
    // The old condition triggered on `strTeam`/`strSeason` alone — SportsDB
    // returns the player's current team on basically every profile, so this
    // produced a single-entry list of all "0"s for players whose stats
    // endpoint is locked (see note above `stats` map). That placeholder
    // entry made `careerStats` look non-empty downstream, which silently
    // blocked the predefined-stats fallback in getPlayerDetailsHybrid from
    // ever running — it never saw "career stats are actually empty".
    if (data['intGoals'] != null ||
        data['intAssists'] != null ||
        data['intAppearances'] != null) {
      careerStats = [];
      final season = data['strSeason']?.toString() ?? 'Career';
      final team = data['strTeam']?.toString() ?? '';
      final seasonMap = <String, dynamic>{
        'season': season,
        'team': team,
        'goals': data['intGoals']?.toString() ?? '0',
        'assists': data['intAssists']?.toString() ?? '0',
        'appearances': data['intAppearances']?.toString() ?? '0',
      };
      careerStats.add(seasonMap);
    }

    print('[SportsDb] Parsed player: $displayName');
    print('[SportsDb]   Goals: ${stats['goals'] ?? 'N/A'}');
    print('[SportsDb]   Assists: ${stats['assists'] ?? 'N/A'}');
    print('[SportsDb]   Appearances: ${stats['appearances'] ?? 'N/A'}');
    print('[SportsDb]   Headshot: ${headshot.isNotEmpty ? 'Yes' : 'No'}');

    return Player(
      id: id,
      fullName: fullName,
      displayName: displayName,
      headshot: headshot,
      jersey: jersey,
      position: position,
      teamId: teamId,
      teamName: teamName,
      height: height,
      weight: weight,
      age: age,
      college: '',
      statistics: stats,
      injuryStatus: null,
      nationality: nationality.isNotEmpty ? nationality : null,
      birthDate: birthDate.isNotEmpty ? birthDate : null,
      foot: foot.isNotEmpty ? foot : null,
      preferredPosition: position.isNotEmpty ? position : null,
      marketValue: marketValue,
      contractExpiry: null,
      seasonStats: seasonStats.isNotEmpty ? seasonStats : null,
      careerStats: careerStats,
    );
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

  // ─── TEAM PAGE DATA WITH 3-DAY CACHING ─────────────────────────────────────
  Future<TeamPageData> getTeamPageData(
      String teamId, {
        String? leagueCode,
        bool forceRefresh = false,
      }) async {
    final resolvedLeague = leagueCode ?? _currentLeagueCode;
    final cacheKey = '${_teamPageCacheKeyPrefix}${teamId}_${resolvedLeague}';

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

      await _cache.cacheTeamPageData(cacheKey, data);
      print('[SportService] ✅ Team page data cached for $teamId (3 days)');

      return data;
    } catch (e) {
      print('[SportService] getTeamPageData error: $e');
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

  // ─── TEAM PAGE DATA: STAGED LOADING ─────────────────────────────────────────
  // Matches load first and are handed back immediately via [onMatchesReady] so
  // the Matches tab can render right away; squad + analytics are then fetched
  // in the background and delivered via [onSquadAnalyticsReady] once ready.
  Future<TeamPageData> getTeamPageDataStaged(
      String teamId, {
        String? leagueCode,
        bool forceRefresh = false,
        Function(TeamPageData matchesOnly)? onMatchesReady,
        Function(TeamPageData fullData)? onSquadAnalyticsReady,
      }) async {
    final resolvedLeague = leagueCode ?? _currentLeagueCode;
    final cacheKey = '${_teamPageCacheKeyPrefix}${teamId}_${resolvedLeague}';

    if (!forceRefresh) {
      TeamPageData? cached;
      try {
        cached = await _cache.getCachedTeamPageData(cacheKey);
      } catch (e) {
        print('[SportService] Team page cache read error: $e');
      }

      if (cached != null) {
        print('[SportService] ✅ Team page cache HIT for $teamId — showing instantly, revalidating in background');
        // Show the cached page immediately — both stages resolve together
        // since the cache already has everything.
        if (onMatchesReady != null) onMatchesReady(cached);
        if (onSquadAnalyticsReady != null) onSquadAnalyticsReady(cached);

        // Then silently refetch live data behind the scenes. The screen
        // is only updated (and the cache only rewritten) if something
        // actually changed — an unchanged revalidation is invisible.
        _revalidateTeamPageInBackground(
          teamId: teamId,
          leagueCode: resolvedLeague,
          cacheKey: cacheKey,
          previous: cached,
          onMatchesReady: onMatchesReady,
          onSquadAnalyticsReady: onSquadAnalyticsReady,
        );

        return cached;
      }
    }

    try {
      print('[SportService] Stage 1: fetching matches for $teamId');
      final matches = await _api.getTeamMatchesData(teamId, leagueCode: resolvedLeague);
      final matchesOnly = TeamPageData.fromMatches(matches);

      if (onMatchesReady != null) onMatchesReady(matchesOnly);

      // Stage 2 (squad + analytics) runs in the background — the caller is
      // not blocked on it, and it does not delay returning matchesOnly.
      _fetchSquadAnalyticsInBackground(
        teamId: teamId,
        cacheKey: cacheKey,
        matches: matches,
        matchesOnly: matchesOnly,
        onSquadAnalyticsReady: onSquadAnalyticsReady,
      );

      return matchesOnly;
    } catch (e) {
      print('[SportService] getTeamPageDataStaged error: $e');
      try {
        final cached = await _cache.getCachedTeamPageData(cacheKey);
        if (cached != null) {
          print('[SportService] ⚠️ Returning stale cache for $teamId');
          if (onMatchesReady != null) onMatchesReady(cached);
          if (onSquadAnalyticsReady != null) onSquadAnalyticsReady(cached);
          return cached;
        }
      } catch (_) {}
      final empty = TeamPageData.empty(resolvedLeague);
      if (onMatchesReady != null) onMatchesReady(empty);
      return empty;
    }
  }

  /// Fire-and-forget stage 2: fetches squad + analytics, merges them onto
  /// the matches-only page, caches the complete result, and notifies the
  /// caller via [onSquadAnalyticsReady]. Errors here never surface to the
  /// caller of [getTeamPageDataStaged] — matches are already on screen, so
  /// the squad/analytics tabs simply keep showing their loading state.
  Future<void> _fetchSquadAnalyticsInBackground({
    required String teamId,
    required String cacheKey,
    required TeamMatchesData matches,
    required TeamPageData matchesOnly,
    Function(TeamPageData fullData)? onSquadAnalyticsReady,
  }) async {
    try {
      print('[SportService] Stage 2: fetching squad + analytics for $teamId');
      final squadAnalytics = await _api.getTeamSquadAndAnalytics(
        teamId,
        queryLeagueCode: matches.queryLeagueCode,
        recentMatches: matches.recentMatches,
      );

      final fullData = matchesOnly.copyWith(
        squad: squadAnalytics.squad,
        analytics: squadAnalytics.analytics,
      );

      await _cache.cacheTeamPageData(cacheKey, fullData);
      print('[SportService] ✅ Team page data cached for $teamId (3 days)');

      if (onSquadAnalyticsReady != null) onSquadAnalyticsReady(fullData);
    } catch (e) {
      print('[SportService] Squad/analytics background fetch error: $e');
    }
  }

  /// Stale-while-revalidate: called after a cache hit has already been shown
  /// to the user. Silently refetches live data (same two stages as a cold
  /// load) and diffs each stage against [previous]. The screen callback and
  /// on-device cache are only touched when something genuinely changed —
  /// an unchanged revalidation is invisible to the user and doesn't rewrite
  /// the cache, so the 3-day TTL keeps counting from the last real change.
  Future<void> _revalidateTeamPageInBackground({
    required String teamId,
    required String leagueCode,
    required String cacheKey,
    required TeamPageData previous,
    Function(TeamPageData matchesOnly)? onMatchesReady,
    Function(TeamPageData fullData)? onSquadAnalyticsReady,
  }) async {
    TeamMatchesData matches;
    TeamPageData mergedMatches;
    try {
      print('[SportService] 🔄 Revalidating matches for $teamId');
      matches = await _api.getTeamMatchesData(teamId, leagueCode: leagueCode);
      final freshMatches = TeamPageData.fromMatches(matches);
      // Keep showing the squad/analytics already on screen until stage 2
      // below resolves, so a matches-only change doesn't blank the tabs.
      mergedMatches = freshMatches.copyWith(
        squad: previous.squad,
        analytics: previous.analytics,
      );

      if (!_cache.teamPageDataEquals(mergedMatches, previous)) {
        print('[SportService] 🔄 Matches changed for $teamId — updating screen');
        if (onMatchesReady != null) onMatchesReady(mergedMatches);
      } else {
        print('[SportService] Matches unchanged for $teamId');
      }
    } catch (e) {
      print('[SportService] Revalidation (matches) error for $teamId: $e');
      return; // Live refresh failed outright — leave the cached page as-is.
    }

    try {
      print('[SportService] 🔄 Revalidating squad/analytics for $teamId');
      final squadAnalytics = await _api.getTeamSquadAndAnalytics(
        teamId,
        queryLeagueCode: matches.queryLeagueCode,
        recentMatches: matches.recentMatches,
      );

      final fullData = mergedMatches.copyWith(
        squad: squadAnalytics.squad,
        analytics: squadAnalytics.analytics,
      );

      if (!_cache.teamPageDataEquals(fullData, previous)) {
        print('[SportService] 🔄 Team page changed for $teamId — re-caching');
        await _cache.cacheTeamPageData(cacheKey, fullData);
        if (onSquadAnalyticsReady != null) onSquadAnalyticsReady(fullData);
      } else {
        print('[SportService] Team page unchanged for $teamId — cache left as-is');
      }
    } catch (e) {
      print('[SportService] Revalidation (squad/analytics) error for $teamId: $e');
    }
  }

  /// Returns true when the given league code represents national teams
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