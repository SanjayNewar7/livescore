// lib/screens/edit_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/models/user_preferences.dart';
import 'package:livescore/services/profile_service.dart';
import 'package:livescore/services/preferences_service.dart';
import 'package:livescore/services/quiz_service.dart';
import 'package:livescore/utils/predefined_data.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ─── PALETTE ────────────────────────────────────────────────────────────
  static const Color _green = Color(0xFF16A34A);
  static const Color _greenDark = Color(0xFF0E7C39);
  static const Color _greenLight = Color(0xFFE6F7EC);
  static const Color _blue = Color(0xFF1A62C8);
  static const Color _blueLight = Color(0xFFE8F0FC);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _ink = Color(0xFF0F1623);
  static const Color _muted = Color(0xFF6B7A96);
  static const Color _bg = Color(0xFFF5F7FB);

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  UserProfile _profile = UserProfile.empty;
  UserPreferences _preferences = UserPreferences();
  bool _isSaving = false;
  bool _isPickingImage = false;
  int _totalBallsCollected = 0;
  String _footballFanSince = '';

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _profile = ProfileService().profile;
    _preferences = PreferencesService().preferences;
    _nameController = TextEditingController(text: _profile.name);
    _bioController = TextEditingController(text: _profile.bio);
    _loadStats();
    _loadAppInstallDate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = QuizService().stats;
    setState(() {
      _totalBallsCollected = stats.totalBalls;
    });
  }

  Future<void> _loadAppInstallDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installKey = 'app_install_date';
      String installDate = prefs.getString(installKey) ?? '';

      if (installDate.isEmpty) {
        installDate = DateTime.now().toIso8601String();
        await prefs.setString(installKey, installDate);
      }

      final installDateTime = DateTime.parse(installDate);
      final now = DateTime.now();
      final years = now.year - installDateTime.year;
      final months = now.month - installDateTime.month;
      final days = now.day - installDateTime.day;

      String since;
      if (years > 0) {
        since = '$years year${years > 1 ? 's' : ''}';
      } else if (months > 0) {
        since = '$months month${months > 1 ? 's' : ''}';
      } else {
        since = '$days day${days > 1 ? 's' : ''}';
      }

      setState(() {
        _footballFanSince = since;
      });
    } catch (e) {
      setState(() {
        _footballFanSince = 'recently';
      });
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _hasUnsavedTextChanges =>
      _nameController.text.trim() != _profile.name ||
          _bioController.text.trim() != _profile.bio;

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasUnsavedTextChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes to your name or bio. If you leave now, they\'ll be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: _dangerRed)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter your name', _dangerRed);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await ProfileService().updateBasicInfo(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      setState(() {
        _profile = updated;
        _isSaving = false;
      });
      if (mounted) {
        _showSnack('Profile saved successfully', _green);
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Could not save profile: $e', _dangerRed);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showPermissionDenied('Camera');
        return;
      }
    } else {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        _showPermissionDenied('Gallery');
        return;
      }
    }

    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final updated = await ProfileService().saveProfileImage(File(image.path));
        if (updated != null && mounted) {
          setState(() => _profile = updated);
          _showSnack('Profile photo updated', _green);
        }
      }
    } catch (e) {
      _showSnack('Failed to pick image: $e', _dangerRed);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _showPermissionDenied(String source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$source Access Denied'),
        content: Text(
          'Please enable $source access in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: _blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeImage() async {
    Navigator.pop(context);
    final updated = await ProfileService().removeProfileImage();
    if (mounted) {
      setState(() => _profile = updated);
      _showSnack('Profile photo removed', _muted);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(width: 20),
                const Text(
                  'Profile Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: _muted)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            _buildSheetTile(
              icon: Icons.camera_alt_rounded,
              title: 'Take a Photo',
              subtitle: 'Capture a new profile picture',
              color: _green,
              onTap: () => _pickImage(ImageSource.camera),
            ),
            _buildSheetTile(
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo',
              color: _blue,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            if (_profile.hasImage)
              _buildSheetTile(
                icon: Icons.delete_outline_rounded,
                title: 'Remove Photo',
                subtitle: 'Remove your profile picture',
                color: _dangerRed,
                onTap: _removeImage,
                isDestructive: true,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive ? _dangerRed : _ink,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
      onTap: onTap,
    );
  }

  // ─── PROFILE COMPLETENESS ──────────────────────────────────────────────

  double get _completenessRatio {
    const total = 5;
    int score = 0;
    if (_profile.hasName) score++;
    if (_profile.bio.trim().isNotEmpty) score++;
    if (_profile.hasImage) score++;
    if (_profile.hasFavoriteClub) score++;
    if (_profile.hasFavoritePlayer) score++;
    return score / total;
  }

  List<String> get _missingProfileItems {
    final missing = <String>[];
    if (!_profile.hasName) missing.add('your name');
    if (_profile.bio.trim().isEmpty) missing.add('a bio');
    if (!_profile.hasImage) missing.add('a profile photo');
    if (!_profile.hasFavoriteClub) missing.add('a favorite club');
    if (!_profile.hasFavoritePlayer) missing.add('a favorite player');
    return missing;
  }

  Widget _buildCompletenessCard() {
    final ratio = _completenessRatio.clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    final missing = _missingProfileItems;
    final isComplete = missing.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(green: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.verified_rounded, size: 16, color: _green),
              ),
              const SizedBox(width: 10),
              const Text(
                'PROFILE COMPLETENESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete ? _green : _blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return Stack(
                  children: [
                    Container(height: 8, color: _green.withOpacity(0.1)),
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
          const SizedBox(height: 10),
          if (isComplete)
            const Row(
              children: [
                Icon(Icons.celebration_rounded, size: 14, color: _green),
                SizedBox(width: 6),
                Text(
                  'Your profile is complete!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _green),
                ),
              ],
            )
          else
            Text(
              'Add ${missing.join(', ')} to reach 100%.',
              style: const TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
        ],
      ),
    );
  }

  // ─── FAVORITE CLUB / PLAYER ────────────────────────────────────────────



  Widget _buildFavoriteClubTile() {
    final hasClub = _profile.hasFavoriteClub;
    final logo = _profile.favoriteClubLogo;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showClubPicker,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _buildFavoriteAvatar(logo, Icons.shield_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FAVORITE CLUB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasClub ? _profile.favoriteClubName! : 'Tap to choose your club',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasClub ? _ink : _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (hasClub)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                onPressed: _clearFavoriteClub,
                tooltip: 'Remove',
              )
            else
              const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritePlayerTile() {
    final hasPlayer = _profile.hasFavoritePlayer;
    final image = _profile.favoritePlayerImage;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showPlayerPicker,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            _buildFavoriteAvatar(image, Icons.person_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FAVORITE PLAYER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPlayer
                        ? '${_profile.favoritePlayerName}'
                        '${(_profile.favoritePlayerTeam?.isNotEmpty ?? false) ? ' · ${_profile.favoritePlayerTeam}' : ''}'
                        : 'Tap to choose your player',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasPlayer ? _ink : _muted,
                    ),
                  ),
                ],
              ),
            ),
            if (hasPlayer)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: _muted),
                onPressed: _clearFavoritePlayer,
                tooltip: 'Remove',
              )
            else
              const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteAvatar(String? url, IconData fallbackIcon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _muted.withOpacity(0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url != null && url.isNotEmpty)
          ? Padding(
        padding: const EdgeInsets.all(4),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, size: 20, color: _muted),
        ),
      )
          : Icon(fallbackIcon, size: 20, color: _muted),
    );
  }

  void _showClubPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Choose Favorite Club',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _muted)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: famousClubs.length,
                itemBuilder: (context, i) {
                  final club = famousClubs[i];
                  final logo = 'https://a.espncdn.com/i/teamlogos/soccer/500/${club['id']}.png';
                  final isSelected = _profile.favoriteClubId == club['id'];
                  return ListTile(
                    leading: ClipOval(
                      child: Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFFF2F2F7),
                        padding: const EdgeInsets.all(6),
                        child: Image.network(
                          logo,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.shield_outlined, color: _muted),
                        ),
                      ),
                    ),
                    title: Text(club['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      club['leagueName'] ?? '',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: _blue) : null,
                    onTap: () => _selectFavoriteClub(club, logo),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlayerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Choose Favorite Player',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _muted)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: famousPlayers.length,
                itemBuilder: (context, i) {
                  final player = famousPlayers[i];
                  final isSelected = _profile.favoritePlayerId == player['id'];
                  return ListTile(
                    leading: ClipOval(
                      child: Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFFF2F2F7),
                        child: Image.network(
                          player['imageUrl'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person_rounded, color: _muted),
                        ),
                      ),
                    ),
                    title: Text(player['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${player['teamName']} · ${player['position']}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: _green) : null,
                    onTap: () => _selectFavoritePlayer(player),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectFavoriteClub(Map<String, String> club, String logo) async {
    Navigator.pop(context);
    final updated = await ProfileService().setFavoriteClub(
      id: club['id']!,
      name: club['name']!,
      logo: logo,
    );
    if (mounted) {
      setState(() => _profile = updated);
      _showSnack('Favorite club set to ${club['name']}', _blue);
    }
  }

  Future<void> _clearFavoriteClub() async {
    final updated = await ProfileService().clearFavoriteClub();
    if (mounted) {
      setState(() => _profile = updated);
      _showSnack('Favorite club removed', _muted);
    }
  }

  Future<void> _selectFavoritePlayer(Map<String, dynamic> player) async {
    Navigator.pop(context);
    final updated = await ProfileService().setFavoritePlayer(
      id: player['id'] as String,
      name: player['name'] as String,
      image: player['imageUrl'] as String,
      team: player['teamName'] as String,
    );
    if (mounted) {
      setState(() => _profile = updated);
      _showSnack('Favorite player set to ${player['name']}', _green);
    }
  }

  Future<void> _clearFavoritePlayer() async {
    final updated = await ProfileService().clearFavoritePlayer();
    if (mounted) {
      setState(() => _profile = updated);
      _showSnack('Favorite player removed', _muted);
    }
  }

  // ─── APP PREFERENCES ────────────────────────────────────────────────────

  Future<void> _toggleDarkMode(bool value) async {
    _showSnack('Dark mode coming soon!', _blue);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _preferences = _preferences.copyWith(notificationsEnabled: value));
    await PreferencesService().savePreferences(_preferences);
  }

  Future<void> _toggleLiveScoreAlerts(bool value) async {
    setState(() => _preferences = _preferences.copyWith(liveScoreAlerts: value));
    await PreferencesService().savePreferences(_preferences);
  }

  Future<void> _toggleNewsAlerts(bool value) async {
    setState(() => _preferences = _preferences.copyWith(newsAlerts: value));
    await PreferencesService().savePreferences(_preferences);
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.tune_rounded, size: 16, color: _blue),
              ),
              const SizedBox(width: 10),
              const Text(
                'APP PREFERENCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildToggleRow(
            icon: Icons.dark_mode_rounded,
            title: 'Dark Mode',
            subtitle: 'Coming soon!',
            value: _preferences.isDarkMode,
            onChanged: _toggleDarkMode,
            comingSoon: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),
          _buildToggleRow(
            icon: Icons.notifications_active_rounded,
            title: 'Push Notifications',
            subtitle: 'Allow the app to send you notifications',
            value: _preferences.notificationsEnabled,
            onChanged: _toggleNotifications,
          ),
          const SizedBox(height: 14),
          _buildToggleRow(
            icon: Icons.sports_soccer_rounded,
            title: 'Live Score Alerts',
            subtitle: 'Get notified the moment your teams score',
            value: _preferences.liveScoreAlerts,
            onChanged: _preferences.notificationsEnabled ? _toggleLiveScoreAlerts : null,
            enabled: _preferences.notificationsEnabled,
          ),
          const SizedBox(height: 14),
          _buildToggleRow(
            icon: Icons.article_rounded,
            title: 'News Alerts',
            subtitle: 'Get notified about breaking football news',
            value: _preferences.newsAlerts,
            onChanged: _preferences.notificationsEnabled ? _toggleNewsAlerts : null,
            enabled: _preferences.notificationsEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
    bool comingSoon = false,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? _green : _muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Soon',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            ),
          ),
          if (!comingSoon)
            Switch(value: value, onChanged: onChanged, activeColor: _green)
          else
            Switch(
              value: false,
              onChanged: null,
              activeColor: _green,
              inactiveThumbColor: _muted,
            ),
        ],
      ),
    );
  }

  // ─── YOUR FOOTBALL JOURNEY ─────────────────────────────────────────────

  Widget _buildJourneyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(green: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.emoji_events_rounded, size: 16, color: _green),
              ),
              const SizedBox(width: 10),
              const Text(
                'YOUR FOOTBALL JOURNEY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.sports_soccer_rounded, size: 24, color: _green),
                      const SizedBox(height: 6),
                      Text(
                        '$_totalBallsCollected',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _greenDark,
                        ),
                      ),
                      const Text(
                        'Balls Collected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 24, color: _blue),
                      const SizedBox(height: 6),
                      Text(
                        _footballFanSince,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _blue,
                        ),
                      ),
                      const Text(
                        'Football Fan Since',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── SHARED STYLE HELPERS ──────────────────────────────────────────────

  BoxDecoration _cardDecoration({bool green = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: green ? Border.all(color: _green.withOpacity(0.15)) : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardIfNeeded,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              fontFamily: 'SportFont',
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () async {
              if (await _confirmDiscardIfNeeded() && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _green),
              )
                  : const Text(
                'Save',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Profile Photo ────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _isPickingImage ? null : _showImagePickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_green, _greenDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: _profile.hasImage
                              ? Image.file(
                            File(_profile.imagePath!),
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          )
                              : Container(
                            color: Colors.white,
                            child: Center(
                              child: Text(
                                _profile.initials,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: _green,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isPickingImage
                              ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _profile.hasImage ? 'Tap to change photo' : 'Tap to add a photo',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
              const SizedBox(height: 20),

              // ── Profile Completeness ─────────────────────────────────────
              _buildCompletenessCard(),
              const SizedBox(height: 20),

              // ── Name Field ────────────────────────────────────────────────
              _buildLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter your name',
                icon: Icons.person_outline_rounded,
                maxLength: 40,
              ),
              const SizedBox(height: 20),

              // ── Bio Field ─────────────────────────────────────────────────
              _buildLabel('Bio'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _bioController,
                hint: 'Tell us about yourself',
                icon: Icons.edit_note_rounded,
                maxLength: 120,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // ── Your Football Journey ────────────────────────────────────
              _buildJourneyCard(),
              const SizedBox(height: 20),

              // ── App Preferences ───────────────────────────────────────────
              _buildPreferencesCard(),
              const SizedBox(height: 28),

              // ── Save Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                      : const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, color: _ink, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 4, right: 4, bottom: maxLines > 1 ? 40 : 0),
            child: Icon(icon, size: 22, color: _green),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          counterStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}