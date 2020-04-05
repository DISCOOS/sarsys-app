// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppConfig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return AppConfig(
    uuid: json['uuid'] as String,
    udid: json['udid'] as String,
    sentryDns: json['sentryDns'] as String,
    demo: json['demo'] as bool,
    demoRole: json['demoRole'] as String,
    onboarding: json['onboarding'] as bool,
    storage: json['storage'] as bool,
    locationWhenInUse: json['locationWhenInUse'] as bool,
    division: json['division'] as String,
    department: json['department'] as String,
    talkGroups: (json['talkGroups'] as List)?.map((e) => e as String)?.toList(),
    talkGroupCatalog: json['talkGroupCatalog'] as String,
    mapCacheTTL: json['mapCacheTTL'] as int,
    mapCacheCapacity: json['mapCacheCapacity'] as int,
    locationAccuracy: json['locationAccuracy'] as String,
    locationFastestInterval: json['locationFastestInterval'] as int,
    locationSmallestDisplacement: json['locationSmallestDisplacement'] as int,
    units: (json['units'] as List)?.map((e) => e as String)?.toList(),
    keepScreenOn: json['keepScreenOn'] as bool,
    callsignReuse: json['callsignReuse'] as bool,
    securityType:
        _$enumDecodeNullable(_$SecurityTypeEnumMap, json['securityType']),
    securityMode:
        _$enumDecodeNullable(_$SecurityModeEnumMap, json['securityMode']),
    securityLockAfter: json['securityLockAfter'] as int,
  );
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'udid': instance.udid,
      'demo': instance.demo,
      'demoRole': instance.demoRole,
      'sentryDns': instance.sentryDns,
      'onboarding': instance.onboarding,
      'division': instance.division,
      'department': instance.department,
      'talkGroups': instance.talkGroups,
      'talkGroupCatalog': instance.talkGroupCatalog,
      'storage': instance.storage,
      'locationWhenInUse': instance.locationWhenInUse,
      'mapCacheTTL': instance.mapCacheTTL,
      'mapCacheCapacity': instance.mapCacheCapacity,
      'locationAccuracy': instance.locationAccuracy,
      'locationFastestInterval': instance.locationFastestInterval,
      'locationSmallestDisplacement': instance.locationSmallestDisplacement,
      'keepScreenOn': instance.keepScreenOn,
      'callsignReuse': instance.callsignReuse,
      'units': instance.units,
      'securityType': _$SecurityTypeEnumMap[instance.securityType],
      'securityMode': _$SecurityModeEnumMap[instance.securityMode],
      'securityLockAfter': instance.securityLockAfter,
    };

T _$enumDecode<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }

  final value = enumValues.entries
      .singleWhere((e) => e.value == source, orElse: () => null)
      ?.key;

  if (value == null && unknownValue == null) {
    throw ArgumentError('`$source` is not one of the supported values: '
        '${enumValues.values.join(', ')}');
  }
  return value ?? unknownValue;
}

T _$enumDecodeNullable<T>(
  Map<T, dynamic> enumValues,
  dynamic source, {
  T unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source, unknownValue: unknownValue);
}

const _$SecurityTypeEnumMap = {
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint',
};

const _$SecurityModeEnumMap = {
  SecurityMode.personal: 'personal',
  SecurityMode.shared: 'shared',
};
