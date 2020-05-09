import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'Device.dart';
import 'Tracking.dart';

part 'Source.g.dart';

@JsonSerializable()
class Source extends EntityObject<Map<String, dynamic>> {
  Source({
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

  /// Factory constructor for creating a new `Source` instance
  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);

  /// Get [Source] from given [aggregate].
  /// Only [Device] and [Tracking] is supported.
  /// An [ArgumentError] in
  static Source fromType<T extends Aggregate>(T aggregate) => Source(
        uuid: aggregate.uuid,
        type: toSourceType<T>(),
      );

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SourceToJson(this);

  static SourceType toSourceType<T extends Aggregate>() {
    final type = typeOf<T>();
    switch (type) {
      case Device:
        return SourceType.device;
      case Unit:
      case Personnel:
      case Tracking:
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
