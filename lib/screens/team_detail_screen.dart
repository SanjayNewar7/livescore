// lib/screens/team_detail_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/team_page_data.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/services/sportsdb_service.dart';
import 'package:livescore/services/notification_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:livescore/utils/theme.dart';
import 'package:livescore/utils/constants.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

// Brand accents: primary = green, secondary = blue. Used as fallbacks when a
// team has no usable brand color, and for neutral/informational UI accents
// that shouldn't compete with a team's own color.
const Color _kPrimaryGreen = Color(0xFF16A34A);
const Color _kSecondaryBlue = Color(0xFF2563EB);

class TeamDetailScreen extends StatefulWidget {
  final TeamInfo team;
  final String? leagueCode;

  const TeamDetailScreen({
    super.key,
    required this.team,
    this.leagueCode,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SportService _sportService = SportService();
  final SportsDbService _sportsDb = SportsDbService();
  final NotificationService _notifications = NotificationService();

  bool _isFollowing = false;
  // True only until the Matches stage (fast path) has loaded — the rest of
  // the screen renders as soon as this flips false.
  bool _isLoading = true;
  // True while Squad + Analytics are being fetched in the background,
  // after matches are already on screen.
  bool _squadAnalyticsLoading = true;
  String? _error;
  TeamPageData? _data;

  // Cache for SportsDB headshots
  Map<String, String> _sportsDbHeadshots = {};
  bool _headshotsLoaded = false;

  bool get _isNationalTeam =>
      AppConstants.isNationalTeamLeague(widget.leagueCode ?? '');
  bool get _isWorldCup => AppConstants.isWorldCup(widget.leagueCode ?? '');

  @override
  void initState() {
    super.initState();
    _isFollowing = _notifications.isTeamFollowed(widget.team.id);
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  /// Stage 1 (matches) renders as soon as it's ready; stage 2
  /// (squad + analytics) then loads in the background and merges in
  /// once it arrives, without blocking or re-loading the Matches tab.
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _squadAnalyticsLoading = true;
      _error = null;
    });

    try {
      await _sportService.getTeamPageDataStaged(
        widget.team.id,
        leagueCode: widget.leagueCode,
        onMatchesReady: (matchesOnly) {
          if (!mounted) return;
          setState(() {
            _data = matchesOnly;
            _isLoading = false;
          });
          if (_isFollowing) {
            _notifications.scheduleTeamFixtures(
                widget.team.id, matchesOnly.upcoming);
          }
        },
        onSquadAnalyticsReady: (fullData) {
          if (!mounted) return;
          setState(() {
            _data = fullData;
            _squadAnalyticsLoading = false;
          });
          // Load SportsDB headshots now that the squad is in.
          _loadSportsDbHeadshots();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load team data';
        _isLoading = false;
        _squadAnalyticsLoading = false;
      });
    }
  }

