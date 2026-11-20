import 'package:flutter_test/flutter_test.dart';
import 'package:livescore/models/user_profile_model.dart';
import 'package:livescore/services/avatar_catalog_service.dart';
import 'package:livescore/utils/suggested_profile_names.dart';

void main() {
  test('suggested names are the 25 distinct original options', () {
    expect(suggestedProfileNames.length, 25);
    expect(suggestedProfileNames.toSet().length, 25);
    expect(suggestedProfileNames.first, 'Akira Striker');
    expect(suggestedProfileNames.last, 'Takumi Cyclone');
  });

  test('old profiles remain readable and avatar choice persists', () {
    final old = UserProfile.fromMap({'name': 'Alex', 'imagePath': '/photo.jpg'});
    expect(old.avatarId, isNull);
    final updated = old.copyWith(avatarId: 'asset-1');
    expect(UserProfile.fromMap(updated.toMap()).avatarId, 'asset-1');
    expect(updated.copyWith(clearAvatar: true).avatarId, isNull);
  });

  test('catalog accepts only public URLs for the configured cloud', () {
    expect(AnimeAvatar.fromJson({
      'id': 'asset-1',
      'url': 'https://res.cloudinary.com/dkk7zqgnz/image/upload/v1/avatar.jpg',
    }), isNotNull);
    expect(AnimeAvatar.fromJson({
      'id': 'asset-2', 'url': 'https://example.com/avatar.jpg',
    }), isNull);
  });
}
