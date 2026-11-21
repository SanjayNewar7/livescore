// lib/screens/search_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/models/search_model.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/screens/team_detail_screen.dart';
import 'package:livescore/screens/players_screen.dart';
import 'package:livescore/widgets/football_pitch_lineup.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/predefined_data.dart' as seed;
import 'package:livescore/services/sportsdb_service.dart';
import 'package:livescore/services/predefined_data_service.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
// Previously this screen used a one-off blue (0xFF1A62C8) that didn't match
// the rest of the app. These now map directly onto AppTheme's palette
// (see lib/utils/theme.dart) so Search looks like it belongs to the same
// app as everywhere else.
class _C {
  static const blue      = AppTheme.primaryBlue;   // was 0xFF1A62C8
  static const blueLight = AppTheme.lightBlue;      // was 0xFFE8F0FC
  static const white     = AppTheme.pureWhite;
  static const offWhite  = AppTheme.extraLightGray; // was 0xFFF5F7FB
  static const border    = Color(0xFFE2E8F2);
  static const text      = Color(0xFF0F1623);
  static const muted     = AppTheme.lightGray;      // was 0xFF6B7A96
  static const green     = AppTheme.successGreen;   // was 0xFF16A34A
  static const orange    = AppTheme.warningOrange;  // was 0xFFF59E0B

  // ─── Dark mode variants ────────────────────────────────────────────────
  static const darkSurface     = AppTheme.darkGray;
  static const darkBackground  = AppTheme.pureBlack;
  static const darkBorder      = Color(0xFF2C2C2E);
  static const darkText        = AppTheme.pureWhite;
  static const darkBlueLight   = Color(0xFF14243A);
}

