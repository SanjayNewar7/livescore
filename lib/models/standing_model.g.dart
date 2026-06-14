// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standing_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StandingAdapter extends TypeAdapter<Standing> {
  @override
  final int typeId = 6;

  @override
  Standing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Standing(
      rank: fields[0] as int,
      team: fields[1] as TeamInfo,
      wins: fields[2] as String,
      losses: fields[3] as String,
      ties: fields[4] as String,
      winPercentage: fields[5] as String,
      pointsFor: fields[6] as String,
      pointsAgainst: fields[7] as String,
      streak: fields[8] as String,
      clinchedPlayoffs: fields[9] as bool,
      conference: fields[10] as String,
      division: fields[11] as String,
      stats: (fields[12] as Map).cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Standing obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.rank)
      ..writeByte(1)
      ..write(obj.team)
      ..writeByte(2)
      ..write(obj.wins)
      ..writeByte(3)
      ..write(obj.losses)
      ..writeByte(4)
      ..write(obj.ties)
      ..writeByte(5)
      ..write(obj.winPercentage)
      ..writeByte(6)
      ..write(obj.pointsFor)
      ..writeByte(7)
      ..write(obj.pointsAgainst)
      ..writeByte(8)
      ..write(obj.streak)
      ..writeByte(9)
      ..write(obj.clinchedPlayoffs)
      ..writeByte(10)
      ..write(obj.conference)
      ..writeByte(11)
      ..write(obj.division)
      ..writeByte(12)
      ..write(obj.stats);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StandingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
