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
  final Point point;

  /// Flag indication that device is added manually
  final bool manual;

  Device({
    @required this.uuid,
    @required this.type,
    this.alias,
    this.number,
    this.point,
    this.manual = true,
    this.status = DeviceStatus.Attached,
  }) : super([uuid, type, status, number, alias, point]);

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
      status: clone.status ?? this.status,
      alias: clone.alias ?? this.alias,
      number: clone.number ?? this.number,
      point: clone.point ?? this.point,
      manual: clone.manual ?? this.manual,
    );
  }

  /// Clone device and set given location
  Device cloneWith({
    DeviceType type,
    DeviceStatus status,
    String alias,
    String number,
    Point point,
    bool manual,
  }) {
    return Device(
      uuid: this.uuid,
      type: type ?? this.type,
      status: status ?? this.status,
      alias: alias ?? this.alias,
      number: number ?? this.number,
      point: point ?? this.point,
      manual: manual ?? this.manual,
    );
  }
}

enum DeviceType { Tetra, App, APRS, AIS }

String translateDeviceType(DeviceType type) {
  switch (type) {
    case DeviceType.Tetra:
      return "Nødnett";
    case DeviceType.App:
      return "App";
    default:
      return enumName(type);
  }
}

enum DeviceStatus { Attached, Detached }

String translateDeviceStatus(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.Attached:
      return "Tilknyttet";
    case DeviceStatus.Detached:
      return "Ikke tilknyttet";
    default:
      return enumName(status);
  }
}
