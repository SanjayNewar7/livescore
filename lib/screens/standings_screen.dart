import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/models/standing_model.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  String _selectedLeagueCode = 'fifa.world';
  bool _isLoading = false;
  List<Standing> _standings = [];
  String? _error;
  String _selectedGroup = 'All';
  List<String> _groups = ['All'];

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedGroup = 'All';
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final standings = await provider.fetchStandingsDirect(_selectedLeagueCode);

      // Extract unique groups
      final groups = standings
          .map((s) => s.conference)
          .where((g) => g != null && g.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        _standings = standings;
        _groups = ['All', ...groups];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Standing> get _filteredStandings {
    if (_selectedGroup == 'All') {
      return _standings;
    }
    return _standings.where((s) => s.conference == _selectedGroup).toList();
  }

  bool _isWorldCup() => _selectedLeagueCode == 'fifa.world';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isWorldCup = _isWorldCup();

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'STANDINGS',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isWorldCup ? AppTheme.primaryBlue : null,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // League selector
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: DropdownButtonFormField<String>(
                  value: _selectedLeagueCode,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDarkMode ? AppTheme.darkGray : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isWorldCup ? AppTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 1,
                      ),
                    ),
                    prefixIcon: isWorldCup
                        ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.network(
                        AppConstants.fifaWorldCup2026LogoUrlSmall,
                        width: 24,
                        height: 24,
                        errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, size: 20),
                      ),
                    )
                        : const Icon(Icons.emoji_events, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: AppConstants.allLeagues.map((league) {
                    final code = league['code']!;
                    final isWC = code == 'fifa.world';

                    return DropdownMenuItem(
                      value: code,
                      child: Row(
                        children: [
                          if (isWC)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  AppConstants.fifaWorldCup2026LogoUrlSmall,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Text(league['flag']!, style: const TextStyle(fontSize: 16)),
                                ),
                              ),
                            )
                          else
                            Text(league['flag']!, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  league['name']!,
                                  style: TextStyle(
                                    fontWeight: isWC ? FontWeight.w700 : FontWeight.w600,
                                    color: isWC ? AppTheme.primaryBlue : null,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  league['country'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.lightGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isWC)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '2026',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null && value != _selectedLeagueCode) {
                      setState(() {
                        _selectedLeagueCode = value;
                      });
                      _loadStandings();
                    }
                  },
                ),
              ),
              // Group filter chips
              if (_groups.length > 1)
                Container(
                  height: 45,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final group = _groups[i];
                      final isSelected = _selectedGroup == group;
                      return FilterChip(
                        label: Text(group),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedGroup = group;
                          });
                        },
                        backgroundColor: isDarkMode ? AppTheme.darkGray : Colors.grey[100],
                        selectedColor: AppTheme.primaryBlue.withOpacity(0.1),
                        checkmarkColor: AppTheme.primaryBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primaryBlue : (isDarkMode ? Colors.white : Colors.grey[700]),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text('Loading standings...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.dangerRed),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.lightGray)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStandings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    if (_standings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 48, color: AppTheme.lightGray),
            SizedBox(height: 16),
            Text('No standings available for this league'),
          ],
        ),
      );
    }

    if (_filteredStandings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppTheme.lightGray),
            SizedBox(height: 16),
            Text('No teams in this group'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStandings,
      color: AppTheme.primaryBlue,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League title
              if (_selectedGroup == 'All')
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_isWorldCup())
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              AppConstants.fifaWorldCup2026LogoUrlSmall,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, size: 20),
                            ),
                          ),
                        ),
                      if (_isWorldCup()) const SizedBox(width: 12),
                      Text(
                        _getLeagueName(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isWorldCup() ? AppTheme.primaryBlue : null,
                        ),
                      ),
                      if (_selectedGroup != 'All') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedGroup,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                color: AppTheme.primaryBlue.withOpacity(0.08),
                child: Row(
                  children: [
                    _buildHeaderCell('POS', 45),
                    _buildHeaderCell('CLUB', 200),
                    _buildHeaderCell('MP', 50),
                    _buildHeaderCell('W', 45),
                    _buildHeaderCell('D', 45),
                    _buildHeaderCell('L', 45),
                    _buildHeaderCell('GF', 50),
                    _buildHeaderCell('GA', 50),
                    _buildHeaderCell('GD', 55),
                    _buildHeaderCell('PTS', 55),
                    _buildHeaderCell('Last 5', 100),
                  ],
                ),
              ),
              // Table rows
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredStandings.length,
                itemBuilder: (context, index) {
                  final standing = _filteredStandings[index];
                  return _buildStandingRow(standing, index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
          letterSpacing: 0.5,
        ),
        textAlign: text == 'CLUB' ? TextAlign.left : TextAlign.center,
      ),
    );
  }

  Widget _buildStandingRow(Standing standing, int index) {
    final isEven = index % 2 == 0;
    final isWorldCup = _isWorldCup();

    // Safely get values with fallbacks
    final points = standing.points ?? 0;
    final matchesPlayed = standing.matchesPlayed ?? 0;
    final wins = int.tryParse(standing.wins) ?? 0;
    final draws = int.tryParse(standing.ties) ?? 0;
    final losses = int.tryParse(standing.losses) ?? 0;
    final goalsFor = standing.goalsFor ?? 0;
    final goalsAgainst = standing.goalsAgainst ?? 0;
    final goalDifference = standing.goalDifference ?? (goalsFor - goalsAgainst);
    final form = standing.form ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: isEven ? null : Colors.grey.withOpacity(0.03),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 45,
            child: Text(
              '${standing.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: standing.rank <= 4 ? AppTheme.primaryBlue : (isWorldCup ? AppTheme.primaryBlue : Colors.grey[700]),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Club with logo
          SizedBox(
            width: 200,
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: standing.team.logo,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(),
                      errorWidget: (context, url, error) => const Icon(Icons.sports_soccer, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    standing.team.abbreviation.isNotEmpty
                        ? standing.team.abbreviation
                        : standing.team.displayName.length > 3
                        ? standing.team.displayName.substring(0, 3).toUpperCase()
                        : standing.team.displayName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // MP
          SizedBox(
            width: 50,
            child: Text(
              '$matchesPlayed',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // Wins
          SizedBox(
            width: 45,
            child: Text(
              '$wins',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
            ),
          ),
          // Draws
          SizedBox(
            width: 45,
            child: Text(
              '$draws',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
            ),
          ),
          // Losses
          SizedBox(
            width: 45,
            child: Text(
              '$losses',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
            ),
          ),
          // Goals For
          SizedBox(
            width: 50,
            child: Text(
              '$goalsFor',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // Goals Against
          SizedBox(
            width: 50,
            child: Text(
              '$goalsAgainst',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // Goal Difference
          SizedBox(
            width: 55,
            child: Text(
              goalDifference > 0 ? '+$goalDifference' : '$goalDifference',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: goalDifference > 0 ? Colors.green : (goalDifference < 0 ? Colors.red : Colors.grey),
              ),
            ),
          ),
          // Points
          SizedBox(
            width: 55,
            child: Text(
              '$points',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isWorldCup ? AppTheme.primaryBlue : AppTheme.primaryBlue,
              ),
            ),
          ),
          // Last 5 Form
          SizedBox(
            width: 100,
            child: _buildFormIndicator(form),
          ),
        ],
      ),
    );
  }

  Widget _buildFormIndicator(String form) {
    if (form.isEmpty) {
      return const SizedBox();
    }

    final formLetters = form.split('');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: formLetters.take(5).map((letter) {
        Color color;
        switch (letter.toUpperCase()) {
          case 'W':
            color = Colors.green;
            break;
          case 'D':
            color = Colors.orange;
            break;
          case 'L':
            color = Colors.red;
            break;
          default:
            color = Colors.grey;
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Text(
              letter.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getLeagueName() {
    final league = AppConstants.allLeagues.firstWhere(
          (l) => l['code'] == _selectedLeagueCode,
      orElse: () => {'name': 'League'},
    );
    return league['name']!;
  }
}