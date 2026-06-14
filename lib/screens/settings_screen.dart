import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livescore/providers/app_provider.dart';
import 'package:livescore/services/cache_service.dart';
import 'package:livescore/utils/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/team_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Profile Card
          _buildProfileCard(provider),
          const SizedBox(height: 20),

          // Appearance Section
          _buildSectionHeader('Appearance', Icons.palette_outlined),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              subtitle: 'Switch between light and dark theme',
              value: provider.isDarkMode,
              onChanged: (_) => provider.toggleTheme(),
              iconColor: const Color(0xFF1A62C8),
            ),
          ]),
          const SizedBox(height: 20),

          // Data & Storage Section
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

          // Preferences Section
          _buildSectionHeader('Preferences', Icons.favorite_border),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildNavigationTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Manage your alert preferences',
              onTap: () => _showComingSoon(context),
              iconColor: const Color(0xFF1A62C8),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.language_outlined,
              title: 'Language',
              subtitle: 'English (US)',
              onTap: () => _showComingSoon(context),
              iconColor: const Color(0xFF1A62C8),
            ),
          ]),
          const SizedBox(height: 20),

          // Favorite Teams Section
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
                  final team = provider.allTeams.firstWhere(
                        (t) => t.id == teamId,
                    orElse: () => TeamInfo(
                      id: '', name: '', displayName: teamId,
                      abbreviation: '', logo: '', color: '',
                      alternateColor: '', record: '',
                    ),
                  );
                  return _buildFavoriteTeamTile(team, provider);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // About Section
          _buildSectionHeader('About', Icons.info_outline),
          const SizedBox(height: 8),
          _buildSettingsCard([
            _buildInfoTile(
              icon: Icons.info_outline,
              title: 'Version',
              value: '1.0.0',
              iconColor: const Color(0xFF1A62C8),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => _showComingSoon(context),
              iconColor: const Color(0xFF1A62C8),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.feedback_outlined,
              title: 'Send Feedback',
              onTap: () => _showComingSoon(context),
              iconColor: const Color(0xFF1A62C8),
            ),
            _buildDivider(),
            _buildNavigationTile(
              icon: Icons.star_outline,
              title: 'Rate App',
              onTap: () => _showComingSoon(context),
              iconColor: const Color(0xFF1A62C8),
            ),
          ]),
          const SizedBox(height: 30),

          // Footer
          Center(
            child: Text(
              'LiveScore © 2024',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileCard(AppProvider provider) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A62C8), Color(0xFF0D3F85)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A62C8).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.sports_soccer_rounded,
                  size: 32,
                  color: Color(0xFF1A62C8),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Football Fan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.favoriteTeamIds.length} Favorite Teams',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
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
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A62C8)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A62C8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color iconColor,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1623),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1A62C8),
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
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1623),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: showArrow
          ? const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B7A96))
          : null,
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
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1623),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      )
          : null,
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
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F1623),
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFavoriteTeamTile(TeamInfo team, AppProvider provider) {
    return Dismissible(
      key: Key(team.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => provider.toggleFavoriteTeam(team.id),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: team.logo.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: team.logo,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            placeholder: (context, url) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A62C8).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1A62C8),
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A62C8).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.sports_soccer_rounded,
                size: 20,
                color: Color(0xFF1A62C8),
              ),
            ),
          )
              : Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1A62C8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              size: 20,
              color: Color(0xFF1A62C8),
            ),
          ),
        ),
        title: Text(
          team.displayName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F1623),
          ),
        ),
        subtitle: Text(
          team.abbreviation,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () => provider.toggleFavoriteTeam(team.id),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1A62C8).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 28,
              color: Color(0xFF1A62C8),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Favorite Teams',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F1623),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Go to Teams tab to add your favorite teams',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
    );
  }

  void _showClearCacheDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Clear Cache'),
        content: const Text(
          'Are you sure you want to clear all cached data? This will free up storage space.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7A96)),
            ),
          ),
          TextButton(
            onPressed: () async {
              setState(() => _isClearingCache = true);
              await CacheService().clearAllCache();
              setState(() => _isClearingCache = false);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cache cleared successfully'),
                    backgroundColor: Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming soon!'),
        backgroundColor: Color(0xFF1A62C8),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}