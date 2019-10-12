// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppConfig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return AppConfig(
      sentryDns: json['sentryDns'] as String,
      demo: json['demo'] as bool,
      demoRole: json['demoRole'] as String,
      onboarding: json['onboarding'] as bool,
      storage: json['storage'] as bool,
      locationWhenInUse: json['locationWhenInUse'] as bool,
      division: json['division'] as String,
      department: json['department'] as String,
      talkGroups:
          (json['talkGroups'] as List)?.map((e) => e as String)?.toList(),
      talkGroupCatalog: json['talkGroupCatalog'] as String,
      mapCacheTTL: json['mapCacheTTL'] as int,
      mapCacheCapacity: json['mapCacheCapacity'] as int,
      locationAccuracy: json['locationAccuracy'] as String,
      locationFastestInterval: json['locationFastestInterval'] as int,
      locationSmallestDisplacement: json['locationSmallestDisplacement'] as int,
      keepScreenOn: json['keepScreenOn'] as bool,
      callsignReuse: json['callsignReuse'] as bool);
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
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
      'callsignReuse': instance.callsignReuse
    };
