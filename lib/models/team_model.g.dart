// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeamInfoAdapter extends TypeAdapter<TeamInfo> {
  @override
  final int typeId = 9;

  @override
  TeamInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeamInfo(
      id: fields[0] as String,
      name: fields[1] as String,
      displayName: fields[2] as String,
      abbreviation: fields[3] as String,
      logo: fields[4] as String,
      color: fields[5] as String,
      alternateColor: fields[6] as String,
      record: fields[7] as String,
      venueName: fields[8] as String?,
      coach: fields[9] as String?,
      foundedYear: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TeamInfo obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.abbreviation)
      ..writeByte(4)
      ..write(obj.logo)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.alternateColor)
      ..writeByte(7)
      ..write(obj.record)
      ..writeByte(8)
      ..write(obj.venueName)
      ..writeByte(9)
      ..write(obj.coach)
      ..writeByte(10)
      ..write(obj.foundedYear);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
