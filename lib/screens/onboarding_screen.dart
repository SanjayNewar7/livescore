import 'package:flutter/material.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/user_preferences.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/screens/home_screen.dart';
import 'package:livescore/screens/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  void _toggleTeamSelection(String teamId) {
    setState(() {
      if (_selectedTeamIds.contains(teamId)) {
        _selectedTeamIds.remove(teamId);
      } else {
        _selectedTeamIds.add(teamId);
      }
    });
  }

  void _toggleLeagueSelection(String leagueCode) {
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
          _currentStep == 0
              ? 'Choose Your Teams'
              : 'Choose Your Leagues',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryBlue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: _currentStep == 1
            ? IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.primaryBlue,
          ),
          onPressed: () {
            setState(() {
              _currentStep = 0;
            });
          },
        )
            : null,
      ),

      body: Column(
        children: [

          Expanded(
            child: _currentStep == 0
                ? _buildTeamSelectionStep()
                : _buildLeagueSelectionStep(),
          ),

          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),

      child: SizedBox(
        width: double.infinity,
        height: 52,

        child: ElevatedButton(
          onPressed: _currentStep == 0
              ? () {
            setState(() {
              _currentStep = 1;
            });
          }
              : _completeOnboarding,

          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),

          child: Text(
            _currentStep == 0
                ? 'Continue'
                : 'Get Started',

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
                '${_selectedTeamIds.length} clubs selected',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
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
                        ? AppTheme.primaryBlue.withOpacity(0.08)
                        : Colors.grey.shade50,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
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
                              color: AppTheme.primaryBlue
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
                                  AppTheme.primaryBlue,
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
                          color: AppTheme.primaryBlue,
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
                            color: AppTheme.primaryBlue,
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

  Widget _buildLeagueSelectionStep() {
    final allLeaguesForDisplay = [
      ...AppConstants.priorityLeagues,
      ...AppConstants.majorClubCompetitions,
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
                  ? AppTheme.primaryBlue.withOpacity(0.08)
                  : Colors.grey.shade50,

              borderRadius: BorderRadius.circular(16),

              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryBlue
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
                        color: AppTheme.primaryBlue.withOpacity(0.1),
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
                      ? AppTheme.primaryBlue
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