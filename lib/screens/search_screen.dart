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

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const blue      = Color(0xFF1A62C8);
  static const blueLight = Color(0xFFE8F0FC);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF5F7FB);
  static const border    = Color(0xFFE2E8F2);
  static const text      = Color(0xFF0F1623);
  static const muted     = Color(0xFF6B7A96);
  static const green     = Color(0xFF16A34A);
  static const orange    = Color(0xFFF59E0B);
}

// ─── PREDEFINED FAMOUS PLAYERS WITH CLOUDINARY IMAGE URLs ──────────────────
const List<Map<String, dynamic>> famousPlayers = [
  {
    'id': '22774',
    'name': 'Cristiano Ronaldo',
    'teamName': 'Al Nassr',
    'teamId': '12765',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'Portugal',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784612724/62fa9c82669f48668f1dce7df614884b_pst8ln.jpg',
  },
  {
    'id': '45843',
    'name': 'Lionel Messi',
    'teamName': 'Inter Miami',
    'teamId': '16052',
    'position': 'FW',
    'jersey': '10',
    'nationality': 'Argentina',
    'imageUrl': 'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/45843.png&w=96&h=70&cb=1',
  },
  {
    'id': '231388',
    'name': 'Kylian Mbappé',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'France',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613639/5bcfbffeeca706844f78b3fb07b168af_mktcmp.jpg',
  },
  {
    'id': '253989',
    'name': 'Erling Haaland',
    'teamName': 'Manchester City',
    'teamId': '382',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'Norway',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784612927/0a8c8599fb5d8dc4268666d6cd376303_vd0ieu.jpg',
  },
  {
    'id': '362150',
    'name': 'Lamine Yamal',
    'teamName': 'Barcelona',
    'teamId': '83',
    'position': 'FW',
    'jersey': '19',
    'nationality': 'Spain',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613098/afbe98ac83049fec7a8f16be1df7e5fb_cpgcw3.jpg',
  },
  {
    'id': '291281',
    'name': 'Jude Bellingham',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'MF',
    'jersey': '5',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613715/735ce113be1b125fa453f10721d95b60_kblifj.jpg',
  },
  {
    'id': '142200',
    'name': 'Harry Kane',
    'teamName': 'Bayern Munich',
    'teamId': '132',
    'position': 'FW',
    'jersey': '9',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613085/32433dade363bf766c66aeff2f34efbc_rz3fp4.jpg',
  },
  {
    'id': '189281',
    'name': 'Ousmane Dembélé',
    'teamName': 'PSG',
    'teamId': '160',
    'position': 'FW',
    'jersey': '10',
    'nationality': 'France',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613084/c01348e00137360e854bdd89186d474c_anykow.jpg',
  },
  {
    'id': '270126',
    'name': 'Vinícius Júnior',
    'teamName': 'Real Madrid',
    'teamId': '86',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'Brazil',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613770/caba416e19a425b1285b73cd6466bd60_fx7so5.jpg',
  },
  {
    'id': '280903',
    'name': 'Bukayo Saka',
    'teamName': 'Arsenal',
    'teamId': '359',
    'position': 'FW',
    'jersey': '7',
    'nationality': 'England',
    'imageUrl': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1784613083/4b187e38059de04124d37a6139938e02_ljtp9a.jpg',
  },
];

// ─── PREDEFINED FAMOUS CLUBS ──────────────────────────────────────────────
const List<Map<String, String>> famousClubs = [
  {'id': '86', 'name': 'Real Madrid', 'league': 'esp.1', 'leagueName': 'La Liga'},
  {'id': '83', 'name': 'Barcelona', 'league': 'esp.1', 'leagueName': 'La Liga'},
  {'id': '359', 'name': 'Arsenal', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '360', 'name': 'Manchester United', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '382', 'name': 'Manchester City', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '160', 'name': 'PSG', 'league': 'fra.1', 'leagueName': 'Ligue 1'},
  {'id': '132', 'name': 'Bayern Munich', 'league': 'ger.1', 'leagueName': 'Bundesliga'},
  {'id': '111', 'name': 'Juventus', 'league': 'ita.1', 'leagueName': 'Serie A'},
  {'id': '363', 'name': 'Chelsea', 'league': 'eng.1', 'leagueName': 'Premier League'},
  {'id': '364', 'name': 'Liverpool', 'league': 'eng.1', 'leagueName': 'Premier League'},
];

// ─── Search Screen ───────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  SearchResponse _predefinedData = SearchResponse();
  String _lastSearchedQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _buildPredefinedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _buildPredefinedData() {
    final players = famousPlayers.map((p) {
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

    final clubs = famousClubs.map((c) {
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
    return Scaffold(
      backgroundColor: _C.offWhite,
      body: SafeArea(
        child: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              focusNode: _focusNode,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: _C.white,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.offWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
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
                color: _C.offWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSearch(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _C.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Search players, teams, leagues...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: _C.muted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  prefixIcon: GestureDetector(
                    onTap: onSearch,
                    child: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _C.muted,
                    ),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
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

  const _SearchResults({
    required this.predefinedData,
    required this.lastSearchedQuery,
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
      return _buildSearchResults(results);
    }

    if (query.isNotEmpty && results.isEmpty && !isSearching) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try searching with different keywords',
      );
    }

    if (query.isEmpty) {
      return _buildPredefinedData();
    }

    return const _EmptyState(
      icon: Icons.search_rounded,
      title: 'Search for anything',
      subtitle: 'Find players, teams, and leagues',
    );
  }

  Widget _buildPredefinedData() {
    final players = predefinedData.players;
    final clubs = predefinedData.teams;

    if (players.isEmpty && clubs.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for anything',
        subtitle: 'Find players, teams, and leagues',
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
          ...players.map((result) => _SearchResultTile(result: result)),
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
          ...clubs.map((result) => _SearchResultTile(result: result)),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSearchResults(SearchResponse results) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (results.leagues.isNotEmpty) ...[
          _SectionHeader('LEAGUES', results.leagues.length),
          ...results.leagues.map((result) => _SearchResultTile(result: result)),
        ],
        if (results.teams.isNotEmpty) ...[
          if (results.leagues.isNotEmpty) const SizedBox(height: 16),
          _SectionHeader('TEAMS', results.teams.length),
          ...results.teams.map((result) => _SearchResultTile(result: result)),
        ],
        if (results.players.isNotEmpty) ...[
          if (results.teams.isNotEmpty || results.leagues.isNotEmpty)
            const SizedBox(height: 16),
          _SectionHeader('PLAYERS', results.players.length),
          ...results.players.map((result) => _SearchResultTile(result: result)),
        ],
      ],
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

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
        boxShadow: [
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
                _Avatar(result: result),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.text,
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
      color: '#1A62C8',
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
      final clubData = famousClubs.firstWhere(
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
        color: '#1A62C8',
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
        ),
      ),
    );
  }

  void _showLeagueInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _Avatar(result: result, size: 64),
            const SizedBox(height: 12),
            Text(
              result.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _C.text,
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

  const _Avatar({required this.result, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final bgColor = _C.blueLight;

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
        border: Border.all(color: _C.border, width: 1.5),
      ),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Placeholder(result: result, size: size),
          errorWidget: (_, __, ___) => _Placeholder(result: result, size: size),
        )
            : _Placeholder(result: result, size: size),
      ),
    );
  }
}

// ─── Placeholder ─────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final SearchResult result;
  final double size;

  const _Placeholder({required this.result, required this.size});

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
      color: _C.blueLight,
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

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                color: _C.blueLight,
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
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _C.text,
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