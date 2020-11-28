import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

abstract class TrackingSource extends EntityObject<Map<String, dynamic>> {
  TrackingSource({
    @required this.uuid,
    @required this.type,
  }) : super(uuid, fields: [type]);

  /// EntityObject id is renamed to uuid in backend
  @JsonKey(ignore: true)
  @protected
  @override
  String get id => super.id;

  /// Source uuid
  final String uuid;

  /// Source type
  final SourceType type;

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson();

  /// Get SourceType from Aggregate Type [T]
  static SourceType toSourceType<T extends Aggregate>() {
    final type = typeOf<T>();
    switch (type) {
      case Device:
        return SourceType.device;
      case Unit:
      case Personnel:
        return SourceType.trackable;
    }
    throw ArgumentError(
      "Aggregate $type not supported as tracking Source",
    );
  }
}

enum SourceType {
  device,
  trackable,
}
