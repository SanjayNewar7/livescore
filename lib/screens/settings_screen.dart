// lib/screens/settings_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/services/profile_service.dart';
import 'package:livescore/services/quiz_service.dart';
import 'package:livescore/models/quiz_model.dart';
import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/models/team_model.dart';
import 'package:flutter/services.dart';

import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'quiz_screen.dart';
import 'privacy_policy_screen.dart';
import 'developer_screen.dart';
import 'team_detail_screen.dart';

// ── App Links ──────────────────────────────────────────────────────
class _AppLinks {
  static const String privacyPolicyUrl = 'https://raw.githubusercontent.com/SanjayNewar7/livescore/master/privacy_policy.md';
  static const String developerUrl = 'https://sanjayrajbhandari.com.np/';
  static const String feedbackEmail = 'sanjaynewar007@gmail.com';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.sanjaya.livegoal';
  static const String buyMeCoffeeUrl = 'https://buymeacoffee.com/sanjay_newar7';
  static const String appVersion = '1.0.0';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _blue = Color(0xFF1A62C8);
  static const Color _darkBlue = Color(0xFF0D3F85);
  static const Color _green = Color(0xFF16A34A);
  static const Color _ink = Color(0xFF0F1623);
  static const Color _bg = Color(0xFFF5F7FB);

  UserProfile _profile = UserProfile.empty;

  // Rotates the "Favorite Club" tile through UserPreferences.favoriteTeamIds
  // (the multi-team list from onboarding / the favorites-screen manage
  // sheet) every 15 seconds when more than one team is set. Single-team or
  // no-team cases render statically - nothing to rotate through.
  Timer? _favoriteTeamRotationTimer;
  int _favoriteTeamRotationIndex = 0;

