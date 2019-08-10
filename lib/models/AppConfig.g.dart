// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppConfig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return AppConfig(
      sentryDns: json['sentryDns'] as String,
      onboarding: json['onboarding'] as bool,
      district: json['district'] as String,
      department: json['department'] as String,
      talkGroups: json['talkGroups'] as String,
      locationWhenInUse: json['locationWhenInUse'] as bool);
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'sentryDns': instance.sentryDns,
      'onboarding': instance.onboarding,
      'district': instance.district,
      'department': instance.department,
      'talkGroups': instance.talkGroups,
      'locationWhenInUse': instance.locationWhenInUse
    };
