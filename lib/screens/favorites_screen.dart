// lib/screens/favorites_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:livescore/models/search_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/user_preferences.dart';
import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/services/profile_service.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/utils/constants.dart';

// ── Custom Minimalist Confirmation Dialog ──────────────────────────────────

Future<bool?> _showRemoveConfirmationDialog(BuildContext context, String itemName) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.remove_circle_outline_rounded,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Remove Favorite',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1623),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              'Are you sure you want to remove "$itemName" from your favorites?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF15803D);
  static const Color _secondary = Color(0xFF1A62C8);
  static const Color _ink = Color(0xFF0F1623);
  static const Color _surface = Color(0xFFF8FAFC);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  UserProfile _profile = UserProfile.empty;

  final PreferencesService _prefsService = PreferencesService();
  final SportService _sportService = SportService();
  UserPreferences _preferences = UserPreferences();

  final Map<String, TeamInfo> _teamCache = {};
  bool _loadingTeamCache = false;

  List<TeamInfo> _allClubs = [];
  List<TeamInfo> _filteredClubs = [];
  String _clubSearchQuery = '';
  bool _isLoadingClubs = true;

  final List<Map<String, String>> _popularClubs = [
    {'id': '360', 'name': 'Manchester United', 'abbr': 'MUN', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/360.png'},
    {'id': '364', 'name': 'Liverpool', 'abbr': 'LIV', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/364.png'},
    {'id': '359', 'name': 'Arsenal', 'abbr': 'ARS', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png'},
    {'id': '363', 'name': 'Chelsea', 'abbr': 'CHE', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/363.png'},
    {'id': '382', 'name': 'Manchester City', 'abbr': 'MCI', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/382.png'},
    {'id': '367', 'name': 'Tottenham Hotspur', 'abbr': 'TOT', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/367.png'},
    {'id': '83', 'name': 'Barcelona', 'abbr': 'BAR', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/83.png'},
    {'id': '86', 'name': 'Real Madrid', 'abbr': 'RMA', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/86.png'},
    {'id': '1068', 'name': 'Atletico Madrid', 'abbr': 'ATM', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/1068.png'},
    {'id': '111', 'name': 'Juventus', 'abbr': 'JUV', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/111.png'},
    {'id': '103', 'name': 'AC Milan', 'abbr': 'MIL', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/103.png'},
    {'id': '110', 'name': 'Inter Milan', 'abbr': 'INT', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/110.png'},
    {'id': '132', 'name': 'Bayern Munich', 'abbr': 'BAY', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/132.png'},
    {'id': '124', 'name': 'Borussia Dortmund', 'abbr': 'DOR', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/124.png'},
    {'id': '160', 'name': 'Paris Saint-Germain', 'abbr': 'PSG', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/160.png'},
    {'id': '139', 'name': 'Ajax Amsterdam', 'abbr': 'AJA', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/139.png'},
    {'id': '437', 'name': 'Porto', 'abbr': 'POR', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/437.png'},
    {'id': '1929', 'name': 'Benfica', 'abbr': 'BEN', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/1929.png'},
    {'id': '20232', 'name': 'Inter Miami CF', 'abbr': 'MIA', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/20232.png'},
    {'id': '819', 'name': 'Flamengo', 'abbr': 'FLA', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/819.png'},
    {'id': '2029', 'name': 'Palmeiras', 'abbr': 'PAL', 'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/2029.png'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profile = ProfileService().profile;
    _preferences = _prefsService.preferences;
    _loadTeamCache();
    _loadClubs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadClubs() {
    setState(() {
      _allClubs = _popularClubs.map((t) {
        return TeamInfo(
          id: t['id']!,
          name: t['name']!,
          displayName: t['name']!,
          abbreviation: t['abbr']!,
          logo: t['logo']!,
          color: '#1A62C8',
          alternateColor: '#FFFFFF',
          record: '0-0-0',
        );
      }).toList();
      _filteredClubs = _allClubs;
      _isLoadingClubs = false;
    });
    _loadRemainingClubsInBackground();
  }

  Future<void> _loadRemainingClubsInBackground() async {
    final allLoadedClubs = <TeamInfo>[];
    final seenClubs = <String>{};
    for (final club in _allClubs) {
      seenClubs.add(club.displayName.trim().toLowerCase());
    }
    for (final league in AppConstants.priorityLeagues) {
      try {
        _sportService.setLeague(league['code']!);
        final teams = await _sportService.getAllTeams().timeout(
          const Duration(seconds: 3),
          onTimeout: () => <TeamInfo>[],
        );
        for (final t in teams) {
          final normalizedName = t.displayName.trim().toLowerCase();
          if (!seenClubs.contains(normalizedName)) {
            seenClubs.add(normalizedName);
            allLoadedClubs.add(t);
          }
        }
      } catch (e) {
        debugPrint('Error loading ${league['name']}: $e');
      }
    }
    if (mounted) {
      setState(() {
        _allClubs = [..._allClubs, ...allLoadedClubs];
        _filterClubs(_clubSearchQuery);
      });
    }
  }

  void _filterClubs(String query) {
    setState(() {
      _clubSearchQuery = query;
      _filteredClubs = query.isEmpty
          ? _allClubs
          : _allClubs.where((t) {
        return t.displayName.toLowerCase().contains(query.toLowerCase()) ||
            t.name.toLowerCase().contains(query.toLowerCase()) ||
            t.abbreviation.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  String _getValidLogoUrl(TeamInfo team) {
    if (team.logo.startsWith('http')) {
      return team.logo;
    }
    return 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png';
  }

  Future<void> _loadTeamCache() async {
    if (_loadingTeamCache) return;
    _loadingTeamCache = true;
    for (final league in AppConstants.priorityLeagues) {
      try {
        _sportService.setLeague(league['code']!);
        final teams = await _sportService.getAllTeams().timeout(
          const Duration(seconds: 3),
          onTimeout: () => <TeamInfo>[],
        );
        for (final t in teams) {
          _teamCache[t.id] = t;
        }
        if (mounted) setState(() {});
      } catch (_) {}
    }
    _loadingTeamCache = false;
  }

  void _refreshPreferences() {
    if (!mounted) return;
    setState(() {
      _preferences = _prefsService.preferences;
    });
  }

  Future<void> _removeFavoriteTeamId(String id) async {
    final team = _teamCache[id];
    final teamName = team?.displayName ?? 'this team';
    final confirm = await _showRemoveConfirmationDialog(context, teamName);
    if (confirm == true) {
      await _prefsService.removeFavoriteTeam(id);
      _refreshPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$teamName removed from favorites'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleClubSelection(String clubId) async {
    if (_prefsService.isTeamFavorite(clubId)) {
      final club = _allClubs.firstWhere(
            (c) => c.id == clubId,
        orElse: () => TeamInfo(
          id: clubId,
          name: 'this club',
          displayName: 'this club',
          abbreviation: 'CLB',
          logo: '',
          color: '',
          alternateColor: '',
          record: '',
        ),
      );
      final confirm = await _showRemoveConfirmationDialog(context, club.displayName);
      if (confirm == true) {
        await _prefsService.removeFavoriteTeam(clubId);
        _refreshPreferences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${club.displayName} removed from favorites'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      final club = _allClubs.firstWhere(
            (c) => c.id == clubId,
        orElse: () => TeamInfo(
          id: clubId,
          name: 'Club',
          displayName: 'Club',
          abbreviation: 'CLB',
          logo: '',
          color: '',
          alternateColor: '',
          record: '',
        ),
      );
      await _prefsService.addFavoriteTeam(clubId);
      _refreshPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${club.displayName} added to favorites'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavoriteTeamId(String id) async {
    if (_prefsService.isTeamFavorite(id)) {
      await _prefsService.removeFavoriteTeam(id);
    } else {
      await _prefsService.addFavoriteTeam(id);
    }
    _refreshPreferences();
  }

  void _openManageTeamsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ManageFavoriteTeamsSheet(
        teamCache: _teamCache,
        isFavorite: (id) => _prefsService.isTeamFavorite(id),
        onToggle: _toggleFavoriteTeamId,
      ),
    ).then((_) => _refreshPreferences());
  }

  void _showCapReachedSnackbar(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You can only have up to 4 favorite $category'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _addFavoritePlayer(SearchResult player) async {
    final added = await _prefsService.addFavoritePlayer({
      'id': player.id,
      'name': player.displayName,
      'image': player.displayImageUrl,
      'team': player.teamName ?? '',
    });
    if (!added) {
      if (_prefsService.isPlayerFavorite(player.id)) return;
      _showCapReachedSnackbar('players');
      return;
    }
    _refreshPreferences();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${player.displayName} added to favorites'),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _removeFavoritePlayer(String playerId, String playerName) async {
    final confirm = await _showRemoveConfirmationDialog(context, playerName);
    if (confirm == true) {
      await _prefsService.removeFavoritePlayer(playerId);
      _refreshPreferences();
    }
  }

  Future<void> _toggleFavoriteLeague(String leagueCode, String leagueName) async {
    if (_prefsService.isLeagueFavorite(leagueCode)) {
      final confirm = await _showRemoveConfirmationDialog(context, leagueName);
      if (confirm == true) {
        await _prefsService.removeFavoriteLeague(leagueCode);
        _refreshPreferences();
      }
    } else {
      final added = await _prefsService.addFavoriteLeague(leagueCode);
      if (!added) {
        _showCapReachedSnackbar('leagues');
        return;
      }
      _refreshPreferences();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$leagueName added to favorites'),
            backgroundColor: _primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 32,
                color: _primary,
              ),
            ),
            onPressed: () => Navigator.pop(context, _profile),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Favorites',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 25,
                letterSpacing: -0.8,
                color: _ink,
                height: 1.1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Manage your favorite teams, clubs & players',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: Color(0xFF6B7A96),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: _primary,
              size: 22,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(0),
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isSelected = _tabController.index == 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? _primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? _primary : Colors.grey.shade500,
                                letterSpacing: -0.3,
                              ),
                              child: const Text('Clubs'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(1),
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isSelected = _tabController.index == 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? _primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? _primary : Colors.grey.shade500,
                                letterSpacing: -0.3,
                              ),
                              child: const Text('Players'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _tabController.animateTo(2),
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isSelected = _tabController.index == 2;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected ? _primary : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? _primary : Colors.grey.shade500,
                                letterSpacing: -0.3,
                              ),
                              child: const Text('Leagues'),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _FavoriteTeamsBanner(
              teamIds: _preferences.favoriteTeamIds,
              teamCache: _teamCache,
              onManage: _openManageTeamsSheet,
              onRemove: _removeFavoriteTeamId,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: MediaQuery.of(context).size.height - 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ClubSelectionGrid(
                    clubs: _filteredClubs,
                    selectedClubIds: _preferences.favoriteTeamIds,
                    isLoading: _isLoadingClubs,
                    searchQuery: _clubSearchQuery,
                    onSearchChanged: _filterClubs,
                    onToggle: _toggleClubSelection,
                  ),
                  _PlayerResultsTab(
                    favoritePlayers: _preferences.favoritePlayers,
                    onSelect: _addFavoritePlayer,
                    onRemove: _removeFavoritePlayer,
                  ),
                  _LeagueSelectionGrid(
                    favoriteLeagueCodes: _preferences.favoriteLeagueIds,
                    onToggle: _toggleFavoriteLeague,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Club Selection Grid ────────────────────────────────────────────────────

class _ClubSelectionGrid extends StatelessWidget {
  final List<TeamInfo> clubs;
  final List<String> selectedClubIds;
  final bool isLoading;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onToggle;

  const _ClubSelectionGrid({
    required this.clubs,
    required this.selectedClubIds,
    required this.isLoading,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onToggle,
  });

  static const Color _primary = Color(0xFF16A34A);

  String _getValidLogoUrl(TeamInfo team) {
    if (team.logo.startsWith('http')) {
      return team.logo;
    }
    return 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F1623)),
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E9AAF), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              ),
            ),
          ),
        ),
        if (selectedClubIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${selectedClubIds.length} club${selectedClubIds.length == 1 ? '' : 's'} selected',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              color: _primary,
              strokeWidth: 3,
            ),
          )
              : clubs.isEmpty
              ? const _EmptySearchHint(
            icon: Icons.sports_soccer_rounded,
            text: 'No clubs found',
          )
              : GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              final isSelected = selectedClubIds.contains(club.id);
              final logoUrl = _getValidLogoUrl(club);

              return GestureDetector(
                onTap: () => onToggle(club.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primary.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? _primary : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: logoUrl,
                        width: 55,
                        height: 55,
                        imageBuilder: (context, imageProvider) {
                          return Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                        placeholder: (context, url) {
                          return Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade200,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        errorWidget: (context, url, error) {
                          return Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primary.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                club.abbreviation.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        club.abbreviation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? _primary : const Color(0xFF0F1623),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          club.displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_circle,
                            color: _primary,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Player Results Tab ─────────────────────────────────────────────────────

class _PlayerResultsTab extends StatelessWidget {
  final List<Map<String, String>> favoritePlayers;
  final ValueChanged<SearchResult> onSelect;
  final void Function(String playerId, String playerName) onRemove;

  const _PlayerResultsTab({
    required this.favoritePlayers,
    required this.onSelect,
    required this.onRemove,
  });

  static const Color _primary = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final query = provider.searchResults;
        final showEmptyState = !provider.isSearching && query.players.isEmpty;
        final favoriteIds = favoritePlayers.map((p) => p['id']).toSet();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (favoritePlayers.isNotEmpty) ...[
              Text(
                '${favoritePlayers.length}/4 Favorite Players',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0F1623),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favoritePlayers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final p = favoritePlayers[i];
                    return _FavoritePlayerChip(
                      name: p['name'] ?? '',
                      imageUrl: p['image'] ?? '',
                      onRemove: () => onRemove(p['id'] ?? '', p['name'] ?? 'this player'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (query) => provider.searchWithDebounce(query),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F1623)),
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E9AAF), size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (provider.isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                    strokeWidth: 3,
                  ),
                ),
              )
            else if (showEmptyState)
              const _EmptySearchHint(
                icon: Icons.person_rounded,
                text: 'Search for a player to set as your favorite',
              )
            else
              ...query.players.map((player) {
                final isFav = favoriteIds.contains(player.id);
                return _SearchResultTile(
                  result: player,
                  isSelected: isFav,
                  onTap: () => isFav ? onRemove(player.id, player.displayName) : onSelect(player),
                );
              }),
          ],
        );
      },
    );
  }
}

// ── Current Favorite Card ──────────────────────────────────────────────────

class _CurrentFavoriteCard extends StatelessWidget {
  final String title;
  final String name;
  final String imageUrl;
  final VoidCallback onClear;

  const _CurrentFavoriteCard({
    required this.title,
    required this.name,
    required this.imageUrl,
    required this.onClear,
  });

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.white.withOpacity(0.1),
                  child: const Icon(Icons.sports_soccer_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Result Tile ─────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;
  final bool isSelected;

  const _SearchResultTile({required this.result, required this.onTap, this.isSelected = false});

  static const Color _primary = Color(0xFF16A34A);
  static const Color _secondary = Color(0xFF1A62C8);
  static const Color _ink = Color(0xFF0F1623);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: _primary.withOpacity(0.05),
          highlightColor: _primary.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: result.displayImageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 44,
                        height: 44,
                        color: _secondary.withOpacity(0.08),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            result.initials,
                            style: const TextStyle(
                              color: _secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    color: _primary,
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty Search Hint ──────────────────────────────────────────────────────

class _EmptySearchHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySearchHint({required this.icon, required this.text});

  static const Color _primary = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: _primary.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Favorite Teams Banner ──────────────────────────────────────────────────

class _FavoriteTeamsBanner extends StatelessWidget {
  final List<String> teamIds;
  final Map<String, TeamInfo> teamCache;
  final VoidCallback onManage;
  final ValueChanged<String> onRemove;

  const _FavoriteTeamsBanner({
    required this.teamIds,
    required this.teamCache,
    required this.onManage,
    required this.onRemove,
  });

  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF15803D);
  static const Color _secondary = Color(0xFF1A62C8);
  static const Color _ink = Color(0xFF0F1623);

  @override
  Widget build(BuildContext context) {
    final hasTeams = teamIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasTeams ? [_primary, _primaryDark] : [Colors.grey.shade50, Colors.grey.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (hasTeams ? _primary : Colors.grey.shade300).withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hasTeams ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasTeams ? Icons.star_rounded : Icons.info_outline_rounded,
                    color: hasTeams ? Colors.white : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasTeams
                        ? '${teamIds.length} Favorite Team${teamIds.length == 1 ? '' : 's'}'
                        : 'No favorite teams yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: hasTeams ? Colors.white : _ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: hasTeams ? Colors.white.withOpacity(0.2) : _secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: onManage,
                    style: TextButton.styleFrom(
                      foregroundColor: hasTeams ? Colors.white : _secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      hasTeams ? 'Manage' : 'Add Teams',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasTeams) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: teamIds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final id = teamIds[i];
                    final team = teamCache[id];
                    return _FavoriteTeamChip(
                      id: id,
                      team: team,
                      onRemove: () => onRemove(id),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FavoriteTeamChip extends StatelessWidget {
  final String id;
  final TeamInfo? team;
  final VoidCallback onRemove;

  const _FavoriteTeamChip({required this.id, required this.team, required this.onRemove});

  static const Color _primary = Color(0xFF16A34A);

  String get _logoUrl {
    final logo = team?.logo ?? '';
    if (logo.startsWith('http')) return logo;
    return 'https://a.espncdn.com/i/teamlogos/soccer/500/$id.png';
  }

  @override
  Widget build(BuildContext context) {
    final label = team?.abbreviation.isNotEmpty == true
        ? team!.abbreviation
        : (team?.displayName ?? 'Team');

    return SizedBox(
      width: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: _logoUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Container(
                      width: 36,
                      height: 36,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 10, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Favorite Player Chip ───────────────────────────────────────────────────

class _FavoritePlayerChip extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onRemove;

  const _FavoritePlayerChip({required this.name, required this.imageUrl, required this.onRemove});

  static const Color _primary = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 36,
                      height: 36,
                      color: _primary.withOpacity(0.08),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.person, color: _primary, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1623),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
                ),
                child: const Icon(Icons.close, size: 10, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manage Favorite Teams Sheet ───────────────────────────────────────────

class _ManageFavoriteTeamsSheet extends StatefulWidget {
  final Map<String, TeamInfo> teamCache;
  final bool Function(String id) isFavorite;
  final Future<void> Function(String id) onToggle;

  const _ManageFavoriteTeamsSheet({
    required this.teamCache,
    required this.isFavorite,
    required this.onToggle,
  });

  @override
  State<_ManageFavoriteTeamsSheet> createState() => _ManageFavoriteTeamsSheetState();
}

class _ManageFavoriteTeamsSheetState extends State<_ManageFavoriteTeamsSheet> {
  static const Color _primary = Color(0xFF16A34A);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final teams = widget.teamCache.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final filtered = _query.isEmpty
        ? teams
        : teams.where((t) => t.displayName.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Manage Favorite Teams',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.5,
                          color: Color(0xFF0F1623),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search teams...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: _primary,
                  ),
                )
                    : GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final team = filtered[index];
                    final selected = widget.isFavorite(team.id);
                    return GestureDetector(
                      onTap: () async {
                        await widget.onToggle(team.id);
                        setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected ? _primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? _primary : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                            BoxShadow(
                              color: _primary.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: team.logo.startsWith('http')
                                      ? team.logo
                                      : 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey.shade100,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 44,
                                    height: 44,
                                    color: _primary.withOpacity(0.08),
                                    child: Center(
                                      child: Text(
                                        team.abbreviation.isNotEmpty ? team.abbreviation.substring(0, 1) : '?',
                                        style: const TextStyle(
                                          color: _primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              team.displayName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? _primary : Colors.grey.shade800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.check_circle, color: _primary, size: 14),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
// ── League Selection Grid ──────────────────────────────────────────────────

class _LeagueSelectionGrid extends StatelessWidget {
  final List<String> favoriteLeagueCodes;
  final void Function(String leagueCode, String leagueName) onToggle;

  const _LeagueSelectionGrid({
    required this.favoriteLeagueCodes,
    required this.onToggle,
  });

  static const Color _primary = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final leagues = AppConstants.popularLeagues;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: leagues.length,
      itemBuilder: (context, index) {
        final league = leagues[index];
        final code = league['code']!;
        final name = league['name'] ?? code;
        final selected = favoriteLeagueCodes.contains(code);

        return GestureDetector(
          onTap: () => onToggle(code, name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _primary : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(league['flag'] ?? '⚽', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected ? _primary : const Color(0xFF0F1623),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        league['country'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? _primary : Colors.grey.shade300,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}