// ─── Search Screen ───────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SportsDbService _sportsDbService = SportsDbService();
  SearchResponse _predefinedData = SearchResponse();
  String _lastSearchedQuery = '';

  // ✅ Most of the ~90 entries in predefined_data.dart's famousPlayers list
  // (everything past the original top 10) use a synthetic id like
  // 'fp_vitinha' instead of a real ESPN id, and have `imageUrl: ''` — see
  // that file's own comment: those are meant to be resolved at runtime via
  // TheSportsDB. This screen previously never did that resolution, so
  // every one of those players showed a blank initials avatar here even
  // when a real, current headshot was available. Tracks which player ids
  // we've already attempted a lookup for, so we don't repeat it every
  // rebuild (SportsDbService itself also disk-caches the raw API result).
  final Set<String> _headshotResolutionAttempted = {};

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _buildPredefinedData();
    PredefinedDataService().addListener(_buildPredefinedData);
  }

  @override
  void dispose() {
    PredefinedDataService().removeListener(_buildPredefinedData);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _buildPredefinedData() {
    final players = seed.famousPlayers.map((p) {
      return SearchResult(
        id: p['id'] as String,
        name: p['name'] as String,
        displayName: p['name'] as String,
        type: 'player',
        imageUrl: p['imageUrl'] as String,
        teamName: p['teamName'] as String,
        teamId: p['teamId'] as String,
        position: p['position'] as String,
        jerseyNumber: p['jersey'] as String,
        nationality: p['nationality'] as String,
      );
    }).toList();

    final clubs = seed.famousClubs.map((c) {
      return SearchResult(
        id: c['id']!,
        name: c['name']!,
        displayName: c['name']!,
        type: 'team',
        imageUrl: 'https://a.espncdn.com/i/teamlogos/soccer/500/${c['id']}.png',
        leagueCode: c['league'],
        leagueName: c['leagueName'],
        abbreviation: c['name']!.length > 3 ? c['name']!.substring(0, 3).toUpperCase() : c['name']!.toUpperCase(),
      );
    }).toList();

    setState(() {
      _predefinedData = SearchResponse(
        players: players,
        teams: clubs,
      );
    });

    // Fire-and-forget: fill in real headshots for any predefined player
    // that doesn't already have a static imageUrl (see field comment on
    // `_headshotResolutionAttempted` above for why this is needed).
    _enrichMissingHeadshots();
  }

  /// Resolves a real headshot from TheSportsDB (by player name) for every
  /// predefined player currently showing a blank `imageUrl`, and updates
  /// the list in place as each one resolves. Runs in small concurrent
  /// batches rather than one request per player at once — TheSportsDB's
  /// free key is rate-limited, and `SportsDbService` already disk-caches
  /// each name lookup, so this only does real network work the first time
  /// a given player is ever shown.
  Future<void> _enrichMissingHeadshots() async {
    final candidates = _predefinedData.players
        .where((p) =>
    (p.imageUrl ?? '').isEmpty &&
        !_headshotResolutionAttempted.contains(p.id))
        .toList();
    if (candidates.isEmpty) return;

    const batchSize = 5;
    for (var i = 0; i < candidates.length; i += batchSize) {
      if (!mounted) return;
      final batch = candidates.skip(i).take(batchSize);
      await Future.wait(batch.map((player) async {
        _headshotResolutionAttempted.add(player.id);
        try {
          final data = await _sportsDbService.searchPlayerByName(player.name);
          if (data == null) return;

          // Prefer the transparent-background cutout, same preference
          // order used everywhere else this app talks to TheSportsDB
          // (see sport_service.dart's `_parseSportsDbPlayer`).
          final cutout = (data['strCutout'] as String?)?.trim() ?? '';
          final thumb = (data['strThumb'] as String?)?.trim() ?? '';
          final headshot = cutout.isNotEmpty ? cutout : thumb;
          if (headshot.isEmpty) return;

          _applyResolvedHeadshot(player.id, headshot);
        } catch (_) {
          // Fails silently, same policy as the rest of this app's
          // TheSportsDB integration — the UI just keeps showing an
          // initials avatar for this one player.
        }
      }));
    }
  }

  void _applyResolvedHeadshot(String playerId, String imageUrl) {
    if (!mounted) return;
    setState(() {
      _predefinedData = SearchResponse(
        players: _predefinedData.players.map((p) {
          if (p.id != playerId) return p;
          return SearchResult(
            id: p.id,
            name: p.name,
            displayName: p.displayName,
            type: p.type,
            imageUrl: imageUrl,
            teamName: p.teamName,
            teamId: p.teamId,
            leagueName: p.leagueName,
            leagueCode: p.leagueCode,
            position: p.position,
            jerseyNumber: p.jerseyNumber,
            abbreviation: p.abbreviation,
            nationality: p.nationality,
            age: p.age,
            rating: p.rating,
          );
        }).toList(),
        teams: _predefinedData.teams,
        leagues: _predefinedData.leagues,
        hasMore: _predefinedData.hasMore,
      );
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      context.read<AppProvider>().clearSearch();
      setState(() {
        _lastSearchedQuery = '';
      });
      return;
    }

    if (query == _lastSearchedQuery) {
      // Already searched for this query
      return;
    }

    _lastSearchedQuery = query;
    context.read<AppProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Explicit status bar style (same fix as PlayerScreen) so the icons
      // always contrast with this screen's background, in both themes.
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? _C.darkBackground : _C.offWhite,
        body: SafeArea(
          child: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                focusNode: _focusNode,
                isDark: isDark,
                onSearch: _performSearch,
                onClear: () {
                  _searchController.clear();
                  _lastSearchedQuery = '';
                  context.read<AppProvider>().clearSearch();
                  setState(() {});
                },
              ),
              Expanded(
                child: _SearchResults(
                  predefinedData: _predefinedData,
                  lastSearchedQuery: _lastSearchedQuery,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? _C.darkSurface : _C.white;
    final field = isDark ? _C.darkBackground : _C.offWhite;
    final border = isDark ? _C.darkBorder : _C.border;
    final text = isDark ? _C.darkText : _C.text;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: surface,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: text),
              onPressed: () {
                context.read<AppProvider>().clearSearch();
                Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: field,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSearch(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: text,
                ),
                decoration: InputDecoration(
                  hintText: 'Search players, teams, leagues...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: _C.muted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  prefixIcon: GestureDetector(
                    onTap: onSearch,
                    child: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _C.muted,
                    ),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: text),
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                      : null,
                ),
              ),
            ),
          ),
          Container(
            width: 50,
            height: 40,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: _C.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
              onPressed: onSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Results ──────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final SearchResponse predefinedData;
  final String lastSearchedQuery;
  final bool isDark;

  const _SearchResults({
    required this.predefinedData,
    required this.lastSearchedQuery,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isSearching = provider.isSearching;
    final results = provider.searchResults;
    final query = provider.searchQuery;

    if (isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _C.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 13,
                color: _C.muted,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: TextStyle(
                fontSize: 11,
                color: _C.muted,
              ),
            ),
          ],
        ),
      );
    }

    if (query.isNotEmpty && results.isNotEmpty) {
      return _buildSearchResults(results, provider.isSearchFallback);
    }

    if (query.isNotEmpty && results.isEmpty && !isSearching) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try searching with different keywords',
        isDark: isDark,
      );
    }

    if (query.isEmpty) {
      return _buildPredefinedData();
    }

    return _EmptyState(
      icon: Icons.search_rounded,
      title: 'Search for anything',
      subtitle: 'Find players, teams, and leagues',
      isDark: isDark,
    );
  }

  Widget _buildPredefinedData() {
    final players = predefinedData.players;
    final clubs = predefinedData.teams;

    if (players.isEmpty && clubs.isEmpty) {
      return _EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for anything',
        subtitle: 'Find players, teams, and leagues',
        isDark: isDark,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (players.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.whatshot_rounded, size: 18, color: _C.orange),
              const SizedBox(width: 6),
              const Text(
                'TRENDING PLAYERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _C.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${players.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...players.map((result) => _SearchResultTile(result: result, isDark: isDark)),
        ],

        if (players.isNotEmpty && clubs.isNotEmpty)
          const SizedBox(height: 16),

        if (clubs.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 18, color: _C.blue),
              const SizedBox(width: 6),
              const Text(
                'TRENDING CLUBS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _C.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${clubs.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...clubs.map((result) => _SearchResultTile(result: result, isDark: isDark)),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchResults(SearchResponse results, bool isFallback) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isFallback) _FallbackNotice(isDark: isDark),
        if (results.leagues.isNotEmpty) ...[
          _SectionHeader('LEAGUES', results.leagues.length),
          ...results.leagues.map((result) => _SearchResultTile(result: result, isDark: isDark)),
        ],
        if (results.teams.isNotEmpty) ...[
          if (results.leagues.isNotEmpty) const SizedBox(height: 16),
          _SectionHeader('TEAMS', results.teams.length),
          ...results.teams.map((result) => _SearchResultTile(result: result, isDark: isDark)),
        ],
        if (results.players.isNotEmpty) ...[
          if (results.teams.isNotEmpty || results.leagues.isNotEmpty)
            const SizedBox(height: 16),
          _SectionHeader('PLAYERS', results.players.length),
          ...results.players.map((result) => _SearchResultTile(result: result, isDark: isDark)),
        ],
      ],
    );
  }
}

