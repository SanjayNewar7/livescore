// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalScorerAdapter extends TypeAdapter<GoalScorer> {
  @override
  final int typeId = 14;

  @override
  GoalScorer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalScorer(
      playerId: fields[0] as String,
      playerName: fields[1] as String,
      minute: fields[2] as int,
      isHomeTeam: fields[3] as bool,
      addedTime: fields[4] as int?,
      assistPlayerName: fields[5] as String?,
      isPenalty: fields[6] as bool,
      isOwnGoal: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GoalScorer obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.playerId)
      ..writeByte(1)
      ..write(obj.playerName)
      ..writeByte(2)
      ..write(obj.minute)
      ..writeByte(3)
      ..write(obj.isHomeTeam)
      ..writeByte(4)
      ..write(obj.addedTime)
      ..writeByte(5)
      ..write(obj.assistPlayerName)
      ..writeByte(6)
      ..write(obj.isPenalty)
      ..writeByte(7)
      ..write(obj.isOwnGoal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalScorerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameAdapter extends TypeAdapter<Game> {
  @override
  final int typeId = 0;

  @override
  Game read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Game(
      id: fields[0] as String,
      status: fields[1] as String,
      shortDetail: fields[2] as String,
      awayTeam: fields[3] as TeamInfo,
      homeTeam: fields[4] as TeamInfo,
      awayScore: fields[5] as String,
      homeScore: fields[6] as String,
      awayLineScores: (fields[7] as List).cast<int>(),
      homeLineScores: (fields[8] as List).cast<int>(),
      venue: fields[9] as Venue,
      date: fields[10] as String,
      clock: fields[11] as String,
      period: fields[12] as String,
      leagueName: fields[13] as String,
      leagueFlag: fields[14] as String,
      goalScorers: (fields[15] as List).cast<GoalScorer>(),
      awayTeamFullName: fields[16] as String,
      homeTeamFullName: fields[17] as String,
      awayTeamShortName: fields[18] as String,
      homeTeamShortName: fields[19] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Game obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.shortDetail)
      ..writeByte(3)
      ..write(obj.awayTeam)
      ..writeByte(4)
      ..write(obj.homeTeam)
      ..writeByte(5)
      ..write(obj.awayScore)
      ..writeByte(6)
      ..write(obj.homeScore)
      ..writeByte(7)
      ..write(obj.awayLineScores)
      ..writeByte(8)
      ..write(obj.homeLineScores)
      ..writeByte(9)
      ..write(obj.venue)
      ..writeByte(10)
      ..write(obj.date)
      ..writeByte(11)
      ..write(obj.clock)
      ..writeByte(12)
      ..write(obj.period)
      ..writeByte(13)
      ..write(obj.leagueName)
      ..writeByte(14)
      ..write(obj.leagueFlag)
      ..writeByte(15)
      ..write(obj.goalScorers)
      ..writeByte(16)
      ..write(obj.awayTeamFullName)
      ..writeByte(17)
      ..write(obj.homeTeamFullName)
      ..writeByte(18)
      ..write(obj.awayTeamShortName)
      ..writeByte(19)
      ..write(obj.homeTeamShortName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class VenueAdapter extends TypeAdapter<Venue> {
  @override
  final int typeId = 2;

  @override
  Venue read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Venue(
      id: fields[0] as String,
      fullName: fields[1] as String,
      city: fields[2] as String,
      state: fields[3] as String,
      capacity: fields[4] as int,
      imageUrl: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Venue obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.city)
      ..writeByte(3)
      ..write(obj.state)
      ..writeByte(4)
      ..write(obj.capacity)
      ..writeByte(5)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenueAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WinProbabilityAdapter extends TypeAdapter<WinProbability> {
  @override
  final int typeId = 3;

  @override
  WinProbability read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WinProbability(
      gameId: fields[0] as String,
      quarter: fields[1] as int,
      time: fields[2] as String,
      awayWinPercentage: fields[3] as double,
      homeWinPercentage: fields[4] as double,
      awayScore: fields[5] as int,
      homeScore: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WinProbability obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.gameId)
      ..writeByte(1)
      ..write(obj.quarter)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.awayWinPercentage)
      ..writeByte(4)
      ..write(obj.homeWinPercentage)
      ..writeByte(5)
      ..write(obj.awayScore)
      ..writeByte(6)
      ..write(obj.homeScore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinProbabilityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GameDetailAdapter extends TypeAdapter<GameDetail> {
  @override
  final int typeId = 4;

  @override
  GameDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameDetail(
      game: fields[0] as Game,
      winProbabilities: (fields[1] as List).cast<WinProbability>(),
      boxScore: (fields[2] as Map).cast<String, dynamic>(),
      plays: (fields[3] as List).cast<Play>(),
    );
  }

  @override
  void write(BinaryWriter writer, GameDetail obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.game)
      ..writeByte(1)
      ..write(obj.winProbabilities)
      ..writeByte(2)
      ..write(obj.boxScore)
      ..writeByte(3)
      ..write(obj.plays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlayAdapter extends TypeAdapter<Play> {
  @override
  final int typeId = 5;

  @override
  Play read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Play(
      id: fields[0] as String,
      quarter: fields[1] as int,
      time: fields[2] as String,
      text: fields[3] as String,
      type: fields[4] as String,
      awayScore: fields[5] as int,
      homeScore: fields[6] as int,
      playerName: fields[7] as String?,
      playerId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Play obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.quarter)
      ..writeByte(2)
      ..write(obj.time)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.awayScore)
      ..writeByte(6)
      ..write(obj.homeScore)
      ..writeByte(7)
      ..write(obj.playerName)
      ..writeByte(8)
      ..write(obj.playerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
