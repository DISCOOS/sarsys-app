// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Author.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Author _$AuthorFromJson(Map json) {
  return Author(
    userId: json['userId'] as String,
    timestamp: json['timestamp'] == null
        ? null
        : DateTime.parse(json['timestamp'] as String),
  );
}

Map<String, dynamic> _$AuthorToJson(Author instance) => <String, dynamic>{
      'userId': instance.userId,
      'timestamp': instance.timestamp?.toIso8601String(),
    };
