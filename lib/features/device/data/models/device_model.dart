import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/core/domain/models/AggregateRef.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/core/domain/models/converters.dart';
import 'package:SarSys/core/domain/models/core.dart';

part 'device_model.g.dart';

@JsonSerializable()
class DeviceModel extends Device implements JsonObject<Map<String, dynamic>> {
  DeviceModel({
    @required String uuid,
    @required DeviceType type,
    String alias,
    String number,
    bool manual,
    bool trackable,
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
          trackable: trackable,
          networkId: networkId,
          allocatedTo: allocatedTo,
          status: status,
        );

  @override
  List<Object> get props => [
        uuid,
        position,
        type,
        alias,
        number,
        manual,
        network,
        trackable,
        networkId,
        allocatedTo,
        status,
      ];

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
      number: clone.number ?? this.number,
      status: clone.status ?? this.status,
      network: clone.network ?? this.network,
      position: clone.position ?? this.position,
      trackable: clone.trackable ?? this.trackable,
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
    bool trackable,
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
      trackable: trackable ?? this.trackable,
      networkId: networkId ?? this.networkId,
      allocatedTo: allocatedTo ?? this.allocatedTo,
    );
  }
}
