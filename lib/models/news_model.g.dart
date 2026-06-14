// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NewsArticleAdapter extends TypeAdapter<NewsArticle> {
  @override
  final int typeId = 8;

  @override
  NewsArticle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NewsArticle(
      id: fields[0] as String,
      headline: fields[1] as String,
      description: fields[2] as String,
      body: fields[3] as String,
      imageUrl: fields[4] as String,
      publishedAt: fields[5] as String,
      author: fields[6] as String,
      categories: (fields[7] as List).cast<String>(),
      videoUrl: fields[8] as String?,
      links: (fields[9] as Map?)?.cast<String, dynamic>(),
      imageCaption: fields[10] as String,
      webUrl: fields[11] as String?,
      articleType: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NewsArticle obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.headline)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.publishedAt)
      ..writeByte(6)
      ..write(obj.author)
      ..writeByte(7)
      ..write(obj.categories)
      ..writeByte(8)
      ..write(obj.videoUrl)
      ..writeByte(9)
      ..write(obj.links)
      ..writeByte(10)
      ..write(obj.imageCaption)
      ..writeByte(11)
      ..write(obj.webUrl)
      ..writeByte(12)
      ..write(obj.articleType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewsArticleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
