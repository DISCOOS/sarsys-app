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

  Device({
    @required this.id,
    @required this.type,
    this.number,
  }) : super([id, type]);

  /// Factory constructor for creating a new `Device` instance
  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

enum DeviceType { Tetra, Phone, APRS, AIS }

String translateDeviceType(DeviceType type) {
  switch (type) {
    case DeviceType.Tetra:
      return "Nødnett";
    case DeviceType.Phone:
      return "Mobiltelefon";
    default:
      return enumName(type);
  }
}
