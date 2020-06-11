// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Passcodes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Passcodes _$PasscodesFromJson(Map json) {
  return Passcodes(
    commander: json['commander'] as String,
    personnel: json['personnel'] as String,
  );
}

Map<String, dynamic> _$PasscodesToJson(Passcodes instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('commander', instance.commander);
  writeNotNull('personnel', instance.personnel);
  return val;
}