  Future<void> _toggleTeamNotifications() async {
    if (_isFollowing) {
      await _notifications.unfollowTeam(widget.team.id);
      if (mounted) setState(() => _isFollowing = false);
      return;
    }
    final consent = await _showNotificationConsent();
    if (consent != true || !mounted) return;
    if (!await _notifications.requestDevicePermission()) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enable notifications in phone settings to follow this team.'),
        ));
      return;
    }
    final prefs = PreferencesService().preferences;
    if (!prefs.notificationsEnabled) {
      await PreferencesService()
          .savePreferences(prefs.copyWith(notificationsEnabled: true));
    }
    await _notifications.followTeam(
      teamId: widget.team.id,
      teamName: widget.team.displayName,
      leagueCode: _data?.leagueCode ?? widget.leagueCode ?? 'eng.1',
      fixtures: _data?.upcoming ?? const [],
    );
    if (mounted) {
      setState(() => _isFollowing = true);
      context.read<AppProvider>().generateNotifications();
    }
  }

  Future<bool?> _showNotificationConsent() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF10213B);
    final muted = dark ? Colors.white70 : const Color(0xFF64748B);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _kPrimaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.notifications_active_rounded,
                    color: _kPrimaryGreen, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Get ${widget.team.displayName} updates',
                  style: TextStyle(
                      fontFamily: 'SportFont',
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: foreground)),
              const SizedBox(height: 8),
              Text('Choose to receive these alerts on your phone:',
                  style: TextStyle(
                      fontFamily: 'SportFont', fontSize: 14, color: muted)),
              const SizedBox(height: 20),
              _consentRow(Icons.article_outlined, 'Team news', foreground),
              const SizedBox(height: 14),
              _consentRow(Icons.schedule_rounded, '15 minutes before kickoff',
                  foreground),
              const SizedBox(height: 14),
              _consentRow(Icons.sports_soccer_rounded,
                  'Kickoff and final result', foreground),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPrimaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Turn on notifications',
                      style: TextStyle(fontFamily: 'SportFont')),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Maybe later',
                      style: TextStyle(fontFamily: 'SportFont',
                          color: _kPrimaryGreen)),
                ),
              ),
              Center(
                child: Text('You can turn these off anytime in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'SportFont', fontSize: 12, color: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _consentRow(IconData icon, String label, Color foreground) => Row(
        children: [
          Icon(icon, size: 20, color: _kPrimaryGreen),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'SportFont',
                      fontSize: 14,
                      color: foreground,
                      fontWeight: FontWeight.w600))),
        ],
      );

  /// Load SportsDB headshots for all squad players
  Future<void> _loadSportsDbHeadshots() async {
    if (_data == null || _data!.squad.isEmpty) return;
    if (_headshotsLoaded) return;

    try {
      // Only try to get headshots if the team is in a mapped league
      final headshots = await _sportsDb.getTeamHeadshots(widget.team.id);

      if (!mounted) return;
      setState(() {
        _sportsDbHeadshots = headshots;
        _headshotsLoaded = true;
      });
      print('[TeamDetail] Loaded ${headshots.length} SportsDB headshots');
    } catch (e) {
      print('[TeamDetail] SportsDB headshot error: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getPrimaryColor() {
    try {
      final colorHex = widget.team.color.replaceAll('#', '');
      if (colorHex.length == 6) {
        return _tonedColor(Color(int.parse('FF$colorHex', radix: 16)));
      }
    } catch (_) {}
    return _kPrimaryGreen;
  }

  /// Tones down colors that are so vividly saturated they clash with the
  /// rest of the UI — common with flag-derived national team colors
  /// (pure reds, yellows, greens straight off a flag). Muted/brand colors
  /// pass through untouched; only very high-saturation, mid-lightness
  /// colors get pulled back toward something the UI can sit next to.
  Color _tonedColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    final isVivid =
        hsl.saturation > 0.80 && hsl.lightness > 0.30 && hsl.lightness < 0.72;
    if (!isVivid) return color;
    return hsl
        .withSaturation(0.62)
        .withLightness(hsl.lightness > 0.5 ? 0.46 : 0.40)
        .toColor();
  }

  /// Returns a badge-safe version of [color].
  /// If the color is too light (luminance > 0.75) it falls back to a dark
  /// neutral so white text remains legible against the badge background.
  Color _safeBadgeColor(Color color) {
    final toned = _tonedColor(color);
    if (toned.computeLuminance() > 0.75) {
      return const Color(0xFF374151); // slate-700 — always readable
    }
    return toned;
  }

  /// Background color for the header hero gradient / tint.
  /// When primaryColor is near-white we use a neutral dark so the gradient
  /// still looks intentional rather than blank.
  Color _safeGradientColor(Color color, bool isDarkMode) {
    final toned = _tonedColor(color);
    if (toned.computeLuminance() > 0.75) {
      return isDarkMode ? const Color(0xFF374151) : const Color(0xFF6B7280);
    }
    return toned;
  }

  String _getValidLogoUrl() {
    if (widget.team.logo.isNotEmpty && widget.team.logo.startsWith('http')) {
      return widget.team.logo;
    }
    return 'https://a.espncdn.com/i/teamlogos/soccer/500/${widget.team.id}.png';
  }

  /// Get best available headshot URL for a player
  String _getPlayerHeadshotUrl(TeamSquadPlayer player) {
    // 1. Try SportsDB headshot first (best quality transparent PNG)
    if (_sportsDbHeadshots.containsKey(player.id) &&
        _sportsDbHeadshots[player.id]!.isNotEmpty) {
      return _sportsDbHeadshots[player.id]!;
    }

    // 2. Try ESPN headshot from API
    if (player.headshotUrl.isNotEmpty &&
        !player.headshotUrl.contains('combiner')) {
      return player.headshotUrl;
    }

    // 3. Build ESPN CDN URL
    if (player.id.isNotEmpty) {
      return 'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/${player.id}.png&w=426&h=240&scale=crop&location=origin';
    }

    return '';
  }

  String _formatMatchDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) return 'Today';
      if (d == tomorrow) return 'Tomorrow';
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatMatchTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _getPrimaryColor();
    final logoUrl = _getValidLogoUrl();

    final surfaceColor = isDarkMode ? const Color(0xFF161920) : Colors.white;
    final bgColor =
        isDarkMode ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC);
    final gradientColor = _safeGradientColor(primaryColor, isDarkMode);

    final standingInfo = _data?.standingInfo;
    final hasRank = standingInfo?.rank != null;
    final hasPoints = standingInfo?.points != null;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Hero AppBar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor:
                isDarkMode ? const Color(0xFF0F1115) : const Color(0xFFF1F5F9),
            iconTheme: IconThemeData(
                color: isDarkMode ? Colors.white : Colors.black87),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primaryColor),
                  ),
                )
              else
                IconButton(
                  tooltip: _isFollowing
                      ? 'Turn off team notifications'
                      : 'Turn on team notifications',
                  icon: Icon(
                    _isFollowing
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: _isFollowing
                        ? _kPrimaryGreen
                        : (isDarkMode ? Colors.white : Colors.black87),
                  ),
                  onPressed: _toggleTeamNotifications,
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              gradientColor
                                  .withOpacity(isDarkMode ? 0.35 : 0.20),
                              gradientColor
                                  .withOpacity(isDarkMode ? 0.08 : 0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -16,
                      bottom: -8,
                      child: Text(
                        widget.team.abbreviation.toUpperCase(),
                        style: TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -4,
                          color: (isDarkMode ? Colors.white : gradientColor)
                              .withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Hero(
                                  tag: 'team_logo_${widget.team.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: logoUrl,
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.contain,
                                    errorWidget: (c, u, e) => Icon(Icons.shield,
                                        size: 80, color: primaryColor),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.team.displayName,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          // WC 2026 badge
                                          if (_isWorldCup) _buildWCBadge(),
                                          if (hasRank)
                                            _buildBadge(
                                              _isNationalTeam &&
                                                      standingInfo!.groupName !=
                                                          null
                                                  ? '${standingInfo.groupName} · #${standingInfo.rank}'
                                                  : '#${standingInfo!.rank} ${standingInfo.groupName ?? ''}',
                                              primaryColor,
                                            ),
                                          if (hasPoints)
                                            _buildBadgeOutline(
                                                '${standingInfo!.points} PTS',
                                                isDarkMode),
                                          if (!hasRank && !_isLoading)
                                            _buildBadge(widget.team.record,
                                                primaryColor),
                                        ],
                                      ),
                                      if (_data?.headCoach != null) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.sports,
                                                size: 12,
                                                color: isDarkMode
                                                    ? Colors.white54
                                                    : Colors.black45),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _data!.headCoach!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDarkMode
                                                      ? Colors.white60
                                                      : Colors.black54,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
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

          // ── Tab Bar ───────────────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _PersistentTabBarDelegate(
              child: Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: isDarkMode ? Colors.white : Colors.black,
                  unselectedLabelColor: AppTheme.lightGray,
                  indicatorColor: primaryColor,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.4),
                  tabs: const [
                    Tab(text: 'MATCHES'),
                    Tab(text: 'SQUAD'),
                    Tab(text: 'ANALYTICS'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: _isLoading
            ? _buildLoadingState(primaryColor)
            : _error != null
                ? _buildErrorState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMatchesTab(isDarkMode, surfaceColor, primaryColor),
                      _buildSquadTab(isDarkMode, surfaceColor, primaryColor),
                      _buildAnalyticsTab(
                          isDarkMode, surfaceColor, primaryColor),
                    ],
                  ),
      ),
    );
  }

  // ── Badges ──────────────────────────────────────────────────────────────────
  Widget _buildWCBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002868), Color(0xFFBF0A30)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆', style: TextStyle(fontSize: 9)),
          SizedBox(width: 3),
          Text(
            'FIFA WORLD CUP 2026',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    final safeColor = _safeBadgeColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: safeColor, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildBadgeOutline(String label, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
            color: isDarkMode ? Colors.white30 : Colors.black26, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDarkMode ? Colors.white70 : Colors.black54,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Loading & Error ──────────────────────────────────────────────────────────
  Widget _buildLoadingState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('Loading team data…',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.lightGray,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppTheme.lightGray),
          const SizedBox(height: 12),
          const Text('Could not load team data',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.lightGray)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadData,
            style: TextButton.styleFrom(foregroundColor: _kPrimaryGreen),
            child: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // MATCHES TAB
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildMatchesTab(
      bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final recent = _data?.recentMatches ?? [];
    final upcoming = _data?.upcoming ?? [];

    // Check if any recent match is from a non-WC competition (fallback data)
    final hasWCMatches = recent.any((m) =>
        m.competition.toLowerCase().contains('world cup') ||
        m.competition.toLowerCase().contains('fifa'));
    final hasFallbackMatches =
        _isWorldCup && recent.isNotEmpty && !hasWCMatches;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── WC 2026 info banner ───────────────────────────────────────────
        if (_isWorldCup) ...[
          _buildWCInfoBanner(isDarkMode, primaryColor),
          const SizedBox(height: 16),
        ],

        // ── Fallback notice ───────────────────────────────────────────────
        if (hasFallbackMatches) ...[
          _buildFallbackNotice(isDarkMode),
          const SizedBox(height: 12),
        ],

        // ── Form Summary Row ──────────────────────────────────────────────
        if (recent.isNotEmpty) ...[
          _buildFormSummaryCard(recent, isDarkMode, surfaceColor, primaryColor),
          const SizedBox(height: 20),
        ],

        // ── Recent Results ────────────────────────────────────────────────
        _blockHeader(_isWorldCup ? 'WORLD CUP RESULTS' : 'RECENT RESULTS'),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          _emptyCard('No recent results found', surfaceColor)
        else
          ...recent.map((m) =>
              _buildMatchCard(m, isDarkMode, surfaceColor, primaryColor)),

        const SizedBox(height: 24),

        // ── Upcoming Fixtures ─────────────────────────────────────────────
        _blockHeader(_isWorldCup ? 'WORLD CUP FIXTURES' : 'UPCOMING FIXTURES'),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          _emptyCard('No upcoming fixtures', surfaceColor)
        else
          ...upcoming.map((f) =>
              _buildFixtureCard(f, isDarkMode, surfaceColor, primaryColor)),
      ],
    );
  }

  /// World Cup 2026 context banner shown at the top of the Matches tab.
  Widget _buildWCInfoBanner(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF002868).withOpacity(isDarkMode ? 0.6 : 0.08),
            const Color(0xFFBF0A30).withOpacity(isDarkMode ? 0.4 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF002868).withOpacity(isDarkMode ? 0.4 : 0.2),
        ),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIFA World Cup 2026',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : const Color(0xFF002868),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'USA · Canada · Mexico • Jun–Jul 2026',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Info notice when WC data is sparse and we fell back to other int'l results.
  Widget _buildFallbackNotice(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(isDarkMode ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing international results (WCQ, Nations League) as World Cup group matches are not yet available.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form Summary Card ──────────────────────────────────────────────────────
  Widget _buildFormSummaryCard(List<TeamRecentMatch> recent, bool isDarkMode,
      Color surfaceColor, Color primaryColor) {
    final wins = recent.where((m) => m.result == 'win').length;
    final draws = recent.where((m) => m.result == 'draw').length;
    final losses = recent.where((m) => m.result == 'loss').length;
    final gf = recent.fold(0, (s, m) => s + m.goalsFor);
    final ga = recent.fold(0, (s, m) => s + m.goalsAgainst);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('RECENT FORM'),
              _sectionLabel('LAST 5 MATCHES'),
            ],
          ),
          const SizedBox(height: 12),
          // Form pill row
          Row(
            children: [
              ...recent.map((m) {
                final color = m.result == 'win'
                    ? const Color(0xFF10B981)
                    : m.result == 'loss'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B);
                final label = m.result == 'win'
                    ? 'W'
                    : m.result == 'loss'
                        ? 'L'
                        : 'D';
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              _formStat('$wins', 'W', const Color(0xFF10B981), isDarkMode),
              _formStatDivider(isDarkMode),
              _formStat('$draws', 'D', const Color(0xFFF59E0B), isDarkMode),
              _formStatDivider(isDarkMode),
              _formStat('$losses', 'L', const Color(0xFFEF4444), isDarkMode),
              _formStatDivider(isDarkMode),
              _formStat('$gf', 'GF', _safeBadgeColor(primaryColor), isDarkMode),
              _formStatDivider(isDarkMode),
              _formStat('$ga', 'GA', AppTheme.lightGray, isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formStat(String value, String label, Color color, bool isDarkMode) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightGray,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _formStatDivider(bool isDarkMode) {
    return Container(
      height: 28,
      width: 1,
      color: isDarkMode ? Colors.white12 : Colors.black12,
    );
  }

  // ── Recent Match Card ───────────────────────────────────────────────────────
  Widget _buildMatchCard(TeamRecentMatch match, bool isDarkMode,
      Color surfaceColor, Color primaryColor) {
    final isWin = match.result == 'win';
    final isLoss = match.result == 'loss';
    final isDraw = match.result == 'draw';
    final resultColor = isWin
        ? const Color(0xFF10B981)
        : isLoss
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
    final resultLabel = isWin
        ? 'W'
        : isLoss
            ? 'L'
            : 'D';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: resultColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Result pill
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(resultLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: resultColor)),
              ),
            ),
            const SizedBox(width: 10),

            // Opponent logo block
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _teamLogo(match.opponentLogo, 36, primaryColor,
                        teamId: match.opponentId),
                  ),
                ),
                // H/A indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: match.isHome
                        ? primaryColor.withOpacity(0.80)
                        : Colors.grey.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    match.isHome ? 'H' : 'A',
                    style: const TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Match info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.opponentName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        match.leagueFlag,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${match.competition}  ·  ${_formatMatchDate(match.date)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.lightGray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (match.yellowCards > 0 || match.redCards > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (match.yellowCards > 0)
                          _cardPill(match.yellowCards, Colors.amber),
                        if (match.yellowCards > 0 && match.redCards > 0)
                          const SizedBox(width: 6),
                        if (match.redCards > 0)
                          _cardPill(match.redCards, const Color(0xFFEF4444)),
                        if (match.possession != null) ...[
                          const SizedBox(width: 6),
                          Text('${match.possession!.toStringAsFixed(0)}% poss',
                              style: const TextStyle(
                                  fontSize: 9, color: AppTheme.lightGray)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Score block
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    match.score,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: resultColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match.isHome ? 'HOME' : 'AWAY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming Fixture Card ───────────────────────────────────────────────────
  Widget _buildFixtureCard(TeamUpcomingFixture fixture, bool isDarkMode,
      Color surfaceColor, Color primaryColor) {
    final dateLabel = _formatMatchDate(fixture.date);
    final timeLabel = _formatMatchTime(fixture.date);
    final isToday = dateLabel == 'Today';
    final isTomorrow = dateLabel == 'Tomorrow';
    final highlightColor = isToday
        ? const Color(0xFF10B981)
        : isTomorrow
            ? _safeBadgeColor(primaryColor)
            : AppTheme.lightGray;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Opponent logo + H/A
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: _teamLogo(fixture.opponentLogo, 38, primaryColor,
                      teamId: fixture.opponentId),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: fixture.isHome
                      ? primaryColor.withOpacity(0.80)
                      : Colors.grey.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  fixture.isHome ? 'H' : 'A',
                  style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Match info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fixture.opponentName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // League badge row
                Row(
                  children: [
                    Text(fixture.leagueFlag,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        fixture.competition,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.lightGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: highlightColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    fixture.isHome ? 'Home Game' : 'Away Game',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: highlightColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date / Time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: highlightColor,
                  ),
                ),
              ),
              if (timeLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(timeLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightGray,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SQUAD TAB
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSquadTab(
      bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final squad = _data?.squad ?? [];
    final categories = ['FORWARDS', 'MIDFIELDERS', 'DEFENDERS', 'GOALKEEPERS'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Best player card
        if (_data?.analytics.bestPlayer != null) ...[
          _buildBestPlayerCard(
            _data!.analytics.bestPlayer!,
            _data!.analytics.bestPlayerRating,
            _data!.analytics.bestPlayerPerformanceNote,
            isDarkMode,
            surfaceColor,
            primaryColor,
            leagueCode: _data?.leagueCode ?? 'eng.1',
          ),
          const SizedBox(height: 20),
        ],

        // Coach
        if (_data?.headCoach != null) ...[
          _blockHeader(
              _isNationalTeam ? 'NATIONAL TEAM MANAGER' : 'COACHING STAFF'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      _safeBadgeColor(primaryColor).withOpacity(0.10),
                  child: Icon(Icons.sports,
                      color: _safeBadgeColor(primaryColor), size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_data!.headCoach!,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('Head Coach',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.lightGray)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (squad.isEmpty && _squadAnalyticsLoading)
          _loadingCard('Loading squad…', surfaceColor, primaryColor)
        else if (squad.isEmpty)
          _emptyCard('Squad data not available', surfaceColor)
        else
          ...categories.map((cat) {
            final players =
                squad.where((p) => p.positionCategory == cat).toList();
            if (players.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _blockHeader(cat),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: players.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                    ),
                    itemBuilder: (context, index) => _buildPlayerRow(
                        players[index], isDarkMode, primaryColor,
                        leagueCode: _data?.leagueCode ?? 'eng.1'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          }).toList(),
      ],
    );
  }

  Widget _buildBestPlayerCard(
    TeamSquadPlayer player,
    double? rating,
    String performanceNote,
    bool isDarkMode,
    Color surfaceColor,
    Color primaryColor, {
    String leagueCode = 'eng.1',
  }) {
    // Get best available headshot
    final headshotUrl = _getPlayerHeadshotUrl(player);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(isDarkMode ? 0.30 : 0.12),
            primaryColor.withOpacity(isDarkMode ? 0.10 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.20), width: 1),
      ),
      child: Row(
        children: [
          _PlayerHeadshot(
            playerId: player.id,
            headshotUrl: headshotUrl,
            size: 72,
            primaryColor: primaryColor,
            leagueCode: leagueCode,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BEST PLAYER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _safeBadgeColor(primaryColor),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildBadge(player.position, primaryColor),
                    const SizedBox(width: 8),
                    if (player.nationality.isNotEmpty)
                      Text(
                        player.nationality,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.lightGray),
                      ),
                  ],
                ),
                if (performanceNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    performanceNote,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (rating != null) ...[
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _safeBadgeColor(primaryColor),
                    letterSpacing: -1,
                  ),
                ),
                const Text('RATING',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.lightGray,
                        letterSpacing: 0.5)),
              ],
            ),
          ] else ...[
            // No rating — show star icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _safeBadgeColor(primaryColor).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star,
                  color: _safeBadgeColor(primaryColor), size: 22),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerRow(TeamSquadPlayer p, bool isDarkMode, Color primaryColor,
      {String leagueCode = 'eng.1'}) {
    // Get best available headshot
    final headshotUrl = _getPlayerHeadshotUrl(p);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Jersey number
          SizedBox(
            width: 26,
            child: Text(
              p.jersey.isNotEmpty ? p.jersey : '—',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppTheme.lightGray),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Headshot with fallback CDN
          _PlayerHeadshot(
            playerId: p.id,
            headshotUrl: headshotUrl,
            size: 40,
            primaryColor: primaryColor,
            leagueCode: leagueCode,
          ),
          const SizedBox(width: 12),
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (p.nationality.isNotEmpty) p.nationality,
                    if (p.age != null) '${p.age} yrs',
                  ].join('  ·  '),
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.lightGray),
                ),
              ],
            ),
          ),
          // Position badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _safeBadgeColor(primaryColor).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              p.position.isNotEmpty ? p.position : '—',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _safeBadgeColor(primaryColor)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // ANALYTICS TAB
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyticsTab(
      bool isDarkMode, Color surfaceColor, Color primaryColor) {
    final a = _data?.analytics ?? TeamAnalytics.empty;
    final hasAnalytics =
        (_data?.squad.isNotEmpty ?? false) || !_squadAnalyticsLoading;

    if (!hasAnalytics) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _loadingCard('Loading analytics…', surfaceColor, primaryColor),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // ── Performance Radar ─────────────────────────────────────────────
        _blockHeader('PERFORMANCE ATTRIBUTES'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF12141C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _RadarPainter(
                  isDarkMode: isDarkMode,
                  color: _safeBadgeColor(primaryColor),
                  stats: {
                    'Attack': a.attackScore,
                    'Defense': a.defenseScore,
                    'Possess.': a.possessionScore,
                    'Midfield': a.midfieldScore,
                    'Discipline': a.disciplineScore,
                  },
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Attacking Production ──────────────────────────────────────────
        _blockHeader('ATTACKING PRODUCTION (LAST 5)'),
        const SizedBox(height: 10),
        Builder(builder: (_) {
          // UI-level fallbacks when ESPN didn't return SOT/conversion data.
          // avgShotsPerGame is always populated (with an estimate if needed),
          // so we can derive reasonable fallback figures from it.
          final totalGames =
              (a.last5Wins + a.last5Draws + a.last5Losses).clamp(1, 5);

          // Total shots across last-5: avgShotsPerGame × games played
          final totalShotsEstimate = a.avgShotsPerGame != null
              ? (a.avgShotsPerGame! * totalGames).roundToDouble()
              : null;

          // Shots on target total — use API value first, fall back to ~35% of total shots
          final sotTotal = a.avgShotsOnTarget ??
              (totalShotsEstimate != null
                  ? (totalShotsEstimate * 0.35).roundToDouble()
                  : null);

          // Conversion rate — Goals ÷ SOT total
          final convRate = a.shotConversionRate ??
              (sotTotal != null && sotTotal > 0
                  ? (a.last5GoalsFor / sotTotal).clamp(0.0, 1.0)
                  : null);

          final sotLabel = sotTotal != null ? sotTotal.toStringAsFixed(0) : '—';
          final convLabel = convRate != null
              ? '${(convRate * 100).toStringAsFixed(1)}%'
              : '—';

          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _metricTile(surfaceColor, '${a.last5GoalsFor}',
                          'GOALS SCORED', const Color(0xFF10B981), isDarkMode)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _metricTile(
                          surfaceColor,
                          a.avgShotsPerGame != null
                              ? a.avgShotsPerGame!.toStringAsFixed(1)
                              : '—',
                          'AVG SHOTS/GAME',
                          _safeBadgeColor(primaryColor),
                          isDarkMode)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _metricTileWithSub(
                          surfaceColor,
                          sotLabel,
                          'SHOTS ON TARGET',
                          'total last 5',
                          Colors.blue,
                          isDarkMode,
                          a.avgShotsOnTarget != null ? null : '~est')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _metricTileWithSub(
                          surfaceColor,
                          convLabel,
                          'CONVERSION RATE',
                          'goals / shots on target',
                          const Color(0xFF8B5CF6),
                          isDarkMode,
                          a.shotConversionRate != null ? null : '~est')),
                ],
              ),
            ],
          );
        }),

        const SizedBox(height: 20),

        // ── Defensive & Discipline ────────────────────────────────────────
        _blockHeader('DEFENSIVE & DISCIPLINE'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _metricTile(surfaceColor, '${a.last5GoalsAgainst}',
                    'GOALS CONCEDED', Colors.redAccent, isDarkMode)),
            const SizedBox(width: 10),
            Expanded(
                child: _metricTile(
                    surfaceColor,
                    '${a.last5Wins * 3 + a.last5Draws}',
                    'POINTS EARNED',
                    _safeBadgeColor(primaryColor),
                    isDarkMode)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _disciplineItem(
                  '${a.last5YellowCards}', 'YELLOW CARDS', Colors.amber),
              Container(
                  height: 30,
                  width: 1,
                  color: isDarkMode ? Colors.white10 : Colors.black12),
              _disciplineItem('${a.last5RedCards}', 'RED CARDS', Colors.red),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Tactical Dominance ────────────────────────────────────────────
        _blockHeader('TACTICAL DOMINANCE (LAST 5)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (a.avgPossession != null)
                _progressRow(
                    'Ball Possession',
                    (a.avgPossession! / 100).clamp(0.0, 1.0),
                    _safeBadgeColor(primaryColor),
                    suffix: '${a.avgPossession!.toStringAsFixed(0)}%',
                    isDarkMode: isDarkMode),
              _progressRow(
                  'Attack Rating', a.attackScore / 100, const Color(0xFF10B981),
                  suffix: '${a.attackScore.toStringAsFixed(0)}',
                  isDarkMode: isDarkMode),
              _progressRow('Defense Rating', a.defenseScore / 100, Colors.blue,
                  suffix: '${a.defenseScore.toStringAsFixed(0)}',
                  isDarkMode: isDarkMode),
              _progressRow('Midfield Rating', a.midfieldScore / 100,
                  const Color(0xFF8B5CF6),
                  suffix: '${a.midfieldScore.toStringAsFixed(0)}',
                  isDarkMode: isDarkMode),
              _progressRow('Discipline', a.disciplineScore / 100, Colors.orange,
                  suffix: '${a.disciplineScore.toStringAsFixed(0)}',
                  isDarkMode: isDarkMode),
              if (a.shotConversionRate != null)
                _progressRow(
                    'Shot Conversion',
                    a.shotConversionRate!.clamp(0.0, 1.0),
                    const Color(0xFFEC4899),
                    suffix:
                        '${(a.shotConversionRate! * 100).toStringAsFixed(0)}%',
                    isDarkMode: isDarkMode,
                    isLast: true),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _teamLogo(String url, double size, Color fallbackColor,
      {String? teamId}) {
    // Build fallback CDN URLs for opponent teams
    String effectiveUrl = url;
    if (effectiveUrl.isEmpty && teamId != null && teamId.isNotEmpty) {
      effectiveUrl = 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png';
    }
    if (effectiveUrl.isEmpty) {
      return Icon(Icons.sports_soccer,
          size: size, color: fallbackColor.withOpacity(0.5));
    }
    return CachedNetworkImage(
      imageUrl: effectiveUrl,
      height: size,
      width: size,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) {
        // If the primary URL failed and we haven't tried CDN yet, try it
        if (!effectiveUrl.contains('espncdn.com') &&
            teamId != null &&
            teamId.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl:
                'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png',
            height: size,
            width: size,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Icon(Icons.sports_soccer,
                size: size, color: fallbackColor.withOpacity(0.5)),
          );
        }
        return Icon(Icons.sports_soccer,
            size: size, color: fallbackColor.withOpacity(0.5));
      },
    );
  }

  Widget _cardPill(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 11,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(1.5)),
          ),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _emptyCard(String message, Color surfaceColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(message,
            style: const TextStyle(fontSize: 13, color: AppTheme.lightGray)),
      ),
    );
  }

  /// Inline loading placeholder shown in the Squad/Analytics tabs while
  /// stage 2 (squad + analytics) is still fetching in the background —
  /// the Matches tab is already interactive at this point.
  Widget _loadingCard(String message, Color surfaceColor, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: primaryColor),
            ),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.lightGray,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(Color surfaceColor, String value, String subtitle,
      Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDarkMode ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightGray,
                  letterSpacing: 0.2)),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (double.tryParse(
                          value.replaceAll('%', '').replaceAll('—', '0')) ??
                      0) /
                  (subtitle.contains('GOAL') ? 10 : 100),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Like [_metricTile] but shows a secondary caption under the subtitle
  /// and optionally an estimate tag when data is derived rather than live.
  Widget _metricTileWithSub(Color surfaceColor, String value, String subtitle,
      String caption, Color color, bool isDarkMode,
      [String? estimateTag]) {
    final parsedVal =
        double.tryParse(value.replaceAll('%', '').replaceAll('—', '0')) ?? 0.0;
    final isPercent = value.contains('%');
    final progressFactor = isPercent
        ? (parsedVal / 100).clamp(0.0, 1.0)
        : (parsedVal / 30).clamp(0.0, 1.0); // SOT typically 0-30 for 5 games

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surfaceColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: value == '—'
                          ? AppTheme.lightGray
                          : (isDarkMode ? Colors.white : Colors.black87))),
              if (estimateTag != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    estimateTag,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.55),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.lightGray,
                  letterSpacing: 0.2)),
          Text(caption,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.lightGray.withOpacity(0.65),
                  letterSpacing: 0.1)),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value == '—' ? 0.0 : progressFactor,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _disciplineItem(String value, String label, Color cardColor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
              color: cardColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lightGray,
                    letterSpacing: 0.3)),
          ],
        ),
      ],
    );
  }

  Widget _progressRow(String label, double val, Color color,
      {String? suffix, bool isDarkMode = false, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white70 : Colors.black87)),
              Text(
                suffix ?? '${(val * 100).toInt()}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: val.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppTheme.lightGray,
          letterSpacing: 0.8,
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.lightGray,
          letterSpacing: 0.5,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PLAYER HEADSHOT WIDGET — cascading CDN fallbacks
// ══════════════════════════════════════════════════════════════════════════════
class _PlayerHeadshot extends StatefulWidget {
  final String playerId;
  final String headshotUrl;
  final double size;
  final Color primaryColor;
  final String leagueCode;

  const _PlayerHeadshot({
    required this.playerId,
    required this.headshotUrl,
    required this.size,
    required this.primaryColor,
    this.leagueCode = 'eng.1',
  });

  @override
  State<_PlayerHeadshot> createState() => _PlayerHeadshotState();
}

class _PlayerHeadshotState extends State<_PlayerHeadshot> {
  int _urlIndex = 0;

  @override
  void didUpdateWidget(covariant _PlayerHeadshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId ||
        oldWidget.headshotUrl != widget.headshotUrl) {
      _urlIndex = 0;
    }
  }

  // ── Headers that unlock ESPN's CDN (Referer is the critical one) ────────────
  // Without Referer: https://www.espn.com/ ESPN CDN returns 403.
  // These headers mimic a real browser request and get ~95%+ hit rate.
  static const Map<String, String> _cdnHeaders = {
    'Referer': 'https://www.espn.com/',
    'Origin': 'https://www.espn.com',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  List<String> get _urls {
    final pid = widget.playerId;
    final apiUrl = widget.headshotUrl.trim();

    if (pid.isEmpty && apiUrl.isEmpty) return [];
    if (pid.isEmpty) return [apiUrl];

    // ── URL priority ──────────────────────────────────────────────────────────
    //
    // 0. API-provided URL — this comes from sports.core.api and is the actual
    //    hosted ESPN image, most likely to resolve successfully. Always try first.
    //
    // 1. combiner with w=426&h=240 — ESPN's preferred soccer headshot size
    //
    // 2. combiner square crop — good for small circular avatars
    //
    // 3. combiner with no size/crop params — sometimes resolves when the
    //    sized variants 404, since it requests the combiner's raw passthrough
    //
    // 4. combinate — newer CDN path
    //
    // 5. legacy direct PNG — older CDN, lower coverage for recent players
    //
    final combiner426 =
        'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$pid.png'
        '&w=426&h=240&scale=crop&location=origin';

    final combiner350 =
        'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$pid.png'
        '&w=350&h=254&scale=crop&location=origin';

    final combinerRaw =
        'https://a.espncdn.com/combiner/i?img=/i/headshots/soccer/players/full/$pid.png';

    final combinate =
        'https://a.espncdn.com/combinate/i/headshots/soccer/players/full/$pid.png';

    final legacy =
        'https://a.espncdn.com/i/headshots/soccer/players/full/$pid.png';

    // De-duplicate preserving order — api URL goes first
    final seen = <String>{};
    final result = <String>[];
    for (final url in [
      apiUrl,
      combiner426,
      combiner350,
      combinerRaw,
      combinate,
      legacy
    ]) {
      if (url.isNotEmpty && seen.add(url)) result.add(url);
    }
    return result;
  }

  String get _currentUrl => _urlIndex < _urls.length ? _urls[_urlIndex] : '';

  void _tryNext() {
    if (!mounted) return;
    if (_urlIndex < _urls.length - 1) {
      // Micro-delay so we're outside the build call that triggered the error
      Future.microtask(() {
        if (mounted) setState(() => _urlIndex++);
      });
    }
  }

  Widget _fallbackAvatar() {
    final safeColor = widget.primaryColor.computeLuminance() > 0.75
        ? const Color(0xFF374151)
        : widget.primaryColor;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: safeColor.withOpacity(0.12),
      ),
      child: Icon(Icons.person_rounded,
          size: widget.size * 0.55, color: safeColor.withOpacity(0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _currentUrl;
    if (url.isEmpty) return _fallbackAvatar();

    return ClipOval(
      child: Image.network(
        url,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        headers: _cdnHeaders,
        // Placeholder — shows the themed circle while loading
        frameBuilder: (ctx, child, frame, _) {
          if (frame == null) {
            // Still loading
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.primaryColor.withOpacity(0.07),
              ),
            );
          }
          return child;
        },
        errorBuilder: (_, __, ___) {
          final hasAnotherUrl = _urlIndex < _urls.length - 1;
          _tryNext();
          if (hasAnotherUrl) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.primaryColor.withOpacity(0.07),
              ),
            );
          }
          return _fallbackAvatar();
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RADAR PAINTER
// ══════════════════════════════════════════════════════════════════════════════
class _RadarPainter extends CustomPainter {
  final Map<String, double> stats;
  final bool isDarkMode;
  final Color color;

  _RadarPainter({
    required this.stats,
    required this.isDarkMode,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.8;
    final keys = stats.keys.toList();
    final int sides = keys.length;
    final double angle = (2 * math.pi) / sides;

    final gridPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withOpacity(0.10)
          : Colors.black.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final level in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final a = i * angle - (math.pi / 2);
        final x = center.dx + radius * level * math.cos(a);
        final y = center.dy + radius * level * math.sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      canvas.drawLine(
        center,
        Offset(
            center.dx + radius * math.cos(a), center.dy + radius * math.sin(a)),
        gridPaint,
      );
    }

    final fillPaint = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final val = (stats[keys[i]] ?? 0).clamp(0.0, 100.0) / 100.0;
      final x = center.dx + radius * val * math.cos(a);
      final y = center.dy + radius * val * math.sin(a);
      i == 0 ? dataPath.moveTo(x, y) : dataPath.lineTo(x, y);
    }
    dataPath.close();
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final val = (stats[keys[i]] ?? 0).clamp(0.0, 100.0) / 100.0;
      canvas.drawCircle(
        Offset(center.dx + radius * val * math.cos(a),
            center.dy + radius * val * math.sin(a)),
        4,
        dotPaint,
      );
    }

    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final lx = center.dx + (radius + 30) * math.cos(a);
      final ly = center.dy + (radius + 28) * math.sin(a);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: keys[i].toUpperCase(),
          style: TextStyle(
            color: isDarkMode
                ? Colors.white.withOpacity(0.55)
                : Colors.black.withOpacity(0.55),
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${(stats[keys[i]] ?? 0).toInt()}',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final w = math.max(labelPainter.width, valuePainter.width);
      labelPainter.paint(
          canvas, Offset(lx - w / 2 + (w - labelPainter.width) / 2, ly - 14));
      valuePainter.paint(
          canvas, Offset(lx - w / 2 + (w - valuePainter.width) / 2, ly - 1));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.stats != stats || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// PERSISTENT HEADER DELEGATE
// ══════════════════════════════════════════════════════════════════════════════
class _PersistentTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _PersistentTabBarDelegate({required this.child});

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_PersistentTabBarDelegate old) => false;
}
