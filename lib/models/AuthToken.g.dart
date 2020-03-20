// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AuthToken.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthToken _$AuthTokenFromJson(Map<String, dynamic> json) {
  return AuthToken(
    accessToken: json['accessToken'] as String,
    idToken: json['idToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessTokenExpiration: json['accessTokenExpiration'] == null
        ? null
        : DateTime.parse(json['accessTokenExpiration'] as String),
  );
}

Map<String, dynamic> _$AuthTokenToJson(AuthToken instance) => <String, dynamic>{
      'idToken': instance.idToken,
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'accessTokenExpiration':
          instance.accessTokenExpiration?.toIso8601String(),
    };
