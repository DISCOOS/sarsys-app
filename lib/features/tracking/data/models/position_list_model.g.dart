// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_list_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PositionListModel _$PositionListModelFromJson(Map json) {
  return PositionListModel(
    id: json['id'] as String?,
    features: (json['features'] as List<dynamic>?)
        ?.map((e) => e == null
            ? null
            : Position.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

Map<String, dynamic> _$PositionListModelToJson(PositionListModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('features', instance.features?.map((e) => e?.toJson()).toList());
  return val;
}
