import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/screens/team_detail_screen.dart';
import 'package:livescore/utils/constants.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final SportService _sportService = SportService();
  String _selectedLeagueCode = 'fifa.world';
  List<TeamInfo> _teams = [];
  List<TeamInfo> _filteredTeams = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final List<Map<String, String>> _leagues = [
    AppConstants.fifaWorldCup2026,
    ...AppConstants.priorityLeagues,
  ];

  // ── Colours (computed once in build, passed down) ─────────────────────────
  late Color _bgColor;
  late Color _surfaceColor;
  late Color _borderColor;
  late Color _textPrimary;
  late Color _textMuted;
  late Color _accent;      // primary — green
  late Color _accent2;     // secondary — blue
  late Color _inputBg;

  bool _searchHasFocus = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _searchFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    setState(() => _searchHasFocus = _searchFocus.hasFocus);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.removeListener(_handleFocusChange);
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = '';
      _searchController.clear();
    });

    try {
      _sportService.setLeague(_selectedLeagueCode);
      final teams = await _sportService.getAllTeams();
      teams.sort((a, b) => a.displayName.compareTo(b.displayName));
      setState(() {
        _teams = teams;
        _filteredTeams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterTeams(String query) {
    setState(() {
      _searchQuery = query;
      _filteredTeams = query.isEmpty
          ? _teams
          : _teams.where((t) {
        final q = query.toLowerCase();
        return t.displayName.toLowerCase().contains(q) ||
            t.name.toLowerCase().contains(q) ||
            t.abbreviation.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _clearSearch() {
    _filterTeams('');
    _searchController.clear();
    _searchFocus.unfocus();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getValidLogoUrl(TeamInfo team) {
    if (team.logo.isNotEmpty && team.logo.startsWith('http')) return team.logo;
    return 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png';
  }

  String _getLeagueLogoId(String code) {
    const map = {
      'fifa.world': '4',
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
      'usa.1': '19',
      'mex.1': '22',
      'bra.1': '85',
      'arg.1': '1',
      'jpn.1': '25',
      'swe.1': '28',
      'nor.1': '30',
      'den.1': '8',
      'uefa.champions': '2',
      'uefa.europa': '2310',
      'uefa.conference': '2311',
      'conmebol.libertadores': '58',
      'conmebol.sudamericana': '59',
    };
    return map[code] ?? '23';
  }

  bool _isWorldCup(String code) => AppConstants.isWorldCup(code);

  String _abbrev(TeamInfo t) => t.abbreviation.isNotEmpty
      ? t.abbreviation
      : t.displayName.substring(0, t.displayName.length.clamp(0, 3)).toUpperCase();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _bgColor     = isDark ? const Color(0xFF0A0B0A) : const Color(0xFFF4F6F5);
    _surfaceColor = isDark ? const Color(0xFF141715) : Colors.white;
    _borderColor  = isDark ? const Color(0xFF232823) : const Color(0xFFE7EBE8);
    _textPrimary  = isDark ? Colors.white            : const Color(0xFF0D0F0D);
    _textMuted    = isDark ? const Color(0xFF64706A) : const Color(0xFFA2ACA6);
    // Primary = green, Secondary = blue.
    _accent       = isDark ? const Color(0xFF22C55E) : const Color(0xFF15803D);
    _accent2      = isDark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);
    _inputBg      = isDark ? const Color(0xFF1B1F1C) : const Color(0xFFEEF1EF);

    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          Expanded(child: SafeArea(top: false, child: _buildBody())),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    // Subtitle line: shows league name or loading/count
    final String subtitle = _isLoading
        ? 'Loading…'
        : _error != null
        ? 'Could not load'
        : _searchQuery.isNotEmpty
        ? '${_filteredTeams.length} result${_filteredTeams.length == 1 ? '' : 's'}'
        : '${_teams.length} team${_teams.length == 1 ? '' : 's'}';

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.28 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mark + title + count pill ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_accent, _accent.withOpacity(0.72)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Teams',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: -0.6,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoading && _error == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(isDark ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── League label + dropdown ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'LEAGUE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _textMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLeagueDropdown(isDark),
            ),

            const SizedBox(height: 10),

            // ── Search bar (always visible) ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSearchBar(isDark),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLeagueDropdown(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLeagueCode,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: _accent2),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary),
          dropdownColor: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          items: _leagues.map((league) {
            final code  = league['code']!;
            final isWC  = _isWorldCup(code);
            final imgUrl = isWC
                ? AppConstants.fifaWorldCup2026LogoUrlSmall
                : 'https://a.espncdn.com/i/leaguelogos/soccer/500/${_getLeagueLogoId(code)}.png';

            return DropdownMenuItem(
              value: code,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(),
                      errorWidget: (_, __, ___) =>
                          Text(league['flag'] ?? '⚽', style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      league['name'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isWC ? FontWeight.w600 : FontWeight.w400,
                        color: _textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isWC) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accent2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '2026',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && value != _selectedLeagueCode) {
              setState(() => _selectedLeagueCode = value);
              _loadTeams();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 44,
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchHasFocus ? _accent.withOpacity(0.55) : _borderColor,
          width: _searchHasFocus ? 1.2 : 0.5,
        ),
        boxShadow: _searchHasFocus
            ? [BoxShadow(color: _accent.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 3))]
            : [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 18, color: _searchHasFocus ? _accent : _textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _filterTeams,
              style: TextStyle(fontSize: 14, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Search teams…',
                hintStyle: TextStyle(fontSize: 14, color: _textMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, size: 16, color: _textMuted),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) return _buildSkeleton();
    if (_error != null) return _buildError();
    if (_teams.isEmpty) return _buildEmpty('No teams available', 'Try a different league.');
    if (_filteredTeams.isEmpty) {
      return _buildEmpty(
        'No results for "$_searchQuery"',
        'Check the spelling or try a different name.',
      );
    }
    return _buildGrid();
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => _SkeletonCard(
        surfaceColor: _surfaceColor,
        shimmerColor: _borderColor,
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor, width: 0.5),
              ),
              child: Icon(Icons.wifi_off_rounded, size: 24, color: _textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load teams',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 13, color: _textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [_accent, _accent.withOpacity(0.82)]),
                  boxShadow: [
                    BoxShadow(color: _accent.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: TextButton(
                  onPressed: _loadTeams,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor, width: 0.5),
              ),
              child: Icon(Icons.sports_soccer_rounded, size: 24, color: _textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: _textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────

  Widget _buildGrid() {
    return RefreshIndicator(
      onRefresh: _loadTeams,
      color: _accent,
      backgroundColor: _surfaceColor,
      displacement: 20,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: _filteredTeams.length,
        itemBuilder: (context, index) {
          final team   = _filteredTeams[index];
          final logoUrl = _getValidLogoUrl(team);
          return _TeamGridCard(
            team: team,
            logoUrl: logoUrl,
            abbrev: _abbrev(team),
            surfaceColor: _surfaceColor,
            borderColor: _borderColor,
            textPrimary: _textPrimary,
            textMuted: _textMuted,
            accent: _accent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamDetailScreen(
                  team: team,
                  leagueCode: _selectedLeagueCode,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final Color surfaceColor;
  final Color shimmerColor;
  const _SkeletonCard({required this.surfaceColor, required this.shimmerColor});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.shimmerColor, width: 0.5),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.shimmerColor.withOpacity(_anim.value),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Divider(height: 0.5, thickness: 0.5, color: widget.shimmerColor),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: widget.shimmerColor.withOpacity(_anim.value),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 8,
                      width: 36,
                      decoration: BoxDecoration(
                        color: widget.shimmerColor.withOpacity(_anim.value * 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Team grid card ────────────────────────────────────────────────────────────

class _TeamGridCard extends StatefulWidget {
  final TeamInfo team;
  final String logoUrl;
  final String abbrev;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final VoidCallback onTap;

  const _TeamGridCard({
    required this.team,
    required this.logoUrl,
    required this.abbrev,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_TeamGridCard> createState() => _TeamGridCardState();
}

class _TeamGridCardState extends State<_TeamGridCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${widget.team.displayName}, ${widget.abbrev}',
      button: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.surfaceColor.withOpacity(0.85)
                  : widget.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pressed ? widget.accent.withOpacity(0.4) : widget.borderColor,
                width: _pressed ? 1.2 : 0.5,
              ),
              boxShadow: _pressed
                  ? []
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // ── Logo ──────────────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: CachedNetworkImage(
                      imageUrl: widget.logoUrl,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: widget.textMuted,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          size: 26,
                          color: widget.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Divider ───────────────────────────────────────────
                Divider(height: 0.5, thickness: 0.5, color: widget.borderColor),

                // ── Name + badge ──────────────────────────────────────
                // Uses Expanded so it never fights a fixed height.
                // maxLines:1 + ellipsis keeps text from ever needing
                // two lines and overflowing the flex container.
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          widget.team.displayName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: widget.textPrimary,
                            letterSpacing: -0.1,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.abbrev,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: widget.accent,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
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