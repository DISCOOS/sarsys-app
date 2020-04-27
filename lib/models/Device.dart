import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Device.g.dart';

@JsonSerializable()
class Device extends Equatable {
  final String uuid;
  final DeviceType type;
  final DeviceStatus status;
  final String number;
  final String alias;
  final String network;
  final String networkId;
  final Point position;
  @JsonKey(fromJson: _toIncidentRef, nullable: true, includeIfNull: false)
  final AggregateRef<Incident> allocatedTo;

  /// Flag indication that device is added manually
  final bool manual;

  Device({
    @required this.uuid,
    @required this.type,
    this.alias,
    this.number,
    this.position,
    this.network,
    this.networkId,
    this.allocatedTo,
    this.manual = true,
    this.status = DeviceStatus.Unavailable,
  }) : super([
          uuid,
          type,
          status,
          number,
          alias,
          network,
          networkId,
          allocatedTo,
          position,
        ]);

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
      position: clone.position ?? this.position,
      number: clone.number ?? this.number,
      manual: clone.manual ?? this.manual,
      status: clone.status ?? this.status,
      network: clone.network ?? this.network,
      networkId: clone.networkId ?? this.networkId,
      allocatedTo: clone.allocatedTo ?? this.allocatedTo,
    );
  }

  /// Clone device and set given location
  Device cloneWith({
    DeviceType type,
    DeviceStatus status,
    String alias,
    String network,
    String networkId,
    String number,
    Point position,
    bool manual,
    AggregateRef<Incident> allocatedTo,
  }) {
    return Device(
      uuid: this.uuid,
      type: type ?? this.type,
      status: status ?? this.status,
      alias: alias ?? this.alias,
      network: network ?? this.network,
      networkId: networkId ?? this.networkId,
      number: number ?? this.number,
      position: position ?? this.position,
      manual: manual ?? this.manual,
      allocatedTo: allocatedTo ?? this.allocatedTo,
    );
  }

  static _toIncidentRef(json) => json != null ? AggregateRef<Incident>.fromJson(json) : null;
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
