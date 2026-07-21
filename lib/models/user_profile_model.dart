// lib/models/user_profile_model.dart
//
// Lightweight local-only profile model. Nothing here is sent to any
// server - name, bio and the profile image path are all stored on
// the device via Hive / local file storage (see ProfileService).

class UserProfile {
  final String name;
  final String bio;
  final String? imagePath;

  final String? favoriteClubId;
  final String? favoriteClubName;
  final String? favoriteClubLogo;

  final String? favoritePlayerId;
  final String? favoritePlayerName;
  final String? favoritePlayerImage;
  final String? favoritePlayerTeam;

  const UserProfile({
    this.name = '',
    this.bio = '',
    this.imagePath,
    this.favoriteClubId,
    this.favoriteClubName,
    this.favoriteClubLogo,
    this.favoritePlayerId,
    this.favoritePlayerName,
    this.favoritePlayerImage,
    this.favoritePlayerTeam,
  });

  static const empty = UserProfile();

  bool get hasName => name.trim().isNotEmpty;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasFavoriteClub => favoriteClubId != null && favoriteClubId!.isNotEmpty;
  bool get hasFavoritePlayer => favoritePlayerId != null && favoritePlayerId!.isNotEmpty;

  String get displayName => hasName ? name.trim() : 'Football Fan';

  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'FF';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  UserProfile copyWith({
    String? name,
    String? bio,
    String? imagePath,
    bool clearImage = false,
    String? favoriteClubId,
    String? favoriteClubName,
    String? favoriteClubLogo,
    bool clearFavoriteClub = false,
    String? favoritePlayerId,
    String? favoritePlayerName,
    String? favoritePlayerImage,
    String? favoritePlayerTeam,
    bool clearFavoritePlayer = false,
  }) {
    return UserProfile(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      favoriteClubId: clearFavoriteClub ? null : (favoriteClubId ?? this.favoriteClubId),
      favoriteClubName: clearFavoriteClub ? null : (favoriteClubName ?? this.favoriteClubName),
      favoriteClubLogo: clearFavoriteClub ? null : (favoriteClubLogo ?? this.favoriteClubLogo),
      favoritePlayerId: clearFavoritePlayer ? null : (favoritePlayerId ?? this.favoritePlayerId),
      favoritePlayerName: clearFavoritePlayer ? null : (favoritePlayerName ?? this.favoritePlayerName),
      favoritePlayerImage: clearFavoritePlayer ? null : (favoritePlayerImage ?? this.favoritePlayerImage),
      favoritePlayerTeam: clearFavoritePlayer ? null : (favoritePlayerTeam ?? this.favoritePlayerTeam),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'bio': bio,
    'imagePath': imagePath,
    'favoriteClubId': favoriteClubId,
    'favoriteClubName': favoriteClubName,
    'favoriteClubLogo': favoriteClubLogo,
    'favoritePlayerId': favoritePlayerId,
    'favoritePlayerName': favoritePlayerName,
    'favoritePlayerImage': favoritePlayerImage,
    'favoritePlayerTeam': favoritePlayerTeam,
  };

  factory UserProfile.fromMap(Map? map) {
    if (map == null) return UserProfile.empty;
    return UserProfile(
      name: map['name']?.toString() ?? '',
      bio: map['bio']?.toString() ?? '',
      imagePath: map['imagePath']?.toString(),
      favoriteClubId: map['favoriteClubId']?.toString(),
      favoriteClubName: map['favoriteClubName']?.toString(),
      favoriteClubLogo: map['favoriteClubLogo']?.toString(),
      favoritePlayerId: map['favoritePlayerId']?.toString(),
      favoritePlayerName: map['favoritePlayerName']?.toString(),
      favoritePlayerImage: map['favoritePlayerImage']?.toString(),
      favoritePlayerTeam: map['favoritePlayerTeam']?.toString(),
    );
  }
}