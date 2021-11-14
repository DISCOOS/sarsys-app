// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'OperationalFunction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OperationalFunction _$OperationalFunctionFromJson(Map json) {
  return OperationalFunction(
    name: json['name'] as String?,
    pattern: json['pattern'] as String?,
  );
}

Map<String, dynamic> _$OperationalFunctionToJson(OperationalFunction instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('pattern', instance.pattern);
  return val;
}
