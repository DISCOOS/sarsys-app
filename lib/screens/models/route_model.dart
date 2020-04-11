import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'route_model.g.dart';

@JsonSerializable()
class RouteModel extends Equatable {
  RouteModel(this.data, this.name, this.incidentId) : super([data, name, incidentId]);
  final String name;
  final dynamic data;
  final String incidentId;

  /// Factory constructor for creating a new `Route` instance
  factory RouteModel.fromJson(Map<String, dynamic> json) => _$RouteModelFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$RouteModelToJson(this);
}
