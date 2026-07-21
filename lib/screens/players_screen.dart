// lib/screens/player_screen.dart
import 'package:flutter/material.dart';
import 'package:livescore/models/player_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:livescore/models/game_model.dart';
import 'package:livescore/services/sport_service.dart';
import 'package:livescore/widgets/football_pitch_lineup.dart';
import 'package:livescore/utils/constants.dart';

/// Player screen that displays detailed player information
/// Opens when clicking on a player in the lineup tab of game_detail_screen
class PlayerScreen extends StatefulWidget {
  final PitchPlayer player;
  final Game? game;
  final TeamInfo? teamInfo;

  const PlayerScreen({
    super.key,
    required this.player,
    this.game,
    this.teamInfo,
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
  Color _primaryColor = const Color(0xFF1A56DB);
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

  /// Load player details from ESPN API
  Future<void> _loadPlayerDetails() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final leagueCode = _getLeagueCodeFromName(widget.game?.leagueName ?? '');

      Player? playerDetails;

      if (widget.player.id.isNotEmpty) {
        try {
          playerDetails = await _sportService.getPlayerDetails(
            widget.player.id,
            leagueCode: leagueCode,
          );
          print('[PlayerScreen] ✅ Loaded: ${playerDetails.displayName}');
          print('[PlayerScreen] Stats: ${playerDetails.statistics}');
          print('[PlayerScreen] SeasonStats: ${playerDetails.seasonStats}');
          print('[PlayerScreen] Nationality: ${playerDetails.nationality}');
          print('[PlayerScreen] BirthDate: ${playerDetails.birthDate}');
          print('[PlayerScreen] Headshot from API: ${playerDetails.headshot}');
        } catch (e) {
          print('[PlayerScreen] API fetch failed: $e');
        }
      }

      if (playerDetails != null && playerDetails.id.isNotEmpty) {
        _playerDetails = playerDetails;
      } else {
        _playerDetails = _createPlayerFromPitchPlayer(widget.player);
      }

      if (widget.teamInfo != null) {
        _primaryColor = _parseColor(widget.teamInfo!.color);
      } else {
        _primaryColor = widget.player.isHome
            ? const Color(0xFF1A56DB)
            : const Color(0xFFEA580C);
      }

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();

    } catch (e) {
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

  /// ✅ FIXED: Properly preserve the headshot image from PitchPlayer
  Player _createPlayerFromPitchPlayer(PitchPlayer pitchPlayer) {
    print('[PlayerScreen] Creating player from PitchPlayer:');
    print('  Name: ${pitchPlayer.name}');
    print('  ID: ${pitchPlayer.id}');
    print('  Headshot: ${pitchPlayer.imageUrl}');

    return Player(
      id: pitchPlayer.id,
      fullName: pitchPlayer.name,
      displayName: pitchPlayer.name,
      // ✅ CRITICAL FIX: Use the imageUrl from PitchPlayer
      headshot: pitchPlayer.imageUrl ?? '',
      jersey: pitchPlayer.number,
      position: pitchPlayer.position,
      teamId: widget.teamInfo?.id ?? '',
      teamName: widget.teamInfo?.displayName ??
          (widget.player.isHome ? 'Home Team' : 'Away Team'),
      height: 0,
      weight: 0,
      age: 0,
      college: '',
      statistics: {},
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
    return const Color(0xFF1A56DB);
  }

  Color _getRatingColor(double? rating) {
    if (rating == null) return Colors.grey;
    if (rating >= 8.0) return const Color(0xFF16A34A);
    if (rating >= 6.5) return const Color(0xFF1A56DB);
    if (rating >= 5.0) return const Color(0xFFCA8A04);
    return const Color(0xFFDC2626);
  }

  String _getRatingLabel(double rating) {
    if (rating >= 8.5) return '⭐ Outstanding';
    if (rating >= 7.5) return '👏 Excellent';
    if (rating >= 6.5) return '👍 Good';
    if (rating >= 5.5) return '📊 Average';
    if (rating >= 4.5) return '⚠️ Below Average';
    return '❌ Poor';
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
        foregroundColor: _textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPlayerDetails,
            tooltip: 'Refresh',
          ),
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

                // Match Rating (if available)
                if (widget.player.rating != null)
                  _buildRatingCard(),

                const SizedBox(height: 16),

                // Season Statistics
                _buildSeasonStatsCard(),

                const SizedBox(height: 16),

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

    // ✅ FIXED: Properly get the headshot from Player or fallback to PitchPlayer
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
            padding: const EdgeInsets.all(20),
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
            child: Row(
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
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SUB',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFCA8A04),
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

    return GridView.count(
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
    );
  }

  String _extractStatValue(Map<String, dynamic> stats, Map<String, dynamic> seasonStats, List<String> keys) {
    for (final key in keys) {
      if (seasonStats.containsKey(key)) {
        final value = seasonStats[key];
        if (value != null && value.toString().isNotEmpty) {
          return value.toString();
        }
      }
    }
    for (final key in keys) {
      if (stats.containsKey(key)) {
        final value = stats[key];
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

  // ─── SEASON STATISTICS ──────────────────────────────────────────────────────

  Widget _buildSeasonStatsCard() {
    final stats = _playerDetails?.statistics ?? {};
    final seasonStats = _playerDetails?.seasonStats ?? {};
    final allStats = {...stats, ...seasonStats};

    final statPairs = [
      {'label': 'Goals per 90', 'keys': ['goalsPer90', 'goals_per_90', 'G/90']},
      {'label': 'Shots', 'keys': ['shots', 'totalShots', 'Shots']},
      {'label': 'Shots on Target', 'keys': ['shotsOnTarget', 'shotsOnTarget', 'SOT']},
      {'label': 'Pass Accuracy', 'keys': ['passAccuracy', 'passingAccuracy', 'Pass%']},
      {'label': 'Tackles', 'keys': ['tackles', 'totalTackles', 'Tackles']},
      {'label': 'Clearances', 'keys': ['clearances', 'totalClearances', 'Clear']},
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
                  'No season statistics available',
                  style: TextStyle(
                    fontSize: 12,
                    color: _mutedColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
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
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: careerStats.length > 5 ? 5 : careerStats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final season = careerStats[index];
              final seasonName = season['season']?.toString() ?? 'N/A';
              final teamName = season['team']?.toString() ?? '';
              final goals = season['goals']?.toString() ?? '0';
              final assists = season['assists']?.toString() ?? '0';
              final appearances = season['appearances']?.toString() ?? '0';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        seasonName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primaryColor,
                        ),
                        textAlign: TextAlign.center,
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
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Row(
                            children: [
                              _buildCareerStatBadge('⚽ $goals', _primaryColor),
                              const SizedBox(width: 8),
                              _buildCareerStatBadge('🎯 $assists', Colors.orange),
                              const SizedBox(width: 8),
                              _buildCareerStatBadge('📊 $appearances', _mutedColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (careerStats.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Showing 5 of ${careerStats.length} seasons',
                  style: TextStyle(
                    fontSize: 11,
                    color: _mutedColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCareerStatBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}