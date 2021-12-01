import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'subscription_event_model.g.dart';

@JsonSerializable(explicitToJson: true)
class SubscriptionEventModel extends Equatable {
  const SubscriptionEventModel({
    required this.name,
    this.statePatches,
    this.changedState,
    this.previousState,
  }) : super();

  factory SubscriptionEventModel.changed(String name) => SubscriptionEventModel(
        name: name,
        changedState: true,
        statePatches: false,
        previousState: false,
      );

  factory SubscriptionEventModel.patches(String name) => SubscriptionEventModel(
        name: name,
        statePatches: true,
        changedState: false,
        previousState: false,
      );

  /// Factory constructor for creating a new `SubscriptionEventModel`  instance
  factory SubscriptionEventModel.fromJson(Map<String, dynamic> json) => _$SubscriptionEventModelFromJson(json);

  final String? name;

  final bool? changedState;

  final bool? statePatches;

  final bool? previousState;

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SubscriptionEventModelToJson(this);

  @override
  List<Object?> get props => [
        name,
        changedState,
        statePatches,
        previousState,
      ];
}
