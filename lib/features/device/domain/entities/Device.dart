import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'package:SarSys/models/AggregateRef.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/models/Position.dart';
import 'package:SarSys/models/converters.dart';
import 'package:SarSys/utils/data_utils.dart';

abstract class Device extends Positionable<Map<String, dynamic>> {
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
    this.status = DeviceStatus.unavailable,
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

  /// Device name
  String get name => this.alias?.isNotEmpty == true ? this.alias : this.number;

  /// Get searchable string
  String get searchable => props.map((prop) => prop is DeviceType ? translateDeviceType(prop) : prop).join(' ');

  /// Merge with json
  Device mergeWith(Map<String, dynamic> json);

  /// Clone device and set given location
  Device copyWith({
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
  });
}

enum DeviceType {
  tetra,
  app,
  aprs,
  ais,
  spot,
  inreach,
}

String translateDeviceType(DeviceType type) {
  switch (type) {
    case DeviceType.tetra:
      return "Nødnett";
    default:
      return enumName(type);
  }
}

enum DeviceStatus { unavailable, available }

String translateDeviceStatus(DeviceStatus status) {
  switch (status) {
    case DeviceStatus.unavailable:
      return "Ikke tilgjengelig";
    case DeviceStatus.available:
      return "Tilgjengelig";
    default:
      return enumName(status);
  }
}