  @override
  void initState() {
    super.initState();
    _profile = ProfileService().profile;
    _favoriteTeamRotationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() => _favoriteTeamRotationIndex++);
    });
  }

  @override
  void dispose() {
    _favoriteTeamRotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    if (mounted) setState(() => _profile = ProfileService().profile);
  }

  Future<void> _openFavorites() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
    if (mounted) setState(() => _profile = ProfileService().profile);
  }

  Future<void> _openQuiz() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen()));
    if (mounted) setState(() {}); // refresh quiz status card
  }

  Future<void> _openPrivacyPolicy() async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
  }

  Future<void> _openDeveloper() async {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperScreen()));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link'), backgroundColor: Color(0xFFDC2626)),
      );
    }
  }

  Future<void> _sendFeedback() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _AppLinks.feedbackEmail,
      query: 'subject=${Uri.encodeComponent('LiveScore App Feedback')}&body=${Uri.encodeComponent('Hi Sanjaya,\n\nI would like to share my feedback about the LiveScore app:\n\n')}',
    );
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open mail app'), backgroundColor: Color(0xFFDC2626)),
      );
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Navigate back to home screen by popping until the first route
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Profile ──────────────────────────────────────────────
          _buildProfileCard(),
          const SizedBox(height: 12),
          _buildFavoritesRow(),
          const SizedBox(height: 20),

          // ── Play Quiz ────────────────────────────────────────────
          _buildSectionHeader('Play Quiz', Icons.quiz_outlined),
          const SizedBox(height: 8),
          _buildQuizCard(),
          const SizedBox(height: 20),

          // ── Data & Storage ───────────────────────────────────────
          _buildSectionHeader('Data & Storage', Icons.storage_outlined),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildActionTile(
              icon: Icons.delete_outline,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () => _showClearCacheDialog(context),
              iconColor: const Color(0xFFDC2626),
              showArrow: true,
            ),
          ]),
          const SizedBox(height: 20),

          // ── Favorite Teams (match feed filter) ──────────────────
          _buildSectionHeader('Favorite Teams', Icons.people_outline),
          const SizedBox(height: 8),
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              final favorites = provider.favoriteTeamIds;
              if (favorites.isEmpty) {
                return _buildEmptyFavoritesCard();
              }
              return _buildSettingsCard(
                favorites.map((teamId) {
                  TeamInfo team;
                  try {
                    team = provider.allTeams.firstWhere((t) => t.id == teamId);
                  } catch (_) {
                    // ✅ FIX: Create TeamInfo with ESPN official logo URL
                    team = TeamInfo(
                      id: teamId,
                      name: teamId,
                      displayName: teamId,
                      abbreviation: teamId.length > 3 ? teamId.substring(0, 3).toUpperCase() : teamId,
                      logo: 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png', // ✅ ESPN official logo
                      color: '#1A62C8',
                      alternateColor: '#FFFFFF',
                      record: '0-0-0',
                    );
                  }
                  return _buildFavoriteTeamTile(team, provider);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Favorite Players (same list/tile format as Favorite Teams
          //    above, sourced from the up-to-4 players picked in onboarding
          //    or the favorites-screen manage sheet) ────────────────────
          _buildSectionHeader('Favorite Players', Icons.person_outline),
          const SizedBox(height: 8),
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              final favoritePlayers = provider.favoritePlayers;
              if (favoritePlayers.isEmpty) {
                return _buildEmptyFavoritesCard(
                  title: 'No Favorite Players',
                  subtitle: 'Go to Players tab to add your favorite players',
                  icon: Icons.person_outline,
                );
              }
              return _buildSettingsCard(
                favoritePlayers.map((player) {
                  return _buildFavoritePlayerTile(player, provider);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Buy Me a Coffee ──────────────────────────────────────
          _buildSectionHeader('Buy Me a Coffee', Icons.volunteer_activism_outlined),
          const SizedBox(height: 8),
          _buildCoffeeCard(),
          const SizedBox(height: 20),

          // ── About ────────────────────────────────────────────────
          _buildSectionHeader('About', Icons.info_outline),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildInfoTile(
              icon: Icons.info_outline,
              title: 'Version',
              value: _AppLinks.appVersion,
              iconColor: _blue,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: _openPrivacyPolicy,
              iconColor: _blue,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.code_outlined,
              title: 'Developer',
              onTap: _openDeveloper,
              iconColor: _blue,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              onTap: _sendFeedback,
              iconColor: _blue,
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.star_outline,
              title: 'Rate App',
              onTap: () => _openUrl(_AppLinks.playStoreUrl),
              iconColor: _blue,
            ),
          ]),
          const SizedBox(height: 30),

          Center(
            child: Text(
              'LiveScore © 2026',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Profile ──────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _openEditProfile,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_blue, _darkBlue],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: ClipOval(
                  child: _profile.hasImage
                      ? Image.file(File(_profile.imagePath!), fit: BoxFit.cover, width: 60, height: 60)
                      : Center(
                    child: Text(
                      _profile.initials,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _blue),
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
                      _profile.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profile.bio.trim().isNotEmpty ? _profile.bio.trim() : 'Tap to set up your profile',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(width: 4),
                    Text('Edit', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesRow() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final favoriteTeamIds = provider.favoriteTeamIds;
        final hasMultipleTeams = favoriteTeamIds.length > 1;

        TeamInfo? rotatingTeam;
        int shownPosition = 0;
        if (favoriteTeamIds.isNotEmpty) {
          shownPosition = _favoriteTeamRotationIndex % favoriteTeamIds.length;
          rotatingTeam = _resolveFavoriteTeam(favoriteTeamIds[shownPosition], provider);
        }

        final clubLabel = hasMultipleTeams
            ? 'Favorite Club (${shownPosition + 1}/${favoriteTeamIds.length})'
            : 'Favorite Club';
        final clubName = rotatingTeam != null
            ? rotatingTeam.displayName
            : (_profile.hasFavoriteClub ? _profile.favoriteClubName ?? '' : 'Not set');
        final clubImage = rotatingTeam != null
            ? (rotatingTeam.logo.isNotEmpty
            ? rotatingTeam.logo
            : 'https://a.espncdn.com/i/teamlogos/soccer/500/${rotatingTeam.id}.png')
            : _profile.favoriteClubLogo;

        return Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildFavoriteChip(
                  key: ValueKey(rotatingTeam?.id ?? clubName),
                  label: clubLabel,
                  name: clubName,
                  imageUrl: clubImage,
                  fallbackIcon: Icons.shield_outlined,
                  accent: _blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildRotatingFavoritePlayerChip(provider),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Same rotate-every-15s pattern as the Favorite Club chip above, but
  /// sourced from the up-to-4 players in UserPreferences.favoritePlayers
  /// (onboarding / favorites-screen manage sheet) instead of the single
  /// profile-level favorite. Falls back to the profile's favorite player
  /// only when that list is empty.
  Widget _buildRotatingFavoritePlayerChip(AppProvider provider) {
    final favoritePlayers = provider.favoritePlayers;

    if (favoritePlayers.isEmpty) {
      return _buildFavoriteChip(
        key: const ValueKey('profile_favorite_player'),
        label: 'Favorite Player',
        name: _profile.hasFavoritePlayer ? _profile.favoritePlayerName ?? '' : 'Not set',
        imageUrl: _profile.favoritePlayerImage,
        fallbackIcon: Icons.person_outline,
        accent: _green,
      );
    }

    final shownPosition = _favoriteTeamRotationIndex % favoritePlayers.length;
    final player = favoritePlayers[shownPosition];
    final hasMultiplePlayers = favoritePlayers.length > 1;

    return _buildFavoriteChip(
      key: ValueKey('fav_player_${player['id'] ?? shownPosition}'),
      label: hasMultiplePlayers
          ? 'Favorite Player (${shownPosition + 1}/${favoritePlayers.length})'
          : 'Favorite Player',
      name: player['name']?.trim().isNotEmpty == true ? player['name']! : 'Unknown Player',
      imageUrl: player['image'],
      fallbackIcon: Icons.person_outline,
      accent: _green,
    );
  }

  /// Resolves a favorite-team id to a TeamInfo using whatever AppProvider has
  /// already loaded, falling back to a stub with the ESPN official logo URL
  /// (same fallback pattern already used in the "Favorite Teams" list below).
  TeamInfo _resolveFavoriteTeam(String teamId, AppProvider provider) {
    try {
      return provider.allTeams.firstWhere((t) => t.id == teamId);
    } catch (_) {
      return TeamInfo(
        id: teamId,
        name: teamId,
        displayName: teamId,
        abbreviation: teamId.length > 3 ? teamId.substring(0, 3).toUpperCase() : teamId,
        logo: 'https://a.espncdn.com/i/teamlogos/soccer/500/$teamId.png',
        color: '#1A62C8',
        alternateColor: '#FFFFFF',
        record: '0-0-0',
      );
    }
  }

  Widget _buildFavoriteChip({
    Key? key,
    required String label,
    required String name,
    required String? imageUrl,
    required IconData fallbackIcon,
    required Color accent,
  }) {
    return GestureDetector(
      key: key,
      onTap: _openFavorites,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _favoriteFallbackIcon(fallbackIcon, accent),
                placeholder: (context, url) => _favoriteFallbackIcon(fallbackIcon, accent),
              )
                  : _favoriteFallbackIcon(fallbackIcon, accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoriteFallbackIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: color),
    );
  }

  // ── Play Quiz ────────────────────────────────────────────────────

  Widget _buildQuizCard() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    return FutureBuilder<QuizDailySet>(
      future: QuizService().getTodayQuiz(provider),
      builder: (context, snapshot) {
        final quiz = snapshot.data;
        final stats = QuizService().stats;

        String statusLabel;
        String buttonLabel;
        if (quiz == null) {
          statusLabel = 'Loading today\'s quiz...';
          buttonLabel = 'Play';
        } else if (quiz.isFullyAnswered) {
          statusLabel = '${quiz.correctCount} / ${quiz.questions.length} correct today';
          buttonLabel = 'View Results';
        } else if (quiz.answeredCount > 0) {
          statusLabel = '${quiz.answeredCount} / ${quiz.questions.length} answered';
          buttonLabel = 'Continue';
        } else {
          statusLabel = '10 new questions ready';
          buttonLabel = 'Play Now';
        }

        return GestureDetector(
          onTap: _openQuiz,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_green, Color(0xFF0F7A3D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Football Quiz', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(statusLabel, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text('${stats.totalBalls} balls collected', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Text(buttonLabel, style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Buy Me a Coffee ──────────────────────────────────────────────

  Widget _buildCoffeeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_cafe_outlined, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enjoying the app?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This app is built and maintained independently. If it helps you follow the game, consider supporting its development with a coffee.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openUrl(_AppLinks.buyMeCoffeeUrl),
              icon: const Icon(Icons.favorite_rounded, size: 18),
              label: const Text('Buy Me a Coffee', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared building blocks ───────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _blue),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _blue, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    bool showArrow = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: showArrow ? const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7A96)) : null,
      onTap: onTap,
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7A96)),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink)),
      trailing: Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _openTeamDetail(TeamInfo team) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDetailScreen(
          team: team,
          leagueCode: provider.currentLeagueCode,
        ),
      ),
    );
  }

  Widget _buildFavoriteTeamTile(TeamInfo team, AppProvider provider) {
    // ✅ FIX: Build ESPN official logo URL
    final logoUrl = team.logo.isNotEmpty
        ? team.logo
        : 'https://a.espncdn.com/i/teamlogos/soccer/500/${team.id}.png';

    return Dismissible(
      key: Key(team.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => provider.toggleFavoriteTeam(team.id),
      child: ListTile(
        onTap: () => _openTeamDetail(team),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: logoUrl,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _blue))),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.sports_soccer_rounded, size: 20, color: _blue),
            ),
          ),
        ),
        title: Text(team.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
        subtitle: Text(team.abbreviation, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () => provider.toggleFavoriteTeam(team.id),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesCard({
    String title = 'No Favorite Teams',
    String subtitle = 'Go to Teams tab to add your favorite teams',
    IconData icon = Icons.favorite_border,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: _blue.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: _blue),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Same tile format as [_buildFavoriteTeamTile] (swipe-to-delete list
  /// tile, circular avatar leading, name + subtitle, trailing delete
  /// button) applied to a favorite-player map ({id, name, image, team}).
  Widget _buildFavoritePlayerTile(Map<String, String> player, AppProvider provider) {
    final id = player['id'] ?? '';
    final name = player['name']?.trim().isNotEmpty == true ? player['name']! : 'Unknown Player';
    final team = player['team'] ?? '';
    final imageUrl = player['image'] ?? '';
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Dismissible(
      key: Key('fav_player_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => provider.removeFavoritePlayer(id),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: imageUrl,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
              child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _green))),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
              child: Center(child: Text(initials, style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 13))),
            ),
          )
              : Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
            child: Center(child: Text(initials, style: const TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 13))),
          ),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
        subtitle: team.isNotEmpty ? Text(team, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)) : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () => provider.removeFavoritePlayer(id),
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, thickness: 1, color: Colors.grey.shade100);

  void _showClearCacheDialog(BuildContext context) async {
    const Color danger = Color(0xFFDC2626);
    const Color muted = Color(0xFF6B7A96);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon header, matches the card gradients used elsewhere
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 28, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [danger.withOpacity(0.08), danger.withOpacity(0.02)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: danger.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: danger, size: 32),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Clear Cache',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This removes cached scores, standings, and images to free up storage. '
                          'Your profile, favorites, and quiz progress are not affected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: muted,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await CacheService().clearAllCache();
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cache cleared successfully'),
                                    backgroundColor: _green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Clear Cache', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
      ),
    );
  }
}