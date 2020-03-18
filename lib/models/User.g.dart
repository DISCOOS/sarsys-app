// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'User.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) {
  return User(
      userId: json['userId'] as String,
      fname: json['fname'] as String,
      lname: json['lname'] as String,
      uname: json['uname'] as String,
      roles: (json['roles'] as List)
          ?.map((e) => _$enumDecodeNullable(_$UserRoleEnumMap, e))
          ?.toList(),
      phone: json['phone'] as String,
      email: json['email'] as String);
}

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'userId': instance.userId,
      'fname': instance.fname,
      'lname': instance.lname,
      'uname': instance.uname,
      'email': instance.email,
      'phone': instance.phone,
      'roles': instance.roles?.map((e) => _$UserRoleEnumMap[e])?.toList()
    };

T _$enumDecode<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    throw ArgumentError('A value must be provided. Supported values: '
        '${enumValues.values.join(', ')}');
  }
  return enumValues.entries
      .singleWhere((e) => e.value == source,
          orElse: () => throw ArgumentError(
              '`$source` is not one of the supported values: '
              '${enumValues.values.join(', ')}'))
      .key;
}

T _$enumDecodeNullable<T>(Map<T, dynamic> enumValues, dynamic source) {
  if (source == null) {
    return null;
  }
  return _$enumDecode<T>(enumValues, source);
}

const _$UserRoleEnumMap = <UserRole, dynamic>{
  UserRole.commander: 'commander',
  UserRole.unit_leader: 'unit_leader',
  UserRole.personnel: 'personnel'
};
