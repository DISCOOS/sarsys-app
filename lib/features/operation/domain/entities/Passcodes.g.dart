// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Passcodes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Passcodes _$PasscodesFromJson(Map json) {
  return Passcodes(
    command: json['command'] as String,
    personnel: json['personnel'] as String,
  );
}

Map<String, dynamic> _$PasscodesToJson(Passcodes instance) => <String, dynamic>{
      'command': instance.command,
      'personnel': instance.personnel,
    };
