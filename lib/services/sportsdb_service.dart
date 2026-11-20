// lib/services/sportsdb_service.dart
//
// Additional data source: TheSportsDB (https://www.thesportsdb.com).
//
// ─── SCOPE (read before extending this file) ──────────────────────────────
// TheSportsDB's free key ('123') is genuinely restricted, verified against
// the live API rather than assumed from docs:
//
//   ✅ search_all_teams.php?l=<League_Name>  — works for any league, and
//      every team includes `idESPN`, so we can match to our existing ESPN
//      team IDs with no fuzzy string matching.
//   ✅ lookup_all_players.php?id=<sportsDbTeamId> — works for any team, and
//      every player includes `idESPN` plus transparent-background headshot
//      URLs (`strCutout`, falling back to `strThumb`).
//   ✅ searchplayers.php?p=<name> — Works for player search on free tier
//   ❌ searchteams.php?t=<name> — locked to always return "Arsenal" on the
//      free key regardless of query. Do not use for lookups.
//   ❌ lookupplayerstats.php?id=<playerId> — locked to a single demo player
//      (Cristiano Ronaldo) on the free key; it ignores the id you pass.
//      There is no way to pull arbitrary player season/career stats from
//      this endpoint on a free key, so this service does not expose one.
//   ❌ No league "stat leaders" (top scorer/assists/cards) endpoint exists
//      anywhere in TheSportsDB's API, free or paid.
//   ❌ No per-match player rating endpoint exists either.
//
// So: this service currently does exactly one job — resolve a *fallback*
// player headshot (transparent cutout PNG) for a given ESPN player id, by
// walking ESPN-team-id → SportsDB-team-id → SportsDB roster → ESPN-matched
// headshot. It is additive only: ESPN stays the primary source everywhere,
// and API-Football/ESPN are untouched. If a lookup fails for any reason
// (unmapped league, network error, team not found) it fails silently and
// the caller keeps whatever it already had (usually nothing, i.e. falls
// back to initials in the UI — exactly as before this service existed).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/utils/constants.dart';

class SportsDbService {
  static final SportsDbService _instance = SportsDbService._internal();
  factory SportsDbService() => _instance;
  SportsDbService._internal();

  final http.Client _client = http.Client();
  final CacheService _cache = CacheService();

  String get _key => AppConstants.sportsDbApiKey;
  String get _base => '${AppConstants.sportsDbBaseUrl}/$_key';

  /// In-memory guard so two concurrent lineup enrichments for the same
  /// league/team don't both hit the network before the cache is written.
  final Map<String, Future<Map<String, String>>> _inFlightLeagueMaps = {};
  final Map<String, Future<Map<String, String>>> _inFlightTeamHeadshots = {};

  /// In-memory cache for team headshot maps (disk cache is also used)
  final Map<String, Map<String, String>> _headshotMemoryCache = {};

  // ─── PLAYER SEARCH AND LOOKUP ──────────────────────────────────────────────

