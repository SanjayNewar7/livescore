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

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:livescore/models/user_profile_model.dart';

class ProfileService {
  static const String _boxName = 'user_profile_box';
  static const String _profileKey = 'profile';
  static const String _imageFileName = 'profile_photo.jpg';

  late Box _box;

  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  UserProfile get profile {
    if (!Hive.isBoxOpen(_boxName)) return UserProfile.empty;
    return UserProfile.fromMap(_box.get(_profileKey) as Map?);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _box.put(_profileKey, profile.toMap());
  }

  Future<UserProfile> updateBasicInfo({String? name, String? bio}) async {
    final updated = profile.copyWith(name: name, bio: bio);
    await saveProfile(updated);
    return updated;
  }

  /// ✅ ADDED: Save a profile image from a File
  Future<UserProfile?> saveProfileImage(File imageFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savedPath = '${dir.path}/$_imageFileName';

      // Overwrite any existing photo.
      final savedFile = File(savedPath);
      if (await savedFile.exists()) {
        await savedFile.delete();
      }
      await imageFile.copy(savedPath);

      final updated = profile.copyWith(imagePath: savedPath);
      await saveProfile(updated);
      return updated;
    } catch (e) {
      print('Error saving profile image: $e');
      return null;
    }
  }

  /// Lets the user pick a photo from gallery or camera, copies it into
  /// permanent local storage, and saves the path against the profile.
  Future<UserProfile?> pickAndSaveProfileImage({required bool fromCamera}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final savedPath = '${dir.path}/$_imageFileName';

    // Overwrite any existing photo.
    final savedFile = File(savedPath);
    if (await savedFile.exists()) {
      await savedFile.delete();
    }
    await File(picked.path).copy(savedPath);

    final updated = profile.copyWith(imagePath: savedPath);
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
    }
    final updated = current.copyWith(clearImage: true);
    await saveProfile(updated);
    return updated;
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