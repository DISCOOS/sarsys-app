// @dart=2.11

import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:meta/meta.dart';

abstract class PositionList extends EntityObject<Map<String, dynamic>> {
  PositionList({
    @required String id,
    @required this.features,
  }) : super(id, fields: [
          features,
        ]);

  final List<Position> features;
  final String type = 'FeatureCollection';

  bool get isNotEmpty => !isEmpty;
  bool get isEmpty => features?.isEmpty == true;

  PositionList cloneWith({
    String id,
    List<Position> features,
  });

  /// Truncate to number of points and return new [PositionList] instance
  PositionList truncate(int count);
}
