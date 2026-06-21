import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/models/standing_model.dart';
import 'package:livescore/models/league_leader_model.dart';

// ─── Design Tokens (matches home_screen / game_detail_screen palette) ─────────
class _C {
  static const blue      = Color(0xFF1A62C8);
  static const blueDark  = Color(0xFF0D3F85);
  static const blueLight = Color(0xFFE8F0FC);
  static const white     = Color(0xFFFFFFFF);
  static const offWhite  = Color(0xFFF5F7FB);
  static const border    = Color(0xFFE2E8F2);
  static const text      = Color(0xFF0F1623);
  static const muted     = Color(0xFF6B7A96);
  static const green     = Color(0xFF16A34A);
  static const red       = Color(0xFFE53535);
  static const amber     = Color(0xFFCA8A04);
  static const gold      = Color(0xFFD4AF37);
}

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  // Default selection: FIFA World Cup 2026
  String _selectedLeagueCode = 'fifa.world';
  String _selectedSeason = AppConstants.standingsSeasons.first['value']!;

  bool _isLoading = false;
  List<Standing> _standings = [];
  LeagueLeaders _leaders = LeagueLeaders.empty;
  bool _isLoadingLeaders = false;
  String? _error;

  String _selectedGroup = 'All';
  List<String> _groups = ['All'];

  final List<Map<String, String>> _leagues = AppConstants.allLeagues;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  bool _isWorldCup() => _selectedLeagueCode == 'fifa.world';

  Future<void> _loadAll() async {
    await _loadStandings();
    _loadLeaders(); // fire-and-forget — doesn't block the table
  }

  Future<void> _loadStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedGroup = 'All';
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final standings = await provider.fetchStandingsDirect(
        _selectedLeagueCode,
        season: _selectedSeason,
      );

      final groups = standings
          .map((s) => s.conference)
          .where((g) => g.isNotEmpty)
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _standings = standings;
        _groups = ['All', ...groups];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeaders() async {
    setState(() {
      _isLoadingLeaders = true;
      _leaders = LeagueLeaders.empty;
    });
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final leaders = await provider.fetchLeagueLeaders(
        _selectedLeagueCode,
        season: _selectedSeason,
      );
      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _isLoadingLeaders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLeaders = false);
    }
  }

  List<Standing> get _filteredStandings {
    if (_selectedGroup == 'All') return _standings;
    return _standings.where((s) => s.conference == _selectedGroup).toList();
  }

  void _onLeagueChanged(String code) {
    if (code == _selectedLeagueCode) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedLeagueCode = code);
    _loadAll();
  }

  void _onSeasonChanged(String value) {
    if (value == _selectedSeason) return;
    setState(() => _selectedSeason = value);
    _loadAll();
  }

  String _getLeagueName() {
    final league = _leagues.firstWhere(
          (l) => l['code'] == _selectedLeagueCode,
      orElse: () => {'name': 'League'},
    );
    return league['name']!;
  }

  String _seasonLabel() {
    final s = AppConstants.standingsSeasons.firstWhere(
          (s) => s['value'] == _selectedSeason,
      orElse: () => {'label': _selectedSeason},
    );
    return s['label']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.offWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              leagueName: _getLeagueName(),
              isWorldCup: _isWorldCup(),
              selectedLeagueCode: _selectedLeagueCode,
              selectedSeasonLabel: _seasonLabel(),
              onSeasonTap: _showSeasonPicker,
            ),
            _LeagueSelectorStrip(
              leagues: _leagues,
              selectedCode: _selectedLeagueCode,
              onSelected: _onLeagueChanged,
            ),
            if (_groups.length > 1) _GroupChips(
              groups: _groups,
              selectedGroup: _selectedGroup,
              onSelected: (g) => setState(() => _selectedGroup = g),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  void _showSeasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeasonPickerSheet(
        selected: _selectedSeason,
        onSelected: (v) {
          Navigator.pop(context);
          _onSeasonChanged(v);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingState();

    if (_error != null && _standings.isEmpty) {
      return _ErrorState(error: _error!, onRetry: _loadAll);
    }

    if (_standings.isEmpty) {
      return const _EmptyState(
        title: 'No standings available',
        subtitle: 'Try a different league or season',
      );
    }

    if (_filteredStandings.isEmpty) {
      return const _EmptyState(
        title: 'No teams in this group',
        subtitle: 'Try a different group filter',
      );
    }

    return RefreshIndicator(
      color: _C.blue,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _StandingsTable(
            standings: _filteredStandings,
            isWorldCup: _isWorldCup(),
          ),
          const SizedBox(height: 8),
          _LeadersSection(
            leaders: _leaders,
            isLoading: _isLoadingLeaders,
            leagueName: _getLeagueName(),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String leagueName;
  final bool isWorldCup;
  final String selectedLeagueCode;
  final String selectedSeasonLabel;
  final VoidCallback onSeasonTap;

  const _Header({
    required this.leagueName,
    required this.isWorldCup,
    required this.selectedLeagueCode,
    required this.selectedSeasonLabel,
    required this.onSeasonTap,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = AppConstants.leagueLogoUrl(selectedLeagueCode);

    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          // League logo (official image, no emoji)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.blueLight,
              border: Border.all(color: _C.border),
            ),
            padding: const EdgeInsets.all(6),
            child: logoUrl != null
                ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox(),
              errorWidget: (_, __, ___) =>
              const Icon(Icons.emoji_events_rounded, size: 18, color: _C.blue),
            )
                : const Icon(Icons.emoji_events_rounded, size: 18, color: _C.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leagueName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'STANDINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _C.muted,
                  ),
                ),
              ],
            ),
          ),
          // Season selector pill
          GestureDetector(
            onTap: onSeasonTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _C.blueLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.blue.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedSeasonLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.blue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _C.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── League Selector Strip (logos only — no emoji) ────────────────────────────

class _LeagueSelectorStrip extends StatelessWidget {
  final List<Map<String, String>> leagues;
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const _LeagueSelectorStrip({
    required this.leagues,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: leagues.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final league = leagues[i];
            final code = league['code']!;
            final isSelected = code == selectedCode;
            final isWC = code == 'fifa.world';
            final logoUrl = AppConstants.leagueLogoUrl(code);

            return GestureDetector(
              onTap: () => onSelected(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? (isWC ? _C.gold.withOpacity(0.15) : _C.blueLight)
                            : _C.offWhite,
                        border: Border.all(
                          color: isSelected
                              ? (isWC ? _C.gold : _C.blue)
                              : _C.border,
                          width: isSelected ? 2 : 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: logoUrl != null
                          ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.shield_rounded, size: 20, color: _C.muted),
                      )
                          : Icon(Icons.shield_rounded, size: 20, color: _C.muted),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 64,
                      child: Text(
                        _shortName(league['name']!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isWC ? _C.amber : _C.blue)
                              : _C.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _shortName(String name) {
    // Keep league chip labels compact
    if (name.length <= 12) return name;
    return name.split(' ').first;
  }
}

// ─── Season Picker bottom sheet ────────────────────────────────────────────────

class _SeasonPickerSheet extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  const _SeasonPickerSheet({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          const Text('SELECT SEASON',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _C.muted)),
          const SizedBox(height: 12),
          ...AppConstants.standingsSeasons.map((s) {
            final isSel = s['value'] == selected;
            return GestureDetector(
              onTap: () => onSelected(s['value']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isSel ? _C.blueLight : _C.offWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSel ? _C.blue : _C.border),
                ),
                child: Row(
                  children: [
                    Text(s['label']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? _C.blue : _C.text,
                        )),
                    const Spacer(),
                    if (isSel) const Icon(Icons.check_circle_rounded, color: _C.blue, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Group Chips (e.g. World Cup groups A–H) ──────────────────────────────────

class _GroupChips extends StatelessWidget {
  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onSelected;

  const _GroupChips({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      height: 44,
      padding: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final group = groups[i];
          final isSelected = group == selectedGroup;
          return GestureDetector(
            onTap: () => onSelected(group),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? _C.blue : _C.offWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? _C.blue : _C.border),
              ),
              child: Text(
                group,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _C.white : _C.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Standings Table ──────────────────────────────────────────────────────────

class _StandingsTable extends StatelessWidget {
  final List<Standing> standings;
  final bool isWorldCup;

  const _StandingsTable({required this.standings, required this.isWorldCup});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: const BoxDecoration(
                  color: _C.blueLight,
                  border: Border(bottom: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('#', 28),
                    _headerCell('CLUB', 168, alignLeft: true),
                    _headerCell('MP', 36),
                    _headerCell('W', 30),
                    _headerCell('D', 30),
                    _headerCell('L', 30),
                    _headerCell('GF', 36),
                    _headerCell('GA', 36),
                    _headerCell('GD', 40),
                    _headerCell('PTS', 44),
                  ],
                ),
              ),
              // Rows
              ...standings.asMap().entries.map((e) => _row(e.value, e.key)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text, double width, {bool alignLeft = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: _C.blueDark,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _row(Standing s, int index) {
    final isEven = index % 2 == 0;
    final wins = int.tryParse(s.wins) ?? 0;
    final draws = int.tryParse(s.ties) ?? 0;
    final losses = int.tryParse(s.losses) ?? 0;
    final mp = s.matchesPlayed ?? (wins + draws + losses);
    final gf = s.goalsFor ?? 0;
    final ga = s.goalsAgainst ?? 0;
    final gd = s.goalDifference ?? (gf - ga);
    final pts = s.points ?? 0;

    // Qualification zone highlight (top 4 styled distinctly, like most apps)
    final rankColor = s.rank <= 4
        ? _C.blue
        : (s.rank <= 6 ? _C.green : _C.text);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isEven ? _C.white : _C.offWhite.withOpacity(0.5),
        border: const Border(bottom: BorderSide(color: _C.border, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.rank <= 4)
                  Container(width: 3, height: 16, color: _C.blue, margin: const EdgeInsets.only(right: 4)),
                Text('${s.rank}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: rankColor)),
              ],
            ),
          ),
          SizedBox(
            width: 168,
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(color: _C.offWhite, shape: BoxShape.circle),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: s.team.logo.isNotEmpty && s.team.logo.startsWith('http')
                          ? s.team.logo
                          : 'https://a.espncdn.com/i/teamlogos/soccer/500/${s.team.id}.png',
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) => const Icon(Icons.shield_rounded, size: 16, color: _C.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.team.displayName.isNotEmpty ? s.team.displayName : s.team.name,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _cell('$mp', 36),
          _cell('$wins', 30, color: _C.green),
          _cell('$draws', 30, color: _C.amber),
          _cell('$losses', 30, color: _C.red),
          _cell('$gf', 36),
          _cell('$ga', 36),
          _cell(gd > 0 ? '+$gd' : '$gd', 40,
              color: gd > 0 ? _C.green : (gd < 0 ? _C.red : _C.muted), bold: true),
          SizedBox(
            width: 44,
            child: Text('$pts',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.blue)),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, double width, {Color color = _C.text, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ─── Leaders Section (top scorer / assist / cards) ────────────────────────────

class _LeadersSection extends StatelessWidget {
  final LeagueLeaders leaders;
  final bool isLoading;
  final String leagueName;

  const _LeadersSection({
    required this.leaders,
    required this.isLoading,
    required this.leagueName,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue),
          ),
        ),
      );
    }

    if (leaders.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          children: const [
            Icon(Icons.bar_chart_rounded, size: 18, color: _C.muted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Stat leaders aren\'t available for this competition yet',
                style: TextStyle(fontSize: 12.5, color: _C.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'LEAGUE STAT LEADERS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _C.muted),
            ),
          ),
          if (leaders.topScorers.isNotEmpty)
            _LeaderCard(
              title: 'Top Scorer',
              icon: Icons.sports_soccer_rounded,
              accent: _C.blue,
              entries: leaders.topScorers,
              statSuffix: 'G',
            ),
          if (leaders.topAssists.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Top Assists',
              icon: Icons.assistant_direction_rounded,
              accent: _C.green,
              entries: leaders.topAssists,
              statSuffix: 'A',
            ),
          ],
          if (leaders.mostYellowCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Most Yellow Cards',
              icon: Icons.square_rounded,
              accent: _C.amber,
              entries: leaders.mostYellowCards,
              statSuffix: '',
            ),
          ],
          if (leaders.mostRedCards.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LeaderCard(
              title: 'Most Red Cards',
              icon: Icons.square_rounded,
              accent: _C.red,
              entries: leaders.mostRedCards,
              statSuffix: '',
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<LeaderEntry> entries;
  final String statSuffix;

  const _LeaderCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.entries,
    required this.statSuffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _C.text)),
              ],
            ),
          ),
          ...entries.asMap().entries.map((e) => _leaderRow(e.value, e.key, e.key == entries.length - 1)),
        ],
      ),
    );
  }

  Widget _leaderRow(LeaderEntry entry, int index, bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(top: BorderSide(color: _C.border, width: 0.6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('${index + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.muted)),
          ),
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(color: _C.offWhite, shape: BoxShape.circle),
            child: ClipOval(
              child: entry.headshot.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: entry.headshot,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, size: 16, color: _C.muted),
              )
                  : const Icon(Icons.person_rounded, size: 16, color: _C.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name.isNotEmpty ? entry.name : 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.text),
                ),
                if (entry.teamAbbreviation.isNotEmpty)
                  Text(
                    entry.teamAbbreviation,
                    style: const TextStyle(fontSize: 10.5, color: _C.muted),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _C.blueLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statSuffix.isNotEmpty ? '${entry.value.toInt()} $statSuffix' : '${entry.value.toInt()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.blue),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading / Error / Empty States ───────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (_, i) => Container(
        height: 44,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _C.border.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: _C.red),
            const SizedBox(height: 14),
            const Text('Couldn\'t load standings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
            const SizedBox(height: 6),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _C.muted)),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => onRetry(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.blue,
                foregroundColor: _C.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 40, color: _C.muted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.text)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _C.muted)),
          ],
        ),
      ),
    );
  }
}