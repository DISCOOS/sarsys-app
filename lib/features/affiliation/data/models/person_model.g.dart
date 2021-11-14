// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'person_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonModel _$PersonModelFromJson(Map json) {
  return PersonModel(
    uuid: json['uuid'] as String,
    fname: json['fname'] as String?,
    lname: json['lname'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    userId: json['userId'] as String?,
    temporary: json['temporary'] as bool?,
  );
}

Map<String, dynamic> _$PersonModelToJson(PersonModel instance) {
  final val = <String, dynamic>{
    'uuid': instance.uuid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('fname', instance.fname);
  writeNotNull('lname', instance.lname);
  writeNotNull('phone', instance.phone);
  writeNotNull('email', instance.email);
  writeNotNull('userId', instance.userId);
  writeNotNull('temporary', instance.temporary);
  return val;
}
