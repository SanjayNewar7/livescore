// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 7;

  @override
  Player read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Player(
      id: fields[0] as String,
      fullName: fields[1] as String,
      displayName: fields[2] as String,
      headshot: fields[3] as String,
      jersey: fields[4] as String,
      position: fields[5] as String,
      teamId: fields[6] as String,
      teamName: fields[7] as String,
      height: fields[8] as int,
      weight: fields[9] as int,
      age: fields[10] as int,
      college: fields[11] as String,
      statistics: (fields[12] as Map).cast<String, dynamic>(),
      injuryStatus: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.headshot)
      ..writeByte(4)
      ..write(obj.jersey)
      ..writeByte(5)
      ..write(obj.position)
      ..writeByte(6)
      ..write(obj.teamId)
      ..writeByte(7)
      ..write(obj.teamName)
      ..writeByte(8)
      ..write(obj.height)
      ..writeByte(9)
      ..write(obj.weight)
      ..writeByte(10)
      ..write(obj.age)
      ..writeByte(11)
      ..write(obj.college)
      ..writeByte(12)
      ..write(obj.statistics)
      ..writeByte(13)
      ..write(obj.injuryStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
