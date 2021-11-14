// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'FleetMapNumber.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FleetMapNumber _$FleetMapNumberFromJson(Map json) {
  return FleetMapNumber(
    name: json['name'] as String?,
    suffix: json['suffix'] as String?,
  );
}

Map<String, dynamic> _$FleetMapNumberToJson(FleetMapNumber instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('suffix', instance.suffix);
  return val;
}
