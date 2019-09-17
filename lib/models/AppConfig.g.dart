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
      talkGroups: json['talkGroups'] as String,
      mapCacheTTL: json['mapCacheTTL'] as int,
      mapCacheCapacity: json['mapCacheCapacity'] as int,
      locationAccuracy: json['locationAccuracy'] as String,
      locationFastestInterval: json['locationFastestInterval'] as int,
      locationSmallestDisplacement:
          json['locationSmallestDisplacement'] as int);
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'sentryDns': instance.sentryDns,
      'onboarding': instance.onboarding,
      'division': instance.division,
      'department': instance.department,
      'talkGroups': instance.talkGroups,
      'storage': instance.storage,
      'locationWhenInUse': instance.locationWhenInUse,
      'mapCacheTTL': instance.mapCacheTTL,
      'mapCacheCapacity': instance.mapCacheCapacity,
      'locationAccuracy': instance.locationAccuracy,
      'locationFastestInterval': instance.locationFastestInterval,
      'locationSmallestDisplacement': instance.locationSmallestDisplacement,
      'demo': instance.demo,
      'demoRole': instance.demoRole
    };
