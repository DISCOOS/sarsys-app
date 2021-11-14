// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AuthToken.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthToken _$AuthTokenFromJson(Map json) {
  return AuthToken(
    accessToken: json['accessToken'] as String?,
    idToken: json['idToken'] as String?,
    clientId: json['clientId'] as String?,
    refreshToken: json['refreshToken'] as String?,
    accessTokenExpiration: json['accessTokenExpiration'] == null
        ? null
        : DateTime.parse(json['accessTokenExpiration'] as String),
  );
}

Map<String, dynamic> _$AuthTokenToJson(AuthToken instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('idToken', instance.idToken);
  writeNotNull('clientId', instance.clientId);
  writeNotNull('accessToken', instance.accessToken);
  writeNotNull('refreshToken', instance.refreshToken);
  writeNotNull('accessTokenExpiration',
      instance.accessTokenExpiration?.toIso8601String());
  return val;
}
