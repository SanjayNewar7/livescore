// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_detail_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamDetailAdapter extends TypeAdapter<TeamDetail> {
  @override
  final int typeId = 10;

  @override
  TeamDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeamDetail(
      basicInfo: fields[0] as TeamInfo,
      stadiumName: fields[1] as String?,
      stadiumCity: fields[2] as String?,
      stadiumState: fields[3] as String?,
      stadiumCapacity: fields[4] as int?,
      headCoach: fields[5] as String?,
      generalManager: fields[6] as String?,
      owner: fields[7] as String?,
      conference: fields[8] as String?,
      division: fields[9] as String?,
      championships: (fields[10] as List?)?.cast<String>(),
      seasonStats: (fields[11] as Map?)?.cast<String, dynamic>(),
      upcomingGames: (fields[12] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
      pastGames: (fields[13] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          ?.toList(),
    );
  }

  @override
  void write(BinaryWriter writer, TeamDetail obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.basicInfo)
      ..writeByte(1)
      ..write(obj.stadiumName)
      ..writeByte(2)
      ..write(obj.stadiumCity)
      ..writeByte(3)
      ..write(obj.stadiumState)
      ..writeByte(4)
      ..write(obj.stadiumCapacity)
      ..writeByte(5)
      ..write(obj.headCoach)
      ..writeByte(6)
      ..write(obj.generalManager)
      ..writeByte(7)
      ..write(obj.owner)
      ..writeByte(8)
      ..write(obj.conference)
      ..writeByte(9)
      ..write(obj.division)
      ..writeByte(10)
      ..write(obj.championships)
      ..writeByte(11)
      ..write(obj.seasonStats)
      ..writeByte(12)
      ..write(obj.upcomingGames)
      ..writeByte(13)
      ..write(obj.pastGames);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
