import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Position.dart';
import 'converters.dart';

part 'Device.g.dart';

@JsonSerializable()
class Device extends Positionable<Map<String, dynamic>> {
  Device({
    @required String uuid,
    @required this.type,
    this.alias,
    this.number,
    this.manual,
    this.network,
    this.networkId,
    this.allocatedTo,
    Position position,
    this.status = DeviceStatus.Unavailable,
  }) : super(uuid, position, fields: [
          type,
          alias,
          number,
          manual,
          network,
          networkId,
          allocatedTo,
          status,
        ]);

  final bool manual;
  final DeviceType type;
  final DeviceStatus status;
  final String number;
  final String alias;
  final String network;
  final String networkId;
  @JsonKey(fromJson: toIncidentRef, nullable: true, includeIfNull: false)
  final AggregateRef<Incident> allocatedTo;

  /// Factory constructor for creating a new `Device` instance
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  /// Device name
  String get name => this.alias?.isNotEmpty == true ? this.alias : this.number;

  /// Get searchable string
  String get searchable => props.map((prop) => prop is DeviceType ? translateDeviceType(prop) : prop).join(' ');

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  /// Clone with json
  Device withJson(Map<String, dynamic> json) {
    var clone = Device.fromJson(json);
    return Device(
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
  Device cloneWith({
    String uuid,
    DeviceType type,
    DeviceStatus status,
    String alias,
    bool manual,
    String network,
    String networkId,
    String number,
    Position position,
    AggregateRef<Incident> allocatedTo,
  }) {
    return Device(
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

enum DeviceType {
  Tetra,
  App,
  APRS,
  AIS,
  Spot,
  InReach,
}

String translateDeviceType(DeviceType type) {
  switch (type) {
    case DeviceType.Tetra:
      return "Nødnett";
    default:
      return enumName(type);
  }
}

enum DeviceStatus { Unavailable, Available }

String translateDeviceStatus(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.Unavailable:
      return "Ikke tilgjengelig";
    case DeviceStatus.Available:
      return "Tilgjengelig";
    default:
      return enumName(status);
  }
}
