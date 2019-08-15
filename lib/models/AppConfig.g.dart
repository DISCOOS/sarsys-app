// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppConfig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return AppConfig(
      sentryDns: json['sentryDns'] as String,
      onboarding: json['onboarding'] as bool,
      division: json['division'] as String,
      department: json['department'] as String,
      tgCatalog: json['tgCatalog'] as String,
      locationWhenInUse: json['locationWhenInUse'] as bool);
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'sentryDns': instance.sentryDns,
      'onboarding': instance.onboarding,
      'division': instance.division,
      'department': instance.department,
      'tgCatalog': instance.tgCatalog,
      'locationWhenInUse': instance.locationWhenInUse
    };
