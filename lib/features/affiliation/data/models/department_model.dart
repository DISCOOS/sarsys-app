// @dart=2.11

import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'department_model.g.dart';

@JsonSerializable()
class DepartmentModel extends Department {
  DepartmentModel({
    @required String uuid,
    @required String name,
    @required String suffix,
    @required AggregateRef<Division> division,
    @required bool active,
  }) : super(
          uuid: uuid,
          name: name,
          suffix: suffix,
          division: division,
          active: active,
        );

  /// Factory constructor for creating a new `DepartmentModel` instance
  factory DepartmentModel.fromJson(Map<String, dynamic> json) => _$DepartmentModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DepartmentModelToJson(this);

  @override
  AggregateRef<Department> toRef() => uuid != null ? AggregateRef.fromType<DepartmentModel>(uuid) : null;
}