  /// Search for a player by name in TheSportsDB
  Future<Map<String, dynamic>?> searchPlayerByName(String playerName) async {
    final cacheKey = 'sportsdb_search_${playerName.toLowerCase()}';
    final cached = await _cache.getCachedSportsDbSearch(cacheKey);
    if (cached != null) {
      print('[SportsDb] Search cache HIT for: $playerName');
      return cached;
    }

    try {
      final url = '$_base/searchplayers.php?p=${Uri.encodeComponent(playerName)}';
      print('[SportsDb] Searching player: $url');
      final res = await _client.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final players = data['player'] as List? ?? [];
        if (players.isNotEmpty) {
          final result = players.first as Map<String, dynamic>;
          await _cache.cacheSportsDbSearch(cacheKey, result);
          return result;
        }
      }
    } catch (e) {
      print('[SportsDb] Search error: $e');
    }
    return null;
  }

  /// Search for players by name with partial matches
  Future<List<Map<String, dynamic>>> searchPlayersByName(String playerName) async {
    final results = <Map<String, dynamic>>[];

    try {
      final url = '$_base/searchplayers.php?p=${Uri.encodeComponent(playerName)}';
      print('[SportsDb] Multi-search: $url');
      final res = await _client.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final players = data['player'] as List? ?? [];
        for (final p in players) {
          if (p is Map<String, dynamic>) {
            results.add(p);
          }
        }
        print('[SportsDb] Found ${results.length} players');
      }
    } catch (e) {
      print('[SportsDb] Multi-search error: $e');
    }
    return results;
  }

  /// Lookup player by SportsDB ID
  Future<Map<String, dynamic>?> lookupPlayer(String playerId) async {
    try {
      final url = '$_base/lookupplayer.php?id=$playerId';
      print('[SportsDb] Looking up player: $url');
      final res = await _client.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final players = data['players'] as List? ?? [];
        if (players.isNotEmpty) {
          return players.first as Map<String, dynamic>;
        }
      }
    } catch (e) {
      print('[SportsDb] Lookup error: $e');
    }
    return null;
  }

  /// Get a player by ESPN ID (searches by name or looks up via team roster)
  Future<Map<String, dynamic>?> getPlayerByEspnId(String espnPlayerId) async {
    final cacheKey = 'sportsdb_player_$espnPlayerId';
    final cached = await _cache.getCachedSportsDbPlayerData(cacheKey);
    if (cached != null) {
      print('[SportsDb] Player cache HIT for ESPN ID: $espnPlayerId');
      return cached;
    }

    // Try to find the player by searching all mapped leagues
    final leagueCodes = AppConstants.sportsDbLeagueNames.keys.toList();

    for (final leagueCode in leagueCodes) {
      try {
        final teamMap = await _getLeagueTeamMap(leagueCode);
        // We need to search players by name, but we don't have the name
        // This is a chicken-and-egg problem - we need the name to search
        // but we're trying to get data for a player ID

        // Try to find the player in a team roster if we know the team
        // This would require knowing the team ID first
      } catch (_) {}
    }

    return null;
  }

  /// Fetch a player by name from TheSportsDB and parse to our Player model
  Future<Map<String, dynamic>?> fetchPlayerByName(String playerName) async {
    if (playerName.isEmpty) return null;

    try {
      final result = await searchPlayerByName(playerName);
      if (result != null) {
        // Check if this player has an ESPN ID we can use to verify
        final espnId = result['idESPN']?.toString() ?? '';
        if (espnId.isNotEmpty) {
          print('[SportsDb] Found player with ESPN ID: $espnId');
        }
        return result;
      }
    } catch (e) {
      print('[SportsDb] Fetch player by name error: $e');
    }
    return null;
  }

  /// Get the roster for a SportsDB team ID
  Future<List<Map<String, dynamic>>> getTeamRoster(String sportsDbTeamId) async {
    try {
      final url = '$_base/lookup_all_players.php?id=$sportsDbTeamId';
      print('[SportsDb] Fetching team roster: $url');
      final res = await _client.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final players = data['player'] as List? ?? [];
        return players.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('[SportsDb] Team roster error: $e');
    }
    return [];
  }

  /// Returns a map of ESPN team id -> TheSportsDB team id for [leagueCode],
  /// or an empty map if the league isn't mapped / the request fails.
  Future<Map<String, String>> _getLeagueTeamMap(String leagueCode) async {
    final sportsDbLeagueName = AppConstants.sportsDbLeagueNames[leagueCode];
    if (sportsDbLeagueName == null) return {};

    final cached = await _cache.getCachedSportsDbLeagueTeamMap(leagueCode);
    if (cached != null) return cached;

    return _inFlightLeagueMaps.putIfAbsent(leagueCode, () async {
      try {
        final uri = Uri.parse(
            '$_base/search_all_teams.php?l=$sportsDbLeagueName');
        final res = await _client.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return {};

        final data = json.decode(res.body) as Map<String, dynamic>;
        final teams = data['teams'] as List? ?? [];

        final map = <String, String>{};
        for (final t in teams) {
          if (t is! Map) continue;
          final espnId = t['idESPN']?.toString() ?? '';
          final sdbId = t['idTeam']?.toString() ?? '';
          if (espnId.isNotEmpty && sdbId.isNotEmpty) {
            map[espnId] = sdbId;
          }
        }

        if (map.isNotEmpty) {
          await _cache.cacheSportsDbLeagueTeamMap(leagueCode, map);
        }
        return map;
      } catch (e) {
        print('[SportsDbService] League team map error for "$leagueCode": $e');
        return {};
      } finally {
        _inFlightLeagueMaps.remove(leagueCode);
      }
    });
  }

  /// Resolves the TheSportsDB team id for an ESPN team id by scanning every
  /// domestic league we have mapped in [AppConstants.sportsDbLeagueNames] —
  /// NOT by trusting the match's own competition/league code.
  ///
  /// This matters because `getMatchLineup` tries several ESPN league paths
  /// until one returns a boxscore for the event id, and ESPN's summary
  /// endpoint doesn't actually validate that the event belongs to the league
  /// in the URL — so the "winning" league code can be something unrelated
  /// (e.g. a Bayern Munich vs Atalanta Champions League game can resolve
  /// under `fifa.world`). A club's real SportsDB roster lives under its
  /// *domestic* league (Bayern → Bundesliga, Atalanta → Serie A), which has
  /// nothing to do with which competition today's fixture is in. So instead
  /// of a single guess, we check every mapped domestic league — cached ones
  /// first (free), then fetch any not-yet-cached ones until we find a match.
  Future<String?> _resolveSportsDbTeamId(String espnTeamId) async {
    final leagueCodes = AppConstants.sportsDbLeagueNames.keys.toList();

    // Pass 1: cached league maps only — no network calls.
    final uncached = <String>[];
    for (final leagueCode in leagueCodes) {
      final cached = await _cache.getCachedSportsDbLeagueTeamMap(leagueCode);
      if (cached == null) {
        uncached.add(leagueCode);
        continue;
      }
      final sdbId = cached[espnTeamId];
      if (sdbId != null && sdbId.isNotEmpty) return sdbId;
    }

    // Pass 2: fetch leagues we haven't cached yet, one at a time, stopping
    // as soon as we find the team. Each league fetched here gets cached for
    // 7 days, so this cost is paid at most once per league overall.
    for (final leagueCode in uncached) {
      final map = await _getLeagueTeamMap(leagueCode);
      final sdbId = map[espnTeamId];
      if (sdbId != null && sdbId.isNotEmpty) return sdbId;
    }

    return null;
  }

  /// Fetches player headshots for a specific ESPN team.
  ///
  /// This is the main method to call for squad headshots.
  /// Returns a map of ESPN player ID -> headshot URL.
  Future<Map<String, String>> getTeamHeadshots(String espnTeamId) async {
    if (espnTeamId.isEmpty) return {};

    // Check memory cache first
    if (_headshotMemoryCache.containsKey(espnTeamId)) {
      final cached = _headshotMemoryCache[espnTeamId]!;
      print('[SportsDb] Memory cache HIT for team: $espnTeamId (${cached.length} headshots)');
      return cached;
    }

    // Check disk cache
    final cachedDisk = await _cache.getCachedSportsDbTeamHeadshots(espnTeamId);
    if (cachedDisk != null) {
      _headshotMemoryCache[espnTeamId] = cachedDisk;
      print('[SportsDb] Disk cache HIT for team: $espnTeamId (${cachedDisk.length} headshots)');
      return cachedDisk;
    }

    print('[SportsDb] Fetching headshots for team: $espnTeamId');

    // Fetch from API
    final headshots = await _getTeamHeadshots(espnTeamId);

    // Cache in memory and disk
    if (headshots.isNotEmpty) {
      _headshotMemoryCache[espnTeamId] = headshots;
      await _cache.cacheSportsDbTeamHeadshots(espnTeamId, headshots);
      print('[SportsDb] Fetched ${headshots.length} headshots for team: $espnTeamId');
    } else {
      // Cache empty result to avoid repeated API calls
      _headshotMemoryCache[espnTeamId] = {};
      await _cache.cacheSportsDbTeamHeadshots(espnTeamId, {});
      print('[SportsDb] No headshots found for team: $espnTeamId');
    }

    return headshots;
  }

  /// Returns a map of ESPN player id -> SportsDB headshot URL for the
  /// roster of ESPN team [espnTeamId]. Empty map if the team can't be
  /// resolved against any mapped domestic league, or the request fails.
  Future<Map<String, String>> _getTeamHeadshots(String espnTeamId) async {
    final cached = await _cache.getCachedSportsDbTeamHeadshots(espnTeamId);
    if (cached != null) return cached;

    return _inFlightTeamHeadshots.putIfAbsent(espnTeamId, () async {
      try {
        final sportsDbTeamId = await _resolveSportsDbTeamId(espnTeamId);
        if (sportsDbTeamId == null) {
          print('[SportsDbService] No SportsDB match for ESPN team "$espnTeamId" '
              'in any mapped domestic league — skipping.');
          return {};
        }

        final uri = Uri.parse('$_base/lookup_all_players.php?id=$sportsDbTeamId');
        final res = await _client.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) return {};

        final data = json.decode(res.body) as Map<String, dynamic>;
        final players = data['player'] as List? ?? [];

        final map = <String, String>{};
        for (final p in players) {
          if (p is! Map) continue;
          final espnPlayerId = p['idESPN']?.toString() ?? '';
          if (espnPlayerId.isEmpty) continue;
          final headshot = (p['strCutout'] as String?)?.trim().isNotEmpty == true
              ? p['strCutout'] as String
              : (p['strThumb'] as String?)?.trim() ?? '';
          if (headshot.isNotEmpty) {
            map[espnPlayerId] = headshot;
          }
        }

        // Cache even an empty result so we don't hammer the free-tier
        // 30-requests/minute limit retrying a team with no ESPN-matched
        // players every single time a lineup screen opens.
        await _cache.cacheSportsDbTeamHeadshots(espnTeamId, map);
        return map;
      } catch (e) {
        print('[SportsDbService] Team headshots error for ESPN team '
            '"$espnTeamId": $e');
        return {};
      } finally {
        _inFlightTeamHeadshots.remove(espnTeamId);
      }
    });
  }

  /// Given the ESPN team ids for both sides of a match, returns a combined
  /// map of ESPN player id -> SportsDB headshot URL, covering both squads.
  /// Each team is resolved independently via its own domestic league (see
  /// `_resolveSportsDbTeamId`), so this works correctly regardless of which
  /// competition today's fixture is actually in (cup, continental, etc).
  /// Returns an empty map if neither team's domestic league is mapped in
  /// [AppConstants.sportsDbLeagueNames] — callers should just keep whatever
  /// headshot they already had (e.g. ESPN's own, or an initials avatar).
  Future<Map<String, String>> getLineupHeadshots({
    required String homeEspnTeamId,
    required String awayEspnTeamId,
  }) async {
    final results = await Future.wait([
      if (homeEspnTeamId.isNotEmpty) _getTeamHeadshots(homeEspnTeamId),
      if (awayEspnTeamId.isNotEmpty) _getTeamHeadshots(awayEspnTeamId),
    ]);

    final combined = <String, String>{};
    for (final m in results) {
      combined.addAll(m);
    }
    return combined;
  }

  /// Get a single player headshot by ESPN player ID and team ID.
  /// This is a convenience wrapper around [getTeamHeadshots].
  Future<String?> getPlayerHeadshot(String espnPlayerId, String espnTeamId) async {
    if (espnPlayerId.isEmpty || espnTeamId.isEmpty) return null;

    final headshots = await getTeamHeadshots(espnTeamId);
    return headshots[espnPlayerId];
  }
}