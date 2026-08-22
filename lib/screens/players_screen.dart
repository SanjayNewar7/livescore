// lib/screens/player_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/widgets/football_pitch_lineup.dart';
import 'package:livescore/utils/constants.dart';
import 'package:livescore/utils/predefined_data.dart';

// Brand accents: primary = green, secondary = blue.
const Color _kPrimaryGreen = Color(0xFF16A34A);
const Color _kSecondaryBlue = Color(0xFF2563EB);

/// Player screen that displays detailed player information
/// Opens when clicking on a player in the lineup tab of game_detail_screen
class PlayerScreen extends StatefulWidget {
  final PitchPlayer player;
  final Game? game;
  final TeamInfo? teamInfo;

  /// Explicit league code override. Used when there's no [game] to derive
  /// a league from (e.g. opened from search results) — without this,
  /// `_getLeagueCodeFromName` had no signal to work with and silently
  /// defaulted to 'eng.1' for every player, regardless of which league
  /// they actually play in. [SearchResult] already carries the correct
  /// code, so callers with a search result should pass it through here.
  final String? leagueCode;

  const PlayerScreen({
    super.key,
    required this.player,
    this.game,
    this.teamInfo,
    this.leagueCode,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  final SportService _sportService = SportService();

  // Player data
  Player? _playerDetails;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  // Theme colors
  Color _primaryColor = _kPrimaryGreen;
  Color _textColor = const Color(0xFF0D1B3E);
  Color _mutedColor = const Color(0xFF6B7A96);
  Color _cardColor = Colors.white;
  Color _bgColor = const Color(0xFFF0F4FF);

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _loadPlayerDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Load player details using hybrid approach (ESPN + TheSportsDB).
  ///
  /// For a player we already have good offline data for (top-tier players
  /// in [predefinedPlayerStats] / [famousPlayers]), this used to still wait
  /// on the full network round-trip before showing anything — the seed data
  /// only ever kicked in as a fallback *after* the live fetch had already
  /// finished (or failed), so it never actually saved any time. Now a known
  /// player paints instantly from the seed, and the live fetch runs
  /// silently in the background to replace it with current data (latest
  /// club, up-to-date season stats, etc.) once it resolves.
  Future<void> _loadPlayerDetails() async {
    if (_isRefreshing) return;

    _primaryColor = widget.teamInfo != null
        ? _parseColor(widget.teamInfo!.color)
        : (widget.player.isHome ? _kPrimaryGreen : _kSecondaryBlue);

    final hasPredefinedSeed = widget.player.id.isNotEmpty &&
        (predefinedPlayerStats.containsKey(widget.player.id) ||
            findFamousPlayerById(widget.player.id) != null);

    if (hasPredefinedSeed) {
      setState(() {
        _playerDetails = _createPlayerFromPitchPlayer(widget.player);
        _isLoading = false;
        _error = null;
      });
      _animationController.forward();

      // Silent background revalidation — no loading state, no error state;
      // if this fails the seed data already on screen just stays as-is.
      _fetchLivePlayerDetails(silent: true);
      return;
    }

    await _fetchLivePlayerDetails(silent: false);
  }

  Future<void> _fetchLivePlayerDetails({required bool silent}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final leagueCode = (widget.leagueCode != null && widget.leagueCode!.isNotEmpty)
          ? widget.leagueCode!
          : _getLeagueCodeFromName(widget.game?.leagueName ?? '');

      Player? playerDetails;

      if (widget.player.id.isNotEmpty) {
        try {
          // Use hybrid fetch - ESPN primary, SportsDB as fallback/enrichment
          playerDetails = await _sportService.getPlayerDetailsHybrid(
            widget.player.id,
            leagueCode: leagueCode,
          );
          print('[PlayerScreen] Hybrid loaded: ${playerDetails.displayName}');
          print('[PlayerScreen] Headshot: ${playerDetails.headshot}');
          print('[PlayerScreen] Stats: ${playerDetails.statistics}');
          print('[PlayerScreen] SeasonStats: ${playerDetails.seasonStats}');
          print('[PlayerScreen] Nationality: ${playerDetails.nationality}');
          print('[PlayerScreen] BirthDate: ${playerDetails.birthDate}');
          print('[PlayerScreen] Foot: ${playerDetails.foot}');
          print('[PlayerScreen] Market Value: ${playerDetails.marketValue}');
        } catch (e) {
          print('[PlayerScreen] Hybrid fetch failed: $e');
        }
      }

      if (!mounted) return;

      if (playerDetails != null && playerDetails.id.isNotEmpty) {
        setState(() {
          _playerDetails = playerDetails;
          _isLoading = false;
        });
        if (!silent) _animationController.forward();
      } else if (!silent) {
        // Foreground load with nothing from the network — fall back to
        // whatever PitchPlayer info is available so the screen isn't blank.
        setState(() {
          _playerDetails = _createPlayerFromPitchPlayer(widget.player);
          _isLoading = false;
        });
        _animationController.forward();
      }
      // else: silent revalidation found nothing better than the seed
      // already on screen — leave it as-is.

    } catch (e) {
      if (silent || !mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getLeagueCodeFromName(String leagueName) {
    if (leagueName.isEmpty) return 'eng.1';
    for (final league in AppConstants.allLeagues) {
      if (league['name'] == leagueName) {
        return league['code']!;
      }
    }
    return 'eng.1';
  }

  /// Create player from PitchPlayer data (fallback for when the live APIs
  /// don't return anything for this player). If this player id happens to
  /// match one of our predefined "seed" players, we enrich the fallback
  /// with real career/season stats instead of leaving everything at zero.
  Player _createPlayerFromPitchPlayer(PitchPlayer pitchPlayer) {
    print('[PlayerScreen] Creating player from PitchPlayer:');
    print('  Name: ${pitchPlayer.name}');
    print('  ID: ${pitchPlayer.id}');
    print('  Headshot: ${pitchPlayer.imageUrl}');

    final predefined = predefinedPlayerStats[pitchPlayer.id];
    final famous = findFamousPlayerById(pitchPlayer.id);

    if (predefined != null) {
      print('[PlayerScreen] Using predefined fallback stats for ${pitchPlayer.name}');
    }

    return Player(
      id: pitchPlayer.id,
      fullName: pitchPlayer.name,
      displayName: pitchPlayer.name,
      headshot: pitchPlayer.imageUrl ?? (famous?['imageUrl'] as String? ?? ''),
      jersey: pitchPlayer.number,
      position: pitchPlayer.position,
      teamId: widget.teamInfo?.id ?? '',
      teamName: widget.teamInfo?.displayName ??
          (widget.player.isHome ? 'Home Team' : 'Away Team'),
      height: 0,
      weight: 0,
      age: 0,
      college: '',
      // ✅ FIX: this used to be hardcoded to `{}` even when `predefined`
      // had real careerGoals/careerAssists/careerAppearances sitting right
      // there — seasonStats and careerStats below were being filled in
      // from `predefined`, but the top-line totals grid (what the
      // "Career Totals" row on this screen actually reads) was not, so it
      // rendered as 0 goals / 0 assists / 0 apps for a known player even
      // though accurate data existed.
      statistics: predefined != null
          ? {
        'goals': predefined['careerGoals'],
        'assists': predefined['careerAssists'],
        'appearances': predefined['careerAppearances'],
      }
          : {},
      seasonStats: predefined?['seasonStats'] as Map<String, dynamic>? ?? {},
      careerStats: (predefined?['careerStats'] as List?)?.cast<Map<String, dynamic>>(),
      nationality: famous?['nationality'] as String?,
      injuryStatus: null,
    );
  }

  Color _parseColor(String hex) {
    try {
      final c = hex.replaceAll('#', '');
      if (c.length == 6) {
        return Color(int.parse('FF$c', radix: 16));
      }
    } catch (_) {}
    return _kPrimaryGreen;
  }

  Color _getRatingColor(double? rating) {
    if (rating == null) return Colors.grey;
    if (rating >= 8.0) return _kPrimaryGreen;
    if (rating >= 6.5) return _kSecondaryBlue;
    if (rating >= 5.0) return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }

  String _getRatingLabel(double rating) {
    if (rating >= 8.5) return 'Outstanding';
    if (rating >= 7.5) return 'Excellent';
    if (rating >= 6.5) return 'Good';
    if (rating >= 5.5) return 'Average';
    if (rating >= 4.5) return 'Below Average';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _textColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    _mutedColor = isDark ? Colors.grey[400]! : const Color(0xFF6B7A96);
    _bgColor = isDark ? const Color(0xFF12141C) : const Color(0xFFF0F4FF);
    _cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: _textColor,
        // ─── STATUS BAR FIX ─────────────────────────────────────────────
        // With a fully transparent AppBar, Flutter can't reliably infer a
        // contrasting status bar icon color from the background (a
        // transparent color has no real "brightness" to estimate), so the
        // battery/wifi/clock icons were rendering with the wrong
        // brightness and blending into this screen's background. Setting
        // this explicitly based on the actual theme brightness fixes it.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        )
            : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _buildAppBarIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            color: _textColor,
            onTap: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
        ),
        leadingWidth: 52,
        actions: [
          _buildAppBarIcon(
            icon: Icons.refresh_rounded,
            color: _kPrimaryGreen,
            onTap: _loadPlayerDetails,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadPlayerDetails,
        color: _primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Profile Header
                _buildProfileHeader(),

                const SizedBox(height: 16),

                // Stats Grid
                _buildStatsGrid(),

                const SizedBox(height: 16),

                // Match Rating (if available). The gap after this used to
                // be unconditional, so when there's no rating (the common
                // case — most players are opened from search, not a live
                // match lineup) you'd get two stacked 16px gaps with
                // nothing between them, reading as one much wider gap
                // before Season Statistics. Now the gap only exists
                // alongside the card itself.
                if (widget.player.rating != null) ...[
                  _buildRatingCard(),
                  const SizedBox(height: 16),
                ],

                // Season Statistics
                _buildSeasonStatsCard(),

                const SizedBox(height: 16),

                // Analytics (radar chart + attribute breakdown). Gated the
                // same way as the rating card above — only reserve the gap
                // when there's actually a card to show, so an empty-stats
                // player doesn't get a wide dead gap here either.
                if (_hasAnalyticsData) ...[
                  _buildAnalyticsCard(),
                  const SizedBox(height: 16),
                ],

                // Player Info (Bio)
                _buildPlayerInfoCard(),

                const SizedBox(height: 16),

                // Injury Status
                if (_playerDetails?.injuryStatus != null)
                  _buildInjuryCard(),

                // Career Stats (if available)
                if (_playerDetails?.careerStats != null && _playerDetails!.careerStats!.isNotEmpty)
                  _buildCareerStatsCard(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── APP BAR ICON ───────────────────────────────────────────────────────────

  Widget _buildAppBarIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _cardColor,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }

  // ─── SHIMMER LOADING ────────────────────────────────────────────────────────

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildShimmerCircle(80),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerLine(width: 120, height: 20),
                      const SizedBox(height: 8),
                      _buildShimmerLine(width: 80, height: 14),
                      const SizedBox(height: 8),
                      _buildShimmerLine(width: 100, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: List.generate(3, (_) => _buildShimmerCard()),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildShimmerLine(width: 120, height: 16),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                  children: List.generate(6, (_) => _buildShimmerCard()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildShimmerLine({double width = 200, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildShimmerLine(width: 30, height: 20),
          const SizedBox(height: 8),
          _buildShimmerLine(width: 40, height: 12),
        ],
      ),
    );
  }

  // ─── ERROR STATE ────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load player details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please try again',
              style: TextStyle(
                fontSize: 14,
                color: _mutedColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPlayerDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PROFILE HEADER ─────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final player = _playerDetails;
    final name = player?.displayName ?? widget.player.name;
    final number = player?.jersey ?? widget.player.number;
    final position = player?.positionDisplay ?? widget.player.position.toUpperCase();

    // Get the headshot from Player or fallback to PitchPlayer
    String headshot = '';
    if (player != null && player.headshot.isNotEmpty) {
      headshot = player.headshot;
    } else if (widget.player.imageUrl != null && widget.player.imageUrl!.isNotEmpty) {
      headshot = widget.player.imageUrl!;
    }

    print('[PlayerScreen] Building profile header:');
    print('  Name: $name');
    print('  Headshot from player: ${player?.headshot}');
    print('  Headshot from widget: ${widget.player.imageUrl}');
    print('  Final headshot: $headshot');

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: _primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand accent strip + eyebrow label
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_kPrimaryGreen, _kSecondaryBlue]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PLAYER PROFILE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _mutedColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Player Photo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _primaryColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: headshot.isNotEmpty
                            ? Image.network(
                          headshot,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitials(name),
                        )
                            : _buildInitials(name),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Player Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: _textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (number.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '#$number',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  position,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (widget.player.isStarter)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'STARTER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kSecondaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'SUB',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _kSecondaryBlue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Team Info
                          Row(
                            children: [
                              if (widget.teamInfo?.logo != null && widget.teamInfo!.logo.isNotEmpty)
                                Image.network(
                                  widget.teamInfo!.logo,
                                  width: 20,
                                  height: 20,
                                  errorBuilder: (_, __, ___) => const SizedBox(width: 20),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                widget.teamInfo?.displayName ??
                                    (widget.player.isHome ? 'Home Team' : 'Away Team'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');

    return Container(
      color: _primaryColor.withOpacity(0.12),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: _primaryColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ─── STATS GRID ─────────────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = _playerDetails?.statistics ?? {};
    final seasonStats = _playerDetails?.seasonStats ?? {};

    // IMPORTANT: `stats` (Player.statistics) is meant to hold all-time
    // career totals — e.g. Ronaldo's 976 goals — while `seasonStats` holds
    // just the current season (e.g. 25 goals for 2024-25 at Al-Nassr).
    // `_extractStatValue` previously checked `seasonStats` FIRST, so this
    // grid silently showed the season number under a plain "GOALS" label
    // with no indication it wasn't the career total — exactly the mix-up
    // being reported. Career totals now take priority here; the Season
    // Statistics card below already shows the season-scoped numbers with
    // their own season/league/team labels, so there's no loss of info.
    final goals = _extractStatValue(stats, seasonStats, [
      'goals', 'totalGoals', 'goalsScored', 'goal', 'g', 'G', 'Goals'
    ]);

    final assists = _extractStatValue(stats, seasonStats, [
      'assists', 'totalAssists', 'assist', 'a', 'A', 'Assists'
    ]);

    final appearances = _extractStatValue(stats, seasonStats, [
      'appearances', 'gamesPlayed', 'matchesPlayed', 'played', 'gp', 'MP', 'Apps'
    ]);

    final statItems = [
      {'label': 'GOALS', 'value': goals, 'icon': Icons.sports_soccer_rounded},
      {'label': 'ASSISTS', 'value': assists, 'icon': Icons.people_rounded},
      {'label': 'APPS', 'value': appearances, 'icon': Icons.calendar_today_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CAREER TOTALS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _mutedColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: statItems.map((item) {
            return Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: _primaryColor,
                    size: 22,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['value'] as String,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _mutedColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _extractStatValue(Map<String, dynamic> stats, Map<String, dynamic> seasonStats, List<String> keys) {
    // Career/season priority: check `stats` (career totals) first, then
    // fall back to `seasonStats`. See the comment in `_buildStatsGrid` for
    // why this order matters — reversing it is what caused the top grid
    // to silently show season numbers instead of all-time totals.
    for (final key in keys) {
      if (stats.containsKey(key)) {
        final value = stats[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }
    for (final key in keys) {
      if (seasonStats.containsKey(key)) {
        final value = seasonStats[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }
    return '0';
  }

  // ─── RATING CARD ────────────────────────────────────────────────────────────

  Widget _buildRatingCard() {
    final rating = widget.player.rating!;
    final ratingColor = _getRatingColor(rating);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: ratingColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: ratingColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: ratingColor,
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: ratingColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCH RATING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _mutedColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRatingLabel(rating),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on performance in this match',
                  style: TextStyle(
                    fontSize: 12,
                    color: _mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ANALYTICS (RADAR CHART) ─────────────────────────────────────────────────

  /// Whether there's enough season-stat data to justify showing the
  /// Analytics card at all — a card full of zeroed-out bars and a flat
  /// radar isn't useful, so we skip it entirely rather than render junk.
  bool get _hasAnalyticsData {
    final seasonStats = _playerDetails?.seasonStats ?? {};
    if (seasonStats.isEmpty) return false;
    return seasonStats.values.any((v) => (num.tryParse('$v') ?? 0) > 0);
  }

  Widget _buildAnalyticsCard() {
    final stats = _playerDetails?.statistics ?? {};
    final seasonStats = _playerDetails?.seasonStats ?? {};
    final allStats = {...stats, ...seasonStats};

    double readStat(List<String> keys) {
      for (final key in keys) {
        if (allStats.containsKey(key)) {
          final v = num.tryParse('${allStats[key]}');
          if (v != null) return v.toDouble();
        }
      }
      return 0.0;
    }

    final goalsPer90 = readStat(['goalsPer90', 'goals_per_90', 'G/90']);
    final shots = readStat(['shots', 'totalShots', 'Shots']);
    final shotsOnTarget = readStat(['shotsOnTarget', 'SOT']);
    final passAccuracy = readStat(['passAccuracy', 'passingAccuracy', 'Pass%']);
    final tackles = readStat(['tackles', 'totalTackles', 'Tackles']);
    final interceptions = readStat(['interceptions', 'Int']);

    // Which attribute weighting to apply — a defender shouldn't be judged
    // by the same yardstick as a striker. See _detectPositionRole and
    // _roleWeights below.
    final role = _detectPositionRole(
      _playerDetails?.preferredPosition ?? _playerDetails?.position,
    );
    final roleWeights = _roleWeights(role);

    // ── Reference ceilings ──────────────────────────────────────────────
    // These are calibrated against real elite-tier output, not a
    // theoretical max. The previous ceilings (100% pass accuracy, 3.5
    // shots-on-target/game, etc.) were far above what even the best
    // players in the world ever actually post, so nobody — including
    // Messi, Ronaldo, Mbappé — could get close to them, and every OVR
    // landed in the 50s-60s no matter how good the player. These numbers
    // instead sit just above what a genuine world-class season looks like
    // (e.g. ~0.95 goals/90 is a Ballon d'Or-level scoring rate, ~88%
    // pass accuracy is elite for an attacking player), so a truly elite
    // season now actually reads as elite.
    final attributes = <_AnalyticsAttribute>[
      _AnalyticsAttribute('ATTACK', goalsPer90, 1.0, Icons.sports_soccer_rounded,
          weight: roleWeights['ATTACK']!),
      _AnalyticsAttribute('SHOTS', shots, 5.5, Icons.gps_fixed_rounded,
          weight: roleWeights['SHOTS']!),
      _AnalyticsAttribute('ACCURACY', shotsOnTarget, 2.8, Icons.adjust_rounded,
          weight: roleWeights['ACCURACY']!),
      _AnalyticsAttribute('PASSING', passAccuracy, 92.0, Icons.compare_arrows_rounded,
          weight: roleWeights['PASSING']!),
      // Tackles/interceptions are kept on the radar for context regardless
      // of role (a striker genuinely doesn't tackle much, a keeper doesn't
      // either — that's real and fine to show), but how much they count
      // toward OVR now depends on the player's actual job.
      _AnalyticsAttribute('TACKLES', tackles, 1.6, Icons.shield_rounded,
          weight: roleWeights['TACKLES']!),
      _AnalyticsAttribute('DEFENSE', interceptions, 0.7, Icons.security_rounded,
          weight: roleWeights['DEFENSE']!),
    ];

    final rawRatios = attributes.map((a) => (a.value / a.maxRef).clamp(0.0, 1.0)).toList();

    // Curve each ratio with sqrt(): a real elite season typically sits at
    // ~70-90% of ceiling rather than literally hitting it, and a flat
    // linear scale mapped that straight to a 70-90 OVR-equivalent already
    // — except once averaged with the near-zero defensive ratios above,
    // it collapsed into the 50s. sqrt() lifts the upper-middle of the
    // range (0.7 → 0.84, 0.9 → 0.95) without ever changing 0 or 1, so the
    // ordering between players is preserved — it's a rescale, not a fudge.
    final curved = rawRatios.map((r) => math.sqrt(r)).toList();

    final weightSum = attributes.fold<double>(0.0, (sum, a) => sum + a.weight);
    double weightedSum = 0.0;
    for (int i = 0; i < attributes.length; i++) {
      weightedSum += curved[i] * attributes[i].weight;
    }
    final overallRatio = weightSum > 0 ? weightedSum / weightSum : 0.0;
    final overall = (overallRatio * 99).round().clamp(1, 99);

    final statsSeason = allStats['statsSeason']?.toString() ?? '';
    final statsTeam = allStats['statsTeam']?.toString() ?? '';
    final subtitle = [statsTeam, statsSeason].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kPrimaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.directions_run, size: 16, color: _kPrimaryGreen),
              ),
              const SizedBox(width: 10),
              Text(
                'PLAYER ANALYTICS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _mutedColor,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (subtitle.isNotEmpty)
                Flexible(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _mutedColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _mutedColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Rated as ${_roleLabel(role)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _mutedColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dark "premium" panel behind the radar — makes the green pop
          // and reads as a stats-broadcast graphic rather than a form field.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B1730), Color(0xFF102A18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _kPrimaryGreen.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                height: 232,
                width: 232,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) {
                        return CustomPaint(
                          size: const Size(232, 232),
                          painter: _RadarChartPainter(
                            values: curved.map((v) => v * t).toList(),
                            labels: attributes.map((a) => a.label).toList(),
                            lineColor: _kPrimaryGreen,
                            fillColor: _kPrimaryGreen,
                            gridColor: Colors.white.withOpacity(0.12),
                            labelColor: Colors.white.withOpacity(0.8),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimaryGreen,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: _kPrimaryGreen.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                        child: Text(
                          'OVR $overall',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          if (role == _PositionRole.goalkeeper)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Goalkeeper rating is based on passing distribution and '
                    'defensive actions — save %, clean sheets, and shot-stopping '
                    'data aren\'t available yet.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: _mutedColor,
                  height: 1.4,
                ),
              ),
            ),

          // Attribute breakdown — sporty gradient progress bars
          ...attributes.asMap().entries.map((entry) {
            final i = entry.key;
            final attr = entry.value;
            final ratio = curved[i];
            final displayValue = attr.value % 1 == 0
                ? attr.value.toStringAsFixed(0)
                : attr.value.toStringAsFixed(2);

            return Padding(
              padding: EdgeInsets.only(bottom: i == attributes.length - 1 ? 0 : 12),
              child: Row(
                children: [
                  Icon(attr.icon, size: 14, color: _kPrimaryGreen),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: Text(
                      attr.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _mutedColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: ratio),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) {
                          return Stack(
                            children: [
                              Container(height: 8, color: _kPrimaryGreen.withOpacity(0.1)),
                              FractionallySizedBox(
                                widthFactor: t <= 0 ? 0.0 : t,
                                child: Container(
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text(
                      displayValue,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── SEASON STATISTICS ──────────────────────────────────────────────────────

  Widget _buildSeasonStatsCard() {
    final stats = _playerDetails?.statistics ?? {};
    final seasonStats = _playerDetails?.seasonStats ?? {};
    final allStats = {...stats, ...seasonStats};

    // These keys are produced by ApiService.getPlayerSeasonStatsApiFootball
    // (scoped to the league the player is currently playing in). Older
    // fallback key spellings are kept alongside in case ESPN/SportsDB ever
    // do populate their own equivalents.
    final statPairs = [
      {'label': 'Goals per 90', 'keys': ['goalsPer90', 'goals_per_90', 'G/90']},
      {'label': 'Shots', 'keys': ['shots', 'totalShots', 'Shots']},
      {'label': 'Shots on Target', 'keys': ['shotsOnTarget', 'SOT']},
      {'label': 'Pass Accuracy', 'keys': ['passAccuracy', 'passingAccuracy', 'Pass%']},
      {'label': 'Tackles', 'keys': ['tackles', 'totalTackles', 'Tackles']},
      {'label': 'Interceptions', 'keys': ['interceptions', 'Int']},
    ];

    final displayStats = statPairs.map((pair) {
      String value = '0';
      for (final key in pair['keys'] as List<String>) {
        if (allStats.containsKey(key)) {
          final v = allStats[key];
          if (v != null && v.toString().isNotEmpty) {
            value = v.toString();
            break;
          }
        }
      }
      return {
        'label': pair['label'] as String,
        'value': value,
      };
    }).toList();

    final statsTeam = allStats['statsTeam']?.toString() ?? '';
    final statsLeague = allStats['statsLeague']?.toString() ?? '';
    final statsSeason = allStats['statsSeason']?.toString() ?? '';
    final rating = allStats['rating']?.toString() ?? '';
    final minutes = allStats['minutes']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SEASON STATISTICS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _mutedColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
            children: displayStats.map((pair) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pair['value'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      pair['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _mutedColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (displayStats.every((s) => s['value'] == '0'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'No season statistics available for this player yet',
                  style: TextStyle(
                    fontSize: 12,
                    color: _mutedColor,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (statsLeague.isNotEmpty || rating.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (statsLeague.isNotEmpty)
                    _buildSeasonStatsFootnote(
                      Icons.bar_chart_rounded,
                      '$statsLeague${statsSeason.isNotEmpty ? " • $statsSeason" : ""}'
                          '${statsTeam.isNotEmpty ? " • $statsTeam" : ""}',
                    ),
                  if (rating.isNotEmpty)
                    _buildSeasonStatsFootnote(Icons.star_rounded, 'Avg rating $rating'),
                  if (minutes.isNotEmpty && minutes != '0')
                    _buildSeasonStatsFootnote(Icons.schedule_rounded, '$minutes mins'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonStatsFootnote(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: _mutedColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: _mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── PLAYER INFO CARD (Bio) ────────────────────────────────────────────────

  Widget _buildPlayerInfoCard() {
    final player = _playerDetails;

    final infoItems = [
      {'label': 'Birth Place', 'value': player?.birthPlace ?? 'N/A'},
      {'label': 'Birth Date', 'value': player?.birthDate?.isNotEmpty == true
          ? player!.birthDate
          : 'N/A'},
      {'label': 'Height', 'value': player?.displayHeight ?? 'N/A'},
      {'label': 'Weight', 'value': player?.displayWeight ?? 'N/A'},
      {'label': 'Age', 'value': player?.displayAge ?? 'N/A'},
      {'label': 'Experience', 'value': player?.experienceDisplay ?? 'N/A'},
      {'label': 'Position', 'value': player?.preferredPosition?.isNotEmpty == true
          ? player!.preferredPosition
          : player?.positionDisplay ?? 'N/A'},
      {'label': 'Foot', 'value': player?.foot?.isNotEmpty == true
          ? player!.foot
          : 'N/A'},
    ];

    // Add contract/market info if available
    final extraItems = <Map<String, String>>[];
    if (player?.contractExpiry?.isNotEmpty == true) {
      extraItems.add({
        'label': 'Contract Until',
        'value': player!.contractExpiry!
      });
    }
    if (player?.marketValue != null && player!.marketValue! > 0) {
      extraItems.add({
        'label': 'Market Value',
        'value': player.marketValueDisplay
      });
    }

    final allItems = [...infoItems, ...extraItems];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PLAYER INFO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _mutedColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _mutedColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── INJURY CARD ────────────────────────────────────────────────────────────

  Widget _buildInjuryCard() {
    final player = _playerDetails;
    final status = player?.injuryStatus ?? '';
    final statusColor = player?.injuryColor ?? const Color(0xFF16A34A);
    final label = player?.injuryLabel ?? 'Available';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusColor == const Color(0xFF16A34A)
                  ? Icons.check_circle_rounded
                  : statusColor == const Color(0xFFCA8A04)
                  ? Icons.warning_amber_rounded
                  : Icons.error_rounded,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INJURY STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _mutedColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (status.isNotEmpty && !status.toLowerCase().contains('healthy'))
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      color: _mutedColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CAREER STATS CARD ──────────────────────────────────────────────────────

  Widget _buildCareerStatsCard() {
    final careerStats = _playerDetails?.careerStats ?? [];
    if (careerStats.isEmpty) return const SizedBox.shrink();

    final shownStats = careerStats.length > 5 ? careerStats.sublist(0, 5) : careerStats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.history_rounded, size: 16, color: _primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                'CAREER HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _mutedColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(shownStats.length, (index) {
            final season = shownStats[index];
            final seasonName = season['season']?.toString() ?? 'N/A';
            final teamName = season['team']?.toString() ?? '';
            final goals = season['goals']?.toString() ?? '0';
            final assists = season['assists']?.toString() ?? '0';
            final appearances = season['appearances']?.toString() ?? '0';

            return Padding(
              padding: EdgeInsets.only(bottom: index == shownStats.length - 1 ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    _buildClubCrest(teamName),
                    const SizedBox(width: 10),
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        seasonName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (teamName.isNotEmpty)
                            Text(
                              teamName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildCareerStatBadge(
                                icon: Icons.sports_soccer_rounded,
                                value: goals,
                                color: _kPrimaryGreen,
                              ),
                              const SizedBox(width: 8),
                              _buildCareerStatBadge(
                                icon: Icons.share_rounded,
                                value: assists,
                                color: _kSecondaryBlue,
                              ),
                              const SizedBox(width: 8),
                              _buildCareerStatBadge(
                                icon: Icons.event_note_rounded,
                                value: appearances,
                                color: _mutedColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (careerStats.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Text(
                  'Showing 5 of ${careerStats.length} seasons',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _mutedColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Small circular club crest for a Career History row. Uses the curated,
  /// verified ESPN logo mapping in predefined_data.dart — TheSportsDB's
  /// free-tier team search always returns Arsenal's badge regardless of
  /// query (see sport_service.dart notes), so it isn't a safe source here.
  /// Falls back to a generic shield icon for clubs we don't have a
  /// confirmed crest id for, or if the image fails to load.
  Widget _buildClubCrest(String teamName) {
    final logoUrl = teamName.isNotEmpty ? getClubLogoUrl(teamName) : null;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _primaryColor.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null
          ? Padding(
        padding: const EdgeInsets.all(4),
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.shield_outlined,
            size: 16,
            color: _mutedColor,
          ),
        ),
      )
          : Icon(
        Icons.shield_outlined,
        size: 16,
        color: _mutedColor,
      ),
    );
  }

  Widget _buildCareerStatBadge({required IconData icon, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Broad tactical role used to decide which stats should drive the OVR
/// composite. Deliberately coarse (4 buckets, not 15 sub-positions) since
/// the underlying stat line (goals/shots/passing/tackles/interceptions)
/// can't meaningfully distinguish a CB from a full-back anyway.
enum _PositionRole { forward, midfielder, defender, goalkeeper }

/// Maps a raw position string (e.g. "FW", "Forward", "CDM", "Centre-Back",
/// "GK") to a [_PositionRole]. Falls back to [_PositionRole.forward] when
/// the position is missing/unrecognized, matching this dataset's bias
/// toward attacking players — safer default than accidentally judging an
/// unknown player on defensive output they were never trying to produce.
_PositionRole _detectPositionRole(String? rawPosition) {
  final p = (rawPosition ?? '').toUpperCase().trim();
  if (p.isEmpty) return _PositionRole.forward;

  if (p.contains('GK') || p.contains('KEEPER')) {
    return _PositionRole.goalkeeper;
  }
  if (p.contains('DF') ||
      p.contains('DEFEN') ||
      p.contains('BACK') ||
      p == 'CB' ||
      p == 'LB' ||
      p == 'RB' ||
      p == 'LWB' ||
      p == 'RWB' ||
      p == 'SWEEPER') {
    return _PositionRole.defender;
  }
  if (p.contains('MF') ||
      p.contains('MID') ||
      p == 'CM' ||
      p == 'CDM' ||
      p == 'CAM' ||
      p == 'DM' ||
      p == 'AM') {
    return _PositionRole.midfielder;
  }
  // FW, ST, CF, W, LW, RW, "Forward", "Striker", "Winger" etc.
  return _PositionRole.forward;
}

/// Attribute weights (must sum to 1.0) for the OVR composite, tuned per
/// role so each player is judged on what their job actually is:
///  - Forwards: mostly attacking output.
///  - Midfielders: passing-led, with a real but secondary mix of both ends.
///  - Defenders: mostly defensive actions; attacking stats barely count.
///  - Goalkeepers: this dataset has no save/clean-sheet stats, so distribution
///    (passing) and defensive actions (as a rough sweeper-keeper proxy) are
///    all there is to go on — attacking stats get zero weight since they're
///    not meaningful for a keeper.
Map<String, double> _roleWeights(_PositionRole role) {
  switch (role) {
    case _PositionRole.forward:
      return {
        'ATTACK': 0.30, 'SHOTS': 0.20, 'ACCURACY': 0.20,
        'PASSING': 0.20, 'TACKLES': 0.05, 'DEFENSE': 0.05,
      };
    case _PositionRole.midfielder:
      return {
        'ATTACK': 0.18, 'SHOTS': 0.12, 'ACCURACY': 0.10,
        'PASSING': 0.30, 'TACKLES': 0.15, 'DEFENSE': 0.15,
      };
    case _PositionRole.defender:
      return {
        'ATTACK': 0.05, 'SHOTS': 0.05, 'ACCURACY': 0.05,
        'PASSING': 0.25, 'TACKLES': 0.30, 'DEFENSE': 0.30,
      };
    case _PositionRole.goalkeeper:
      return {
        'ATTACK': 0.0, 'SHOTS': 0.0, 'ACCURACY': 0.0,
        'PASSING': 0.60, 'TACKLES': 0.20, 'DEFENSE': 0.20,
      };
  }
}

String _roleLabel(_PositionRole role) {
  switch (role) {
    case _PositionRole.forward:
      return 'Forward';
    case _PositionRole.midfielder:
      return 'Midfielder';
    case _PositionRole.defender:
      return 'Defender';
    case _PositionRole.goalkeeper:
      return 'Goalkeeper';
  }
}

/// One axis of the analytics radar: a display label, the raw stat value,
/// a reference ceiling used to normalize it onto a 0-1 scale, an icon for
/// the attribute bar, and a weight used only when rolling attributes up
/// into the single OVR badge (see _buildAnalyticsCard for why attacking
/// stats are weighted far higher than defensive ones there).
class _AnalyticsAttribute {
  final String label;
  final double value;
  final double maxRef;
  final IconData icon;
  final double weight;

  const _AnalyticsAttribute(this.label, this.value, this.maxRef, this.icon, {this.weight = 1.0});
}

/// Lightweight hexagonal radar/spider chart, drawn with CustomPainter so
/// the project doesn't need a charting package dependency just for this.
/// [values] are expected pre-normalized to 0.0–1.0.
class _RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;

  _RadarChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 34; // room for labels
    final sides = values.length;
    final angleStep = (2 * math.pi) / sides;

    double angleFor(int i) => -math.pi / 2 + angleStep * i;

    // Grid rings
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * ring / 4;
      final path = Path();
      for (int i = 0; i < sides; i++) {
        final angle = angleFor(i);
        final point = Offset(
          center.dx + ringRadius * math.cos(angle),
          center.dy + ringRadius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // Axis spokes
    for (int i = 0; i < sides; i++) {
      final angle = angleFor(i);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, point, gridPaint);
    }

    // Data polygon
    final dataPath = Path();
    final dataPoints = <Offset>[];
    for (int i = 0; i < sides; i++) {
      final angle = angleFor(i);
      final v = values[i].clamp(0.0, 1.0);
      final point = Offset(
        center.dx + radius * v * math.cos(angle),
        center.dy + radius * v * math.sin(angle),
      );
      dataPoints.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [fillColor.withOpacity(0.55), fillColor.withOpacity(0.10)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // Vertex dots with a soft glow
    final dotGlowPaint = Paint()..color = lineColor.withOpacity(0.35);
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in dataPoints) {
      canvas.drawCircle(p, 6, dotGlowPaint);
      canvas.drawCircle(p, 3.5, dotPaint);
      canvas.drawCircle(p, 3.5, dotBorderPaint);
    }

    // Axis labels
    for (int i = 0; i < sides; i++) {
      final angle = angleFor(i);
      final labelRadius = radius + 22;
      final point = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(point.dx - tp.width / 2, point.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.values.toString() != values.toString() ||
        oldDelegate.lineColor != lineColor;
  }
}