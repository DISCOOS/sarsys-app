// @dart=2.11

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/domain/entities/PositionList.dart';

part 'position_list_model.g.dart';

@JsonSerializable()
class PositionListModel extends PositionList {
  PositionListModel({
    @required String id,
    @required List<Position> features,
  }) : super(
          id: id,
          features: features,
        );

  /// Factory constructor for creating a new `TrackModel`  instance
  factory PositionListModel.fromJson(Map<String, dynamic> json) => _$PositionListModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$PositionListModelToJson(this);

  PositionList cloneWith({
    String id,
    List<Position> features,
  }) =>
      PositionListModel(
        id: id ?? this.id,
        features: features ?? this.features,
      );

  /// Truncate to number of points and return new [PositionListModel] instance
  PositionListModel truncate(int count) => PositionListModel(
        id: id,
        features: features.skip(max(0, features.length - count)).toList(),
      );
}
