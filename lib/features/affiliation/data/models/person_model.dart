import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'person_model.g.dart';

@JsonSerializable()
class PersonModel extends Person {
  PersonModel({
    @required String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool temporary,
  }) : super(
          uuid: uuid,
          fname: fname,
          lname: lname,
          phone: phone,
          email: email,
          userId: userId,
          temporary: temporary,
        );

  /// Factory constructor for creating a new `Person` instance
  factory PersonModel.fromJson(Map<String, dynamic> json) => _$PersonModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PersonModelToJson(this);

  static PersonModel fromUser(User user, {bool temporary = false}) => PersonModel(
        uuid: Uuid().v4(),
        fname: user?.fname,
        lname: user?.lname,
        phone: user?.phone,
        email: user?.email,
        userId: user?.userId,
        temporary: temporary,
      );

  static PersonModel fromPersonnel(Personnel personnel, {bool temporary = false}) => PersonModel(
        uuid: personnel.person?.uuid ?? Uuid().v4(),
        fname: personnel?.fname,
        lname: personnel?.lname,
        phone: personnel?.phone,
        email: personnel?.email,
        userId: personnel?.userId,
        temporary: temporary,
      );

  @override
  Person copyWith({
    String uuid,
    String fname,
    String lname,
    String phone,
    String email,
    String userId,
    bool temporary,
  }) =>
      PersonModel(
        uuid: uuid ?? this.uuid,
        fname: fname ?? this.fname,
        lname: lname ?? this.lname,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        userId: userId ?? this.userId,
        temporary: temporary ?? this.temporary,
      );

  @override
  AggregateRef<Person> toRef() => uuid != null ? AggregateRef.fromType<PersonModel>(uuid) : null;
}

enum PersonConflictCode { duplicate_user_id }
