import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'Device.g.dart';

@JsonSerializable()
class Device extends Equatable {
  final String id;
  final DeviceType type;
  final DeviceStatus status;
  final String number;
  final String alias;
  final Point point;

  Device({
    @required this.id,
    @required this.type,
    @required this.status,
    this.alias,
    this.number,
    this.point,
  }) : super([id, type, status, number, alias, point]);

  /// Factory constructor for creating a new `Device` instance
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  /// Device name
  get name => this.alias?.isNotEmpty == true ? this.alias : this.number;

  /// Get searchable string
  get searchable => props.map((prop) => prop is DeviceType ? translateDeviceType(prop) : prop).join(' ');

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  /// Clone with json
  Device withJson(Map<String, dynamic> json) {
    var clone = Device.fromJson(json);
    return Device(
      id: clone.id ?? this.id,
      type: clone.type ?? this.type,
      status: clone.status ?? this.status,
      alias: clone.alias ?? this.alias,
      number: clone.number ?? this.number,
      point: clone.point ?? this.point,
    );
  }

  /// Clone device and set given location
  Device cloneWith({
    DeviceType type,
    DeviceStatus status,
    String alias,
    String number,
    Point point,
  }) {
    return Device(
      id: this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      alias: alias ?? this.alias,
      number: number ?? this.number,
      point: point ?? this.point,
    );
  }
}

enum DeviceType { Tetra, Mobile, APRS, AIS }

String translateDeviceType(DeviceType type) {
  switch (type) {
    case DeviceType.Tetra:
      return "Nødnett";
    case DeviceType.Mobile:
      return "Mobiltelefon";
    default:
      return enumName(type);
  }
}

enum DeviceStatus { Attached, Detached }

String translateDeviceStatus(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.Attached:
      return "I bruk";
    case DeviceStatus.Detached:
      return "Fjernet";
    default:
      return enumName(status);
  }
}
