// @dart=2.11

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'FleetMap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FleetMap _$FleetMapFromJson(Map json) {
  return FleetMap(
    name: json['name'] as String,
    alias: json['alias'] as String,
    prefix: json['prefix'] as String,
    pattern: json['pattern'] as String,
    numbers: (json['numbers'] as List)
        ?.map((e) => e == null
            ? null
            : FleetMapNumber.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    catalogs: (json['catalogs'] as List)
        ?.map((e) => e == null
            ? null
            : TalkGroupCatalog.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
    functions: (json['functions'] as List)
        ?.map((e) => e == null
            ? null
            : OperationalFunction.fromJson((e as Map)?.map(
                (k, e) => MapEntry(k as String, e),
              )))
        ?.toList(),
  );
}

Map<String, dynamic> _$FleetMapToJson(FleetMap instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('prefix', instance.prefix);
  writeNotNull('alias', instance.alias);
  writeNotNull('pattern', instance.pattern);
  writeNotNull('numbers', instance.numbers?.map((e) => e?.toJson())?.toList());
  writeNotNull(
      'catalogs', instance.catalogs?.map((e) => e?.toJson())?.toList());
  writeNotNull(
      'functions', instance.functions?.map((e) => e?.toJson())?.toList());
  return val;
}
