import 'dart:async';
import 'package:flutter/material.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/services/sportsdb_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/user_preferences.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/utils/predefined_data.dart';
import 'package:livescore/models/search_model.dart';
import 'package:livescore/screens/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Onboarding uses the app's green brand color (matches favorites_screen.dart
/// and home_screen.dart) rather than the older AppTheme.primaryBlue.
const Color _kGreen = Color(0xFF16A34A);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final SportService _sportService = SportService();
  final PreferencesService _prefs = PreferencesService();

  List<TeamInfo> _allTeams = [];
  List<TeamInfo> _filteredTeams = [];
  List<String> _selectedTeamIds = [];
  String _searchQuery = '';
  bool _isLoading = true;
  int _currentStep = 0;

  List<String> _selectedLeagueCodes = [];

  /// Each entry has 'id', 'name', 'image', 'team' — populated either from
  /// the famousPlayers seed list or from a live search result, since search
  /// results have no local id->data table to look up later.
  List<Map<String, String>> _selectedPlayers = [];

  // Live player search (same SportService.search() pipeline — ESPN primary,
  // TheSportsDB/API-Football fallback — used elsewhere in the app) so users
  // aren't limited to the small famousPlayers seed list.
  final TextEditingController _playerSearchController = TextEditingController();
  Timer? _playerSearchDebounce;
  SearchResponse _playerSearchResults = SearchResponse();
  bool _isSearchingPlayers = false;
  String _playerSearchQuery = '';

  // 0 = Teams, 1 = Players, 2 = Leagues
  static const int _stepCount = 3;
  static const int maxSelectionsPerCategory = 4;

  // VERIFIED ESPN TEAM IDS
  final List<Map<String, String>> _popularTeams = [

    // Premier League
    {
      'id': '360',
      'name': 'Manchester United',
      'abbr': 'MUN',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/360.png'
    },
    {
      'id': '364',
      'name': 'Liverpool',
      'abbr': 'LIV',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/364.png'
    },
    {
      'id': '359',
      'name': 'Arsenal',
      'abbr': 'ARS',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/359.png'
    },
    {
      'id': '363',
      'name': 'Chelsea',
      'abbr': 'CHE',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/363.png'
    },
    {
      'id': '382',
      'name': 'Manchester City',
      'abbr': 'MCI',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/382.png'
    },
    {
      'id': '367',
      'name': 'Tottenham Hotspur',
      'abbr': 'TOT',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/367.png'
    },

    // La Liga
    {
      'id': '83',
      'name': 'Barcelona',
      'abbr': 'BAR',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/83.png'
    },
    {
      'id': '86',
      'name': 'Real Madrid',
      'abbr': 'RMA',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/86.png'
    },
    {
      'id': '1068',
      'name': 'Atletico Madrid',
      'abbr': 'ATM',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/1068.png'
    },

    // Serie A
    {
      'id': '111',
      'name': 'Juventus',
      'abbr': 'JUV',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/111.png'
    },
    {
      'id': '103',
      'name': 'AC Milan',
      'abbr': 'MIL',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/103.png'
    },
    {
      'id': '110',
      'name': 'Inter Milan',
      'abbr': 'INT',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/110.png'
    },

    // Bundesliga
    {
      'id': '132',
      'name': 'Bayern Munich',
      'abbr': 'BAY',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/132.png'
    },
    {
      'id': '124',
      'name': 'Borussia Dortmund',
      'abbr': 'DOR',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/124.png'
    },

    // Ligue 1
    {
      'id': '160',
      'name': 'Paris Saint-Germain',
      'abbr': 'PSG',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/160.png'
    },

    // Eredivisie
    {
      'id': '139',
      'name': 'Ajax',
      'abbr': 'AJA',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/139.png'
    },

    // Primeira Liga
    {
      'id': '437',
      'name': 'Porto',
      'abbr': 'POR',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/437.png'
    },
    {
      'id': '1929',
      'name': 'Benfica',
      'abbr': 'BEN',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/1929.png'
    },

    // MLS
    {
      'id': '20232',
      'name': 'Inter Miami CF',
      'abbr': 'MIA',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/20232.png'
    },

    // Brazil
    {
      'id': '819',
      'name': 'Flamengo',
      'abbr': 'FLA',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/819.png'
    },
    {
      'id': '2029',
      'name': 'Palmeiras',
      'abbr': 'PAL',
      'logo': 'https://a.espncdn.com/i/teamlogos/soccer/500/2029.png'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTeamsProgressive();
  }

  @override
  void dispose() {
    _playerSearchDebounce?.cancel();
    _playerSearchController.dispose();
    super.dispose();
  }

  void _loadTeamsProgressive() {
    setState(() {
      _allTeams = _popularTeams.map((t) {
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

      _filteredTeams = _allTeams;
      _isLoading = false;
    });

    _loadRemainingTeamsInBackground();
  }

  Future<void> _loadRemainingTeamsInBackground() async {
    final allLoadedTeams = <TeamInfo>[];

    // FIXED DUPLICATE FILTERING
    final seenTeams = <String>{};

    for (final team in _allTeams) {
      seenTeams.add(team.displayName.trim().toLowerCase());
    }

    final leaguesToFetch = AppConstants.priorityLeagues;

    for (final league in leaguesToFetch) {
      try {
        _sportService.setLeague(league['code']!);

        final teams = await _sportService.getAllTeams().timeout(
          const Duration(seconds: 3),
          onTimeout: () => <TeamInfo>[],
        );

        for (final t in teams) {
          final normalizedName =
          t.displayName.trim().toLowerCase();

          if (!seenTeams.contains(normalizedName)) {
            seenTeams.add(normalizedName);
            allLoadedTeams.add(t);
          }
        }
      } catch (e) {
        debugPrint('Error loading ${league['name']}: $e');
      }
    }

    if (mounted) {
      setState(() {
        _allTeams = [..._allTeams, ...allLoadedTeams];

        _filteredTeams = _searchQuery.isEmpty
            ? _allTeams
            : _allTeams.where((t) {
          return t.displayName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
              t.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              t.abbreviation
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
        }).toList();
      });
    }
  }

  void _filterTeams(String query) {
    setState(() {
      _searchQuery = query;

      _filteredTeams = query.isEmpty
          ? _allTeams
          : _allTeams.where((t) {
        return t.displayName
            .toLowerCase()
            .contains(query.toLowerCase()) ||
            t.name
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            t.abbreviation
                .toLowerCase()
                .contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showCapReachedSnackbar(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You can select up to $maxSelectionsPerCategory $category'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleTeamSelection(String teamId) {
    if (!_selectedTeamIds.contains(teamId) && _selectedTeamIds.length >= maxSelectionsPerCategory) {
      _showCapReachedSnackbar('clubs');
      return;
    }
    setState(() {
      if (_selectedTeamIds.contains(teamId)) {
        _selectedTeamIds.remove(teamId);
      } else {
        _selectedTeamIds.add(teamId);
      }
    });
  }

  bool _isPlayerSelected(String playerId) => _selectedPlayers.any((p) => p['id'] == playerId);

  void _togglePlayerSelection(Map<String, String> player) {
    final id = player['id'];
    if (id == null) return;
    final alreadySelected = _isPlayerSelected(id);
    if (!alreadySelected && _selectedPlayers.length >= maxSelectionsPerCategory) {
      _showCapReachedSnackbar('players');
      return;
    }
    setState(() {
      if (alreadySelected) {
        _selectedPlayers.removeWhere((p) => p['id'] == id);
      } else {
        _selectedPlayers.add(player);
      }
    });
  }

  void _searchPlayersWithDebounce(String query) {
    _playerSearchDebounce?.cancel();
    _playerSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlayers(query);
    });
  }

  Future<void> _searchPlayers(String query) async {
    setState(() => _playerSearchQuery = query);
    if (query.trim().isEmpty) {
      setState(() {
        _playerSearchResults = SearchResponse();
        _isSearchingPlayers = false;
      });
      return;
    }
    setState(() => _isSearchingPlayers = true);
    try {
      // Same ESPN / TheSportsDB / API-Football search pipeline used
      // everywhere else in the app (favorites_screen.dart's Players tab),
      // so results here have real, accurate player ids — not limited to
      // the small local famousPlayers seed list.
      final results = await _sportService.search(query);
      if (!mounted) return;
      setState(() {
        _playerSearchResults = results;
        _isSearchingPlayers = false;
      });
    } catch (e) {
      debugPrint('Error searching players: $e');
      if (!mounted) return;
      setState(() => _isSearchingPlayers = false);
    }
  }

  void _toggleLeagueSelection(String leagueCode) {
    if (!_selectedLeagueCodes.contains(leagueCode) && _selectedLeagueCodes.length >= maxSelectionsPerCategory) {
      _showCapReachedSnackbar('leagues');
      return;
    }
    setState(() {
      if (_selectedLeagueCodes.contains(leagueCode)) {
        _selectedLeagueCodes.remove(leagueCode);
      } else {
        _selectedLeagueCodes.add(leagueCode);
      }
    });
  }

  Future<void> _completeOnboarding() async {
    final preferences = UserPreferences(
      favoriteTeamIds: _selectedTeamIds,
      favoriteLeagueIds: _selectedLeagueCodes,
      favoritePlayers: _selectedPlayers,
      hasCompletedOnboarding: true,
    );

    await _prefs.savePreferences(preferences);

    if (mounted) {
      // Use named route navigation instead of pushing new instance
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  String _getValidLogoUrl(TeamInfo team) {
    if (team.logo.startsWith('http')) {
      return team.logo;
    }

    return 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png';
  }

  String _getLeagueLogoId(String code) {
    const leagueLogoMap = {

      // Top European Leagues
      'eng.1': '23',
      'esp.1': '15',
      'ita.1': '12',
      'ger.1': '10',
      'fra.1': '9',
      'por.1': '14',
      'ned.1': '11',
      'bel.1': '6',
      'sco.1': '83',
      'tur.1': '63',
      'aut.1': '56',
      'sui.1': '57',

      // Americas
      'usa.1': '19',
      'mex.1': '22',
      'bra.1': '85',
      'arg.1': '1',

      // Asia
      'jpn.1': '25',

      // Scandinavia
      'swe.1': '28',
      'nor.1': '30',
      'den.1': '8',

      // UEFA
      'uefa.champions': '2',
      'uefa.europa': '2310',
      'uefa.conference': '2311',

      // South America
      'conmebol.libertadores': '58',
      'conmebol.sudamericana': '59',
    };

    return leagueLogoMap[code] ?? '23';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: Text(
          switch (_currentStep) {
            0 => 'Choose Your Teams',
            1 => 'Choose Your Players',
            _ => 'Choose Your Leagues',
          },
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _kGreen,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: _kGreen,
          ),
          onPressed: () {
            setState(() {
              _currentStep -= 1;
            });
          },
        )
            : null,
      ),

      body: Column(
        children: [

          Expanded(
            child: switch (_currentStep) {
              0 => _buildTeamSelectionStep(),
              1 => _buildPlayerSelectionStep(),
              _ => _buildLeagueSelectionStep(),
            },
          ),

          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final isLastStep = _currentStep == _stepCount - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

      child: SizedBox(
        width: double.infinity,
        height: 52,

        child: ElevatedButton(
          onPressed: isLastStep
              ? _completeOnboarding
              : () {
            setState(() {
              _currentStep += 1;
            });
          },

          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.white,
            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),

          child: Text(
            isLastStep ? 'Get Started' : 'Continue',

            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamSelectionStep() {
    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),

          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search clubs...',
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),

              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 0),
            ),

            onChanged: _filterTeams,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),

          child: Row(
            children: [

              Text(
                '${_selectedTeamIds.length}/$maxSelectionsPerCategory clubs selected',
                style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const Spacer(),

              if (_selectedTeamIds.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTeamIds.clear();
                    });
                  },

                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),

            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),

            itemCount: _filteredTeams.length,

            itemBuilder: (context, index) {
              final team = _filteredTeams[index];

              final isSelected =
              _selectedTeamIds.contains(team.id);

              final logoUrl = _getValidLogoUrl(team);

              return GestureDetector(
                onTap: () {
                  _toggleTeamSelection(team.id);
                },

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),

                  decoration: BoxDecoration(
                    color: isSelected
                        ? _kGreen.withOpacity(0.08)
                        : Colors.grey.shade50,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(
                      color: isSelected
                          ? _kGreen
                          : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                  ),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      CachedNetworkImage(
                        imageUrl: logoUrl,
                        width: 55,
                        height: 55,

                        imageBuilder:
                            (context, imageProvider) {
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

                        errorWidget:
                            (context, url, error) {
                          return Container(
                            width: 55,
                            height: 55,

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGreen
                                  .withOpacity(0.1),
                            ),

                            child: Center(
                              child: Text(
                                team.abbreviation
                                    .substring(0, 1)
                                    .toUpperCase(),

                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                  _kGreen,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      Text(
                        team.abbreviation,
                        textAlign: TextAlign.center,

                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kGreen,
                        ),

                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      Padding(
                        padding:
                        const EdgeInsets.symmetric(
                            horizontal: 6),

                        child: Text(
                          team.displayName,
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                          ),

                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      if (isSelected)
                        const Padding(
                          padding:
                          EdgeInsets.only(top: 4),

                          child: Icon(
                            Icons.check_circle,
                            color: _kGreen,
                            size: 16,
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

  Widget _buildPlayerSelectionStep() {
    final showingSearch = _playerSearchQuery.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _playerSearchController,
            decoration: InputDecoration(
              hintText: 'Search any player...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _playerSearchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                onPressed: () {
                  _playerSearchController.clear();
                  _searchPlayers('');
                },
              )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: _searchPlayersWithDebounce,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_selectedPlayers.length}/$maxSelectionsPerCategory players selected',
                style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_selectedPlayers.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPlayers.clear();
                    });
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        if (_selectedPlayers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPlayers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = _selectedPlayers[i];
                  return Chip(
                    label: Text(p['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.check_circle, color: _kGreen, size: 16),
                    backgroundColor: _kGreen.withOpacity(0.08),
                    onDeleted: () => _togglePlayerSelection(p),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: showingSearch
              ? _buildPlayerSearchResults()
              : GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            // Full top-100 seed list (predefined_data.dart) rather than a
            // 10-player slice — Ronaldo and Messi stay first since that's
            // how they're ordered in the seed list itself.
            itemCount: famousPlayers.length,
            itemBuilder: (context, index) {
              final player = famousPlayers[index];
              final id = player['id'] as String;
              final name = player['name'] as String;
              final isSelected = _isPlayerSelected(id);
              return _OnboardingPlayerTile(
                name: name,
                team: player['teamName'] as String,
                // predefined_data.dart's `imageUrl` (the res.cloudinary
                // links) is search_screen's own fallback set and isn't
                // used here — onboarding resolves every player's headshot
                // itself, uniformly, via ESPN + TheSportsDB below.
                isSelected: isSelected,
                onTap: () async {
                  // By the time the user taps a visible tile, the same
                  // lookup has usually already completed for its avatar
                  // (both go through the same memoized resolver), so this
                  // normally resolves instantly from cache rather than
                  // making a fresh request.
                  final image = await _PlayerImageResolver.resolve(name) ?? '';
                  _togglePlayerSelection({
                    'id': id,
                    'name': name,
                    'image': image,
                    'team': player['teamName'] as String,
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSearchResults() {
    if (_isSearchingPlayers) {
      return const Center(child: CircularProgressIndicator(color: _kGreen));
    }
    final results = _playerSearchResults.players;
    if (results.isEmpty) {
      return Center(
        child: Text(
          'No players found for "$_playerSearchQuery"',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final player = results[index];
        final isSelected = _isPlayerSelected(player.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isSelected ? _kGreen.withOpacity(0.06) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? _kGreen : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: player.displayImageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(width: 40, height: 40, color: Colors.grey.shade200),
                errorWidget: (context, url, error) => Container(
                  width: 40,
                  height: 40,
                  color: _kGreen.withOpacity(0.1),
                  child: Center(child: Text(player.initials, style: const TextStyle(color: _kGreen, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            title: Text(player.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(player.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            trailing: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? _kGreen : Colors.grey.shade400,
            ),
            onTap: () => _togglePlayerSelection({
              'id': player.id,
              'name': player.displayName,
              'image': player.displayImageUrl,
              'team': player.teamName ?? '',
            }),
          ),
        );
      },
    );
  }

  Widget _buildLeagueSelectionStep() {
    final allLeaguesForDisplay = [
      ...AppConstants.priorityLeagues,
      ...AppConstants.majorClubCompetitions,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${_selectedLeagueCodes.length}/$maxSelectionsPerCategory leagues selected',
                style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_selectedLeagueCodes.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedLeagueCodes.clear();
                    });
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildLeagueList(allLeaguesForDisplay)),
      ],
    );
  }

  Widget _buildLeagueList(List<Map<String, String>> allLeaguesForDisplay) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: allLeaguesForDisplay.length,

      itemBuilder: (context, index) {
        final league = allLeaguesForDisplay[index];
        final code = league['code']!;

        final isSelected =
        _selectedLeagueCodes.contains(code);

        return GestureDetector(
          onTap: () => _toggleLeagueSelection(code),

          child: Container(
            margin: const EdgeInsets.only(bottom: 12),

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: isSelected
                  ? _kGreen.withOpacity(0.08)
                  : Colors.grey.shade50,

              borderRadius: BorderRadius.circular(16),

              border: Border.all(
                color: isSelected
                    ? _kGreen
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),

            child: Row(
              children: [

                CachedNetworkImage(
                  imageUrl:
                  'https://a.espncdn.com/i/leaguelogos/soccer/500/${_getLeagueLogoId(code)}.png',

                  width: 42,
                  height: 42,

                  imageBuilder: (context, imageProvider) {
                    return Container(
                      width: 42,
                      height: 42,

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
                      width: 42,
                      height: 42,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),

                      child: Center(
                        child: Text(
                          league['flag'] ?? '⚽',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  },

                  errorWidget: (context, url, error) {
                    return Container(
                      width: 42,
                      height: 42,

                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kGreen.withOpacity(0.1),
                      ),

                      child: Center(
                        child: Text(
                          league['flag'] ?? '⚽',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Text(
                        league['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        league['country'] ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.circle_outlined,

                  color: isSelected
                      ? _kGreen
                      : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Onboarding Player Tile ─────────────────────────────────────────────────

class _OnboardingPlayerTile extends StatelessWidget {
  final String name;
  final String team;
  final bool isSelected;
  final VoidCallback onTap;

  const _OnboardingPlayerTile({
    required this.name,
    required this.team,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? _kGreen.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _kGreen : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                team,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: _kGreen, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  /// Onboarding never uses predefined_data.dart's static `imageUrl` (that's
  /// search_screen's own fallback set) — every player here, including the
  /// famous top 10, gets its headshot resolved the same way, at runtime,
  /// via [_PlayerImageResolver] (ESPN + TheSportsDB jointly).
  Widget _buildAvatar() {
    return FutureBuilder<String?>(
      future: _PlayerImageResolver.resolve(name),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved != null && resolved.isNotEmpty) {
          return _avatarFromUrl(resolved);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return _avatarPlaceholder(loading: true);
        }
        return _avatarInitials();
      },
    );
  }

  Widget _avatarFromUrl(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      width: 55,
      height: 55,
      imageBuilder: (context, imageProvider) {
        return Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        );
      },
      placeholder: (context, url) => _avatarPlaceholder(loading: true),
      errorWidget: (context, url, error) => _avatarInitials(),
    );
  }

  Widget _avatarPlaceholder({required bool loading}) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade200),
      child: loading
          ? const Center(
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      )
          : null,
    );
  }

  Widget _avatarInitials() {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _kGreen.withOpacity(0.1)),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kGreen),
        ),
      ),
    );
  }
}

// ── Runtime player headshot resolver (ESPN + TheSportsDB, jointly) ────────
//
// Most of the top-100 seed list in predefined_data.dart doesn't ship with a
// verified static CDN headshot (only the original curated 10 do). Rather
// than guess a URL, this resolves one lazily by name through
// TheSportsDB's free-tier player search, then prefers ESPN's own headshot
// CDN when TheSportsDB gives us a cross-referenced `idESPN` — the same
// ESPN-primary / TheSportsDB-fallback convention SportsDbService already
// uses for lineup headshots elsewhere in the app. Every name is looked up
// at most once per app session; failures are cached too, so a miss doesn't
// get retried on every rebuild/scroll.
class _PlayerImageResolver {
  static final Map<String, Future<String?>> _cache = {};

  // TheSportsDB's free public key ('123') is capped around 30 requests per
  // minute. Building 100 grid tiles (even just via normal scrolling) can
  // fire off far more lookups than that in a burst, so anything past
  // roughly the 30th distinct player was silently getting rate-limited and
  // falling back to initials — not because those players weren't found,
  // but because the request never really got a clean response. Chaining
  // every lookup through this single queue, ~2.2s apart, keeps us safely
  // under that budget so headshots resolve all the way to the end of the
  // list (just progressively, while scrolling, rather than all at once).
  static Future<void> _queue = Future.value();
  static const Duration _requestSpacing = Duration(milliseconds: 2200);

  static Future<String?> resolve(String playerName) {
    return _cache.putIfAbsent(playerName, () => _enqueue(playerName));
  }

  static Future<String?> _enqueue(String playerName) {
    final completer = Completer<String?>();
    _queue = _queue.then((_) async {
      final result = await _lookup(playerName);
      if (!completer.isCompleted) completer.complete(result);
      await Future.delayed(_requestSpacing);
    });
    return completer.future;
  }

  static Future<String?> _lookup(String playerName) async {
    try {
      var result = await SportsDbService().searchPlayerByName(playerName);
      // A handful of single/mononym-style names (e.g. "Zubimendi",
      // "Grimaldo") match better on the surname alone than the full
      // display name — cheap second attempt, still inside the same
      // throttled slot so it doesn't add to the burst.
      if (result == null) {
        final parts = playerName.trim().split(RegExp(r'\s+'));
        if (parts.length > 1) {
          result = await SportsDbService().searchPlayerByName(parts.last);
        }
      }
      if (result == null) return null;

      final espnId = (result['idESPN'] as String?)?.trim() ?? '';
      if (espnId.isNotEmpty) {
        return 'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$espnId.png&w=180&h=180&cb=1';
      }

      final cutout = (result['strCutout'] as String?)?.trim() ?? '';
      if (cutout.isNotEmpty) return cutout;

      final thumb = (result['strThumb'] as String?)?.trim() ?? '';
      if (thumb.isNotEmpty) return thumb;
    } catch (e) {
      debugPrint('[PlayerImageResolver] Lookup failed for "$playerName": $e');
    }
    return null;
  }
}