// ─── Fallback Notice ─────────────────────────────────────────────────────────
// Shown above results when the live search API is unavailable/rate-limited
// and we're serving offline predefined data instead.

class _FallbackNotice extends StatelessWidget {
  final bool isDark;

  const _FallbackNotice({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.orange.withOpacity(isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _C.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live search is unavailable right now — showing popular suggestions instead.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? _C.darkText : _C.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader(this.title, this.count);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _C.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _C.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _C.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Result Tile ──────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final bool isDark;

  const _SearchResultTile({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? _C.darkSurface : _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? _C.darkBorder : _C.border),
        boxShadow: isDark
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(result: result, isDark: isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? _C.darkText : _C.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getSubtitle(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _C.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: result.type),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _C.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSubtitle() {
    switch (result.type) {
      case 'player':
        final parts = <String>[];
        if (result.position != null && result.position!.isNotEmpty) {
          parts.add(result.position!);
        }
        if (result.teamName != null && result.teamName!.isNotEmpty) {
          parts.add(result.teamName!);
        }
        if (result.jerseyNumber != null && result.jerseyNumber!.isNotEmpty) {
          parts.add('#${result.jerseyNumber}');
        }
        if (result.nationality != null && result.nationality!.isNotEmpty) {
          parts.add(result.nationality!);
        }
        return parts.isNotEmpty ? parts.join(' • ') : 'Player';
      case 'team':
        if (result.leagueName != null && result.leagueName!.isNotEmpty) {
          return result.leagueName!;
        }
        return 'Team';
      case 'league':
        return 'League';
      default:
        return '';
    }
  }

  void _onTap(BuildContext context) {
    final provider = context.read<AppProvider>();
    provider.clearSearch();

    switch (result.type) {
      case 'team':
        _navigateToTeam(context);
        break;
      case 'player':
        _navigateToPlayer(context);
        break;
      case 'league':
        _showLeagueInfo(context);
        break;
    }
  }

  void _navigateToTeam(BuildContext context) {
    final team = TeamInfo(
      id: result.id,
      name: result.name,
      displayName: result.displayName,
      abbreviation: result.abbreviation ??
          (result.name.length > 3 ? result.name.substring(0, 3).toUpperCase() : result.name.toUpperCase()),
      logo: result.imageUrl ?? 'https://a.espncdn.com/i/teamlogos/soccer/500/${result.id}.png',
      color: '#007AFF',  // AppTheme.primaryBlue
      alternateColor: '#FFFFFF',
      record: '0-0-0',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          team: team,
          leagueCode: result.leagueCode,
        ),
      ),
    );
  }

  void _navigateToPlayer(BuildContext context) {
    final pitchPlayer = PitchPlayer(
      id: result.id,
      name: result.displayName,
      shortName: result.displayName.split(' ').last,
      number: result.jerseyNumber ?? '',
      position: result.position ?? '',
      imageUrl: result.imageUrl,
      isStarter: true,
      isHome: true,
      rating: result.rating != null ? double.tryParse(result.rating!) : null,
    );

    TeamInfo? teamInfo;
    if (result.teamId != null && result.teamId!.isNotEmpty) {
      final clubData = seed.famousClubs.firstWhere(
            (c) => c['id'] == result.teamId,
        orElse: () => {'id': result.teamId!, 'name': result.teamName ?? 'Unknown Team'},
      );

      teamInfo = TeamInfo(
        id: clubData['id']!,
        name: clubData['name']!,
        displayName: clubData['name']!,
        abbreviation: clubData['name']!.length > 3
            ? clubData['name']!.substring(0, 3).toUpperCase()
            : clubData['name']!.toUpperCase(),
        logo: 'https://a.espncdn.com/i/teamlogos/soccer/500/${clubData['id']}.png',
        color: '#007AFF',  // AppTheme.primaryBlue
        alternateColor: '#FFFFFF',
        record: '0-0-0',
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          player: pitchPlayer,
          teamInfo: teamInfo,
          game: null,
          leagueCode: result.leagueCode,
        ),
      ),
    );
  }

  void _showLeagueInfo(BuildContext context) {
    final sheetIsDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: sheetIsDark ? _C.darkSurface : _C.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetIsDark ? _C.darkBorder : _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Avatar(result: result, size: 64, isDark: sheetIsDark),
            const SizedBox(height: 12),
            Text(
              result.displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: sheetIsDark ? _C.darkText : _C.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'League',
              style: TextStyle(
                fontSize: 14,
                color: _C.muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.blue,
                  foregroundColor: _C.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'VIEW STANDINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Avatar ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final SearchResult result;
  final double size;
  final bool isDark;

  const _Avatar({required this.result, this.size = 44, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? _C.darkBlueLight : _C.blueLight;

    String imageUrl = result.imageUrl ?? '';
    if (result.type == 'team' && result.id.isNotEmpty) {
      imageUrl = 'https://a.espncdn.com/i/teamlogos/soccer/500/${result.id}.png';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: isDark ? _C.darkBorder : _C.border, width: 1.5),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Placeholder(result: result, size: size, isDark: isDark),
          errorWidget: (_, __, ___) => _Placeholder(result: result, size: size, isDark: isDark),
        )
            : _Placeholder(result: result, size: size, isDark: isDark),
      ),
    );
  }
}

// ─── Placeholder ─────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final SearchResult result;
  final double size;
  final bool isDark;

  const _Placeholder({required this.result, required this.size, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    String text;
    if (result.type == 'player') {
      final parts = result.displayName.split(' ');
      text = parts.map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase();
    } else {
      text = result.displayName.isNotEmpty ? result.displayName[0].toUpperCase() : '?';
    }

    return Container(
      width: size,
      height: size,
      color: isDark ? _C.darkBlueLight : _C.blueLight,
      child: Center(
        child: Text(
          text.isNotEmpty ? (text.length > 2 ? text.substring(0, 2) : text) : '?',
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w800,
            color: _C.blue,
          ),
        ),
      ),
    );
  }
}

// ─── Type Badge ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'player': const Color(0xFF10B981),
      'team': const Color(0xFF1A62C8),
      'league': const Color(0xFF8B5CF6),
    };

    final labels = {
      'player': 'Player',
      'team': 'Team',
      'league': 'League',
    };

    final color = colors[type] ?? _C.muted;
    final label = labels[type] ?? type;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? _C.darkBlueLight : _C.blueLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                size: 36,
                color: _C.blue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? _C.darkText : _C.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _C.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
