// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfigModel _$AppConfigModelFromJson(Map json) {
  return AppConfigModel(
    uuid: json['uuid'] as String,
    udid: json['udid'] as String,
    sentryDns: json['sentryDns'] as String,
    version: json['version'] as int,
    demo: json['demo'] as bool,
    demoRole: json['demoRole'] as String,
    onboarded: json['onboarded'] as bool,
    firstSetup: json['firstSetup'] as bool,
    storage: json['storage'] as bool,
    locationAlways: json['locationAlways'] as bool,
    locationWhenInUse: json['locationWhenInUse'] as bool,
    activityRecognition: json['activityRecognition'] as bool,
    talkGroups: (json['talkGroups'] as List)?.map((e) => e as String)?.toList(),
    talkGroupCatalog: json['talkGroupCatalog'] as String,
    mapCacheTTL: json['mapCacheTTL'] as int,
    mapRetinaMode: json['mapRetinaMode'] as bool,
    mapCacheCapacity: json['mapCacheCapacity'] as int,
    locationStoreLocally: json['locationStoreLocally'] as bool,
    locationAllowSharing: json['locationAllowSharing'] as bool,
    locationAccuracy: json['locationAccuracy'] as String,
    locationFastestInterval: json['locationFastestInterval'] as int,
    locationSmallestDisplacement: json['locationSmallestDisplacement'] as int,
    units: (json['units'] as List)?.map((e) => e as String)?.toList(),
    idpHints: (json['idpHints'] as List)?.map((e) => e as String)?.toList(),
    keepScreenOn: json['keepScreenOn'] as bool,
    callsignReuse: json['callsignReuse'] as bool,
    securityType:
        _$enumDecodeNullable(_$SecurityTypeEnumMap, json['securityType']),
    securityMode:
        _$enumDecodeNullable(_$SecurityModeEnumMap, json['securityMode']),
    trustedDomains:
        (json['trustedDomains'] as List)?.map((e) => e as String)?.toList(),
    securityLockAfter: json['securityLockAfter'] as int,
    locationDebug: json['locationDebug'] as bool,
  );
}

Map<String, dynamic> _$AppConfigModelToJson(AppConfigModel instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uuid', instance.uuid);
  writeNotNull('udid', instance.udid);
  writeNotNull('version', instance.version);
  writeNotNull('demo', instance.demo);
  writeNotNull('demoRole', instance.demoRole);
  writeNotNull('sentryDns', instance.sentryDns);
  writeNotNull('onboarded', instance.onboarded);
  writeNotNull('firstSetup', instance.firstSetup);
  writeNotNull('talkGroups', instance.talkGroups);
  writeNotNull('talkGroupCatalog', instance.talkGroupCatalog);
  writeNotNull('storage', instance.storage);
  writeNotNull('locationAlways', instance.locationAlways);
  writeNotNull('locationWhenInUse', instance.locationWhenInUse);
  writeNotNull('activityRecognition', instance.activityRecognition);
  writeNotNull('mapCacheTTL', instance.mapCacheTTL);
  writeNotNull('mapRetinaMode', instance.mapRetinaMode);
  writeNotNull('mapCacheCapacity', instance.mapCacheCapacity);
  writeNotNull('locationAllowSharing', instance.locationAllowSharing);
  writeNotNull('locationStoreLocally', instance.locationStoreLocally);
  writeNotNull('locationAccuracy', instance.locationAccuracy);
  writeNotNull('locationFastestInterval', instance.locationFastestInterval);
  writeNotNull(
      'locationSmallestDisplacement', instance.locationSmallestDisplacement);
  writeNotNull('keepScreenOn', instance.keepScreenOn);
  writeNotNull('callsignReuse', instance.callsignReuse);
  writeNotNull('units', instance.units);
  writeNotNull('idpHints', instance.idpHints);
  writeNotNull('securityType', _$SecurityTypeEnumMap[instance.securityType]);
  writeNotNull('securityMode', _$SecurityModeEnumMap[instance.securityMode]);
  writeNotNull('trustedDomains', instance.trustedDomains);
  writeNotNull('securityLockAfter', instance.securityLockAfter);
  writeNotNull('locationDebug', instance.locationDebug);
  return val;
}

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
