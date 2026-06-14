// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserPreferencesAdapter extends TypeAdapter<UserPreferences> {
  @override
  final int typeId = 11;

  @override
  UserPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPreferences(
      favoriteTeamIds: (fields[0] as List).cast<String>(),
      favoriteLeagueIds: (fields[1] as List).cast<String>(),
      hasCompletedOnboarding: fields[2] as bool,
      isDarkMode: fields[3] as bool,
      notificationsEnabled: fields[4] as bool,
      liveScoreAlerts: fields[5] as bool,
      newsAlerts: fields[6] as bool,
      lastSelectedLeague: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserPreferences obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.favoriteTeamIds)
      ..writeByte(1)
      ..write(obj.favoriteLeagueIds)
      ..writeByte(2)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(3)
      ..write(obj.isDarkMode)
      ..writeByte(4)
      ..write(obj.notificationsEnabled)
      ..writeByte(5)
      ..write(obj.liveScoreAlerts)
      ..writeByte(6)
      ..write(obj.newsAlerts)
      ..writeByte(7)
      ..write(obj.lastSelectedLeague);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
