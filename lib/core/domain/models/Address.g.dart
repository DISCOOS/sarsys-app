// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map json) {
  return Address(
    lines: (json['lines'] as List<dynamic>?)?.map((e) => e as String).toList(),
    postalCode: json['postalCode'] as String?,
    countryCode: json['countryCode'] as String?,
  );
}

Map<String, dynamic> _$AddressToJson(Address instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('lines', instance.lines);
  writeNotNull('postalCode', instance.postalCode);
  writeNotNull('countryCode', instance.countryCode);
  return val;
}
