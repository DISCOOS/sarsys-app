import 'package:SarSys/core/domain/models/converters.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/core/domain/models/core.dart';

part 'unit_model.g.dart';

@JsonSerializable()
class UnitModel extends Unit implements JsonObject<Map<String, dynamic>> {
  UnitModel({
    @required String uuid,
    @required UnitType type,
    @required int number,
    @required UnitStatus status,
    @required String callsign,
    String phone,
    List<String> personnels = const [],
    AggregateRef<Tracking> tracking,
  }) : super(
          uuid: uuid,
          type: type,
          phone: phone,
          number: number,
          status: status,
          tracking: tracking,
          callsign: callsign,
          personnels: personnels,
        );

  /// Factory constructor for creating a new `Unit` instance from json data
  factory UnitModel.fromJson(Map<String, dynamic> json) => _$UnitModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$UnitModelToJson(this);

  /// Clone with json
  Unit mergeWith(Map<String, dynamic> json) {
    var clone = UnitModel.fromJson(json);
    return copyWith(
      uuid: clone.uuid,
      type: clone.type,
      number: clone.number,
      status: clone.status,
      phone: clone.phone,
      callsign: clone.callsign,
      tracking: clone.tracking,
      personnels: clone.personnels ?? const [],
    );
  }

  Unit copyWith({
    String uuid,
    UnitType type,
    int number,
    UnitStatus status,
    String phone,
    String callsign,
    List<String> personnels,
    AggregateRef<Tracking> tracking,
  }) {
    return UnitModel(
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      number: number ?? this.number,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      callsign: callsign ?? this.callsign,
      tracking: tracking ?? this.tracking,
      personnels: personnels ?? this.personnels ?? const [],
    );
  }
}
