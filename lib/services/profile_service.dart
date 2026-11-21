// lib/services/profile_service.dart
//
// Everything here stays on the device:
//  - name / bio / favorite club / favorite player -> Hive box
//  - profile photo -> copied into the app's documents directory
//
// Requires these packages in pubspec.yaml:
//   image_picker: ^1.0.0
//   path_provider: ^2.1.0

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show FileImage;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/services/avatar_catalog_service.dart';
import 'package:livescore/utils/suggested_profile_names.dart';

class ProfileService extends ChangeNotifier {
  Future<void>? _defaultAvatarInFlight;
  static const String _boxName = 'user_profile_box';
  static const String _profileKey = 'profile';

  /// Legacy fixed name, still cleaned up when found.
  static const String _imageFileName = 'profile_photo.jpg';
  static const String _imageFilePrefix = 'profile_photo_';

  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  Future<void> init() async {
    await _ensureBox();
    if (!profile.hasName || profile.name.trim() == 'Football Fan') {
      await saveProfile(profile.copyWith(
        name: suggestedProfileNames[
            Random().nextInt(suggestedProfileNames.length)],
      ));
    }
  }

  /// Every read/write goes through this instead of a cached `late Box`
  /// field. That field-based pattern is a footgun: if `init()` never ran
  /// (e.g. an earlier, unrelated service's init() threw during app
  /// startup and short-circuited a shared try/catch block in main.dart),
  /// every subsequent call throws a silent `LateInitializationError` deep
  /// inside an unawaited Future — no crash screen, no snackbar, nothing
  /// visibly happens. Going through `Hive.box`/`Hive.openBox` directly
  /// makes the service open its own box on first use if needed, so a
  /// profile save works correctly even if startup init was skipped.
  Future<Box> _ensureBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  UserProfile get profile {
    if (!Hive.isBoxOpen(_boxName)) return UserProfile.empty;
    return UserProfile.fromMap(Hive.box(_boxName).get(_profileKey) as Map?);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final box = await _ensureBox();
    await box.put(_profileKey, profile.toMap());
    notifyListeners();
  }

  Future<UserProfile> updateBasicInfo({String? name, String? bio}) async {
    final updated = profile.copyWith(name: name, bio: bio);
    await saveProfile(updated);
    return updated;
  }

  /// Frees the decoded frame of a photo we are retiring, so it does not sit in
  /// the image cache for the rest of the session.
  Future<void> _evictCachedImage(String path) async {
    await FileImage(File(path)).evict();
  }

  /// Copies [source] into the documents directory under a fresh, unique name
  /// and deletes the photo it replaces.
  ///
  /// The file name has to change on every save. A mounted [Image] only
  /// re-resolves when its provider compares unequal, and [FileImage] equality
  /// is just the path — so reusing one fixed name leaves the previous photo on
  /// screen until the next app launch, however the cache is evicted.
  Future<String> _storeImage(File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final savedPath =
        '${dir.path}/$_imageFilePrefix${DateTime.now().millisecondsSinceEpoch}.jpg';
    await source.copy(savedPath);

    // Retire the photo this one replaces, plus anything left behind by the
    // older fixed-name scheme.
    for (final stale in {profile.imagePath, '${dir.path}/$_imageFileName'}) {
      if (stale == null || stale == savedPath) continue;
      final staleFile = File(stale);
      if (await staleFile.exists()) {
        await staleFile.delete();
      }
      await _evictCachedImage(stale);
    }

    return savedPath;
  }

  /// ✅ ADDED: Save a profile image from a File
  Future<UserProfile?> saveProfileImage(File imageFile) async {
    try {
      final savedPath = await _storeImage(imageFile);
      final updated = profile.copyWith(imagePath: savedPath, clearAvatar: true);
      await saveProfile(updated);
      return updated;
    } catch (e) {
      print('Error saving profile image: $e');
      return null;
    }
  }

  /// Lets the user pick a photo from gallery or camera, copies it into
  /// permanent local storage, and saves the path against the profile.
  Future<UserProfile?> pickAndSaveProfileImage(
      {required bool fromCamera}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return null;

    final savedPath = await _storeImage(File(picked.path));

    final updated = profile.copyWith(imagePath: savedPath, clearAvatar: true);
    await saveProfile(updated);
    return updated;
  }

  Future<UserProfile> removeProfileImage() async {
    final current = profile;
    if (current.imagePath != null) {
      final file = File(current.imagePath!);
      if (await file.exists()) {
        await file.delete();
      }
      await _evictCachedImage(current.imagePath!);
    }
    final updated = current.copyWith(clearImage: true, clearAvatar: true);
    await saveProfile(updated);
    return updated;
  }

  Future<UserProfile?> saveAnimeAvatar(AnimeAvatar avatar,
      {bool onlyIfEmpty = false}) async {
    final uri = Uri.tryParse(avatar.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'res.cloudinary.com' ||
        !uri.path.startsWith('/dkk7zqgnz/image/upload/')) return null;
    File? temporary;
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 5 * 1024 * 1024) return null;
      final dir = await getApplicationDocumentsDirectory();
      temporary = File('${dir.path}/avatar_download.tmp');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      if (onlyIfEmpty) {
        final existingPath = profile.imagePath;
        if (existingPath != null && await File(existingPath).exists()) {
          return null;
        }
      }
      final savedPath = await _storeImage(temporary);
      final updated =
          profile.copyWith(imagePath: savedPath, avatarId: avatar.id);
      await saveProfile(updated);
      return updated;
    } catch (_) {
      return null;
    } finally {
      if (temporary != null && await temporary.exists())
        await temporary.delete();
    }
  }

  Future<void> ensureDefaultAvatar() async {
    if (_defaultAvatarInFlight != null) return _defaultAvatarInFlight;
    final pending = _loadDefaultAvatar();
    _defaultAvatarInFlight = pending;
    try {
      await pending;
    } finally {
      _defaultAvatarInFlight = null;
    }
  }

  Future<void> _loadDefaultAvatar() async {
    final currentPath = profile.imagePath;
    if (currentPath != null && await File(currentPath).exists()) return;
    final avatars = await AvatarCatalogService().getAvatars();
    final latestPath = profile.imagePath;
    if (avatars.isEmpty ||
        (latestPath != null && await File(latestPath).exists())) return;
    final selected = avatars.firstWhere(
      (avatar) => avatar.id == profile.avatarId,
      orElse: () => avatars[Random().nextInt(avatars.length)],
    );
    await saveAnimeAvatar(selected, onlyIfEmpty: true);
  }

  Future<UserProfile> setFavoriteClub({
    required String id,
    required String name,
    required String logo,
  }) async {
    final updated = profile.copyWith(
      favoriteClubId: id,
      favoriteClubName: name,
      favoriteClubLogo: logo,
    );
    await saveProfile(updated);
    return updated;
  }

  Future<UserProfile> clearFavoriteClub() async {
    final updated = profile.copyWith(clearFavoriteClub: true);
    await saveProfile(updated);
    return updated;
  }

  Future<UserProfile> setFavoritePlayer({
    required String id,
    required String name,
    required String image,
    required String team,
  }) async {
    final updated = profile.copyWith(
      favoritePlayerId: id,
      favoritePlayerName: name,
      favoritePlayerImage: image,
      favoritePlayerTeam: team,
    );
    await saveProfile(updated);
    return updated;
  }

  Future<UserProfile> clearFavoritePlayer() async {
    final updated = profile.copyWith(clearFavoritePlayer: true);
    await saveProfile(updated);
    return updated;
  }
}
