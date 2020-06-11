import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/converters.dart';
import 'package:SarSys/models/core.dart';

part 'device_model.g.dart';

@JsonSerializable()
class DeviceModel extends Device implements JsonObject<Map<String, dynamic>> {
  DeviceModel({
    @required String uuid,
    @required DeviceType type,
    String alias,
    String number,
    bool manual,
    String network,
    String networkId,
    this.allocatedTo,
    Position position,
    DeviceStatus status = DeviceStatus.unavailable,
  }) : super(
          uuid: uuid,
          position: position,
          type: type,
          alias: alias,
          number: number,
          manual: manual,
          network: network,
          networkId: networkId,
          allocatedTo: allocatedTo,
          status: status,
        );

  @override
  @JsonKey(fromJson: toIncidentRef)
  final AggregateRef<Incident> allocatedTo;

  /// Factory constructor for creating a new `Device` instance
  factory DeviceModel.fromJson(Map<String, dynamic> json) => _$DeviceModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);

  /// Merge with with json
  Device mergeWith(Map<String, dynamic> json) {
    var clone = DeviceModel.fromJson(json);
    return DeviceModel(
      uuid: clone.uuid ?? this.uuid,
      type: clone.type ?? this.type,
      alias: clone.alias ?? this.alias,
      manual: clone.manual ?? this.manual,
      position: clone.position ?? this.position,
      number: clone.number ?? this.number,
      status: clone.status ?? this.status,
      network: clone.network ?? this.network,
      networkId: clone.networkId ?? this.networkId,
      allocatedTo: clone.allocatedTo ?? this.allocatedTo,
    );
  }

  /// Clone device and set given location
  Device copyWith({
    String uuid,
    bool manual,
    String alias,
    String number,
    String network,
    DeviceType type,
    String networkId,
    Position position,
    DeviceStatus status,
    AggregateRef<Incident> allocatedTo,
  }) {
    return DeviceModel(
      uuid: uuid ?? this.uuid,
      type: type ?? this.type,
      alias: alias ?? this.alias,
      number: number ?? this.number,
      status: status ?? this.status,
      manual: manual ?? this.manual,
      network: network ?? this.network,
      position: position ?? this.position,
      networkId: networkId ?? this.networkId,
      allocatedTo: allocatedTo ?? this.allocatedTo,
    );
  }
}
