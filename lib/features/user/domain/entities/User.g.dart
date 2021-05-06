// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'User.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map json) {
  return User(
    userId: json['userId'] as String,
    fname: json['fname'] as String,
    lname: json['lname'] as String,
    uname: json['uname'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String,
    security: json['security'] == null
        ? null
        : Security.fromJson((json['security'] as Map)?.map(
            (k, e) => MapEntry(k as String, e),
          )),
    org: json['org'] as String,
    div: json['div'] as String,
    dep: json['dep'] as String,
    roles: (json['roles'] as List)
            ?.map((e) => _$enumDecodeNullable(_$UserRoleEnumMap, e))
            ?.toList() ??
        [],
    passcodes:
        (json['passcodes'] as List)?.map((e) => e as String)?.toList() ?? [],
  );
}

Map<String, dynamic> _$UserToJson(User instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('userId', instance.userId);
  writeNotNull('fname', instance.fname);
  writeNotNull('lname', instance.lname);
  writeNotNull('uname', instance.uname);
  writeNotNull('email', instance.email);
  writeNotNull('phone', instance.phone);
  writeNotNull('org', instance.org);
  writeNotNull('div', instance.div);
  writeNotNull('dep', instance.dep);
  writeNotNull('security', instance.security?.toJson());
  writeNotNull(
      'roles', instance.roles?.map((e) => _$UserRoleEnumMap[e])?.toList());
  writeNotNull('passcodes', instance.passcodes);
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

const _$UserRoleEnumMap = {
  UserRole.commander: 'commander',
  UserRole.planning_chief: 'planning_chief',
  UserRole.operations_chief: 'operations_chief',
  UserRole.unit_leader: 'unit_leader',
  UserRole.personnel: 'personnel',
};
