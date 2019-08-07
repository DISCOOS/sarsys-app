// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppConfig.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) {
  return AppConfig(
      sentryDns: json['sentryDns'] as String,
      onboarding: json['onboarding'] as bool,
      affiliation: json['affiliation'] as String,
      locationWhenInUse: json['locationWhenInUse'] as bool);
}

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'onboarding': instance.onboarding,
      'affiliation': instance.affiliation,
      'locationWhenInUse': instance.locationWhenInUse
    };
