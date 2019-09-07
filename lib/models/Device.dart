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
  final String number;
  final Point location;

  Device({
    @required this.id,
    @required this.type,
    this.number,
    this.location,
  }) : super([id, type, number]);

  /// Factory constructor for creating a new `Device` instance
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  /// Device name
  get name => "${translateDeviceType(type)} $number";

  /// Get searchable string
  get searchable => props.map((prop) => prop is DeviceType ? translateDeviceType(prop) : prop).join(' ');

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  /// Clone device and set given location
  Device cloneWith({
    Point location,
  }) {
    return Device(
      id: this.id,
      type: this.type,
      number: this.number,
      location: location ?? this.location,
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
