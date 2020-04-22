// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Address _$AddressFromJson(Map json) {
  return Address(
    lines: (json['lines'] as List)?.map((e) => e as String)?.toList(),
    postalCode: json['postalCode'] as String,
    countryCode: json['countryCode'] as String,
  );
}

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
      'lines': instance.lines,
      'postalCode': instance.postalCode,
      'countryCode': instance.countryCode,
    };
