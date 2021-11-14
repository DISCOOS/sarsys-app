// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfigModel _$AppConfigModelFromJson(Map json) {
  return AppConfigModel(
    uuid: json['uuid'] as String,
    udid: json['udid'] as String?,
    sentryDns: json['sentryDns'] as String?,
    version: json['version'] as int?,
    demo: json['demo'] as bool?,
    demoRole: json['demoRole'] as String?,
    onboarded: json['onboarded'] as bool?,
    firstSetup: json['firstSetup'] as bool?,
    storage: json['storage'] as bool?,
    locationAlways: json['locationAlways'] as bool?,
    locationWhenInUse: json['locationWhenInUse'] as bool?,
    activityRecognition: json['activityRecognition'] as bool?,
    talkGroups: (json['talkGroups'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    talkGroupCatalog: json['talkGroupCatalog'] as String?,
    mapCacheTTL: json['mapCacheTTL'] as int?,
    mapRetinaMode: json['mapRetinaMode'] as bool?,
    mapCacheCapacity: json['mapCacheCapacity'] as int?,
    locationStoreLocally: json['locationStoreLocally'] as bool?,
    locationAllowSharing: json['locationAllowSharing'] as bool?,
    locationAccuracy: json['locationAccuracy'] as String?,
    locationFastestInterval: json['locationFastestInterval'] as int?,
    locationSmallestDisplacement: json['locationSmallestDisplacement'] as int?,
    units: (json['units'] as List<dynamic>?)?.map((e) => e as String).toList(),
    idpHints:
        (json['idpHints'] as List<dynamic>?)?.map((e) => e as String).toList(),
    keepScreenOn: json['keepScreenOn'] as bool?,
    callsignReuse: json['callsignReuse'] as bool?,
    securityType:
        _$enumDecodeNullable(_$SecurityTypeEnumMap, json['securityType']),
    securityMode:
        _$enumDecodeNullable(_$SecurityModeEnumMap, json['securityMode']),
    trustedDomains: (json['trustedDomains'] as List<dynamic>?)
        ?.map((e) => e as String?)
        .toList(),
    securityLockAfter: json['securityLockAfter'] as int?,
    locationDebug: json['locationDebug'] as bool?,
  );
}

Map<String, dynamic> _$AppConfigModelToJson(AppConfigModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('udid', instance.udid);
  writeNotNull('version', instance.version);
  writeNotNull('demo', instance.demo);
  writeNotNull('demoRole', instance.demoRole);
  val['sentryDns'] = instance.sentryDns;
  val['onboarded'] = instance.onboarded;
  val['firstSetup'] = instance.firstSetup;
  val['talkGroups'] = instance.talkGroups;
  val['talkGroupCatalog'] = instance.talkGroupCatalog;
  val['storage'] = instance.storage;
  val['locationAlways'] = instance.locationAlways;
  val['locationWhenInUse'] = instance.locationWhenInUse;
  val['activityRecognition'] = instance.activityRecognition;
  val['mapCacheTTL'] = instance.mapCacheTTL;
  val['mapRetinaMode'] = instance.mapRetinaMode;
  val['mapCacheCapacity'] = instance.mapCacheCapacity;
  val['locationAllowSharing'] = instance.locationAllowSharing;
  val['locationStoreLocally'] = instance.locationStoreLocally;
  val['locationAccuracy'] = instance.locationAccuracy;
  val['locationFastestInterval'] = instance.locationFastestInterval;
  val['locationSmallestDisplacement'] = instance.locationSmallestDisplacement;
  val['keepScreenOn'] = instance.keepScreenOn;
  val['callsignReuse'] = instance.callsignReuse;
  val['units'] = instance.units;
  val['idpHints'] = instance.idpHints;
  val['securityType'] = _$SecurityTypeEnumMap[instance.securityType];
  val['securityMode'] = _$SecurityModeEnumMap[instance.securityMode];
  val['trustedDomains'] = instance.trustedDomains;
  val['securityLockAfter'] = instance.securityLockAfter;
  val['locationDebug'] = instance.locationDebug;
  return val;
}

K _$enumDecode<K, V>(
  Map<K, V> enumValues,
  Object? source, {
  K? unknownValue,
}) {
  if (source == null) {
    throw ArgumentError(
      'A value must be provided. Supported values: '
      '${enumValues.values.join(', ')}',
    );
  }

  return enumValues.entries.singleWhere(
    (e) => e.value == source,
    orElse: () {
      if (unknownValue == null) {
        throw ArgumentError(
          '`$source` is not one of the supported values: '
          '${enumValues.values.join(', ')}',
        );
      }
      return MapEntry(unknownValue, enumValues.values.first);
    },
  ).key;
}

K? _$enumDecodeNullable<K, V>(
  Map<K, V> enumValues,
  dynamic source, {
  K? unknownValue,
}) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<K, V>(enumValues, source, unknownValue: unknownValue);
}

const _$SecurityTypeEnumMap = {
  SecurityType.pin: 'pin',
  SecurityType.fingerprint: 'fingerprint',
};

const _$SecurityModeEnumMap = {
  SecurityMode.personal: 'personal',
  SecurityMode.shared: 'shared',
};
