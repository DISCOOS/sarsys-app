

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';

import 'subscription_event_model.dart';
import 'subscription_filter_model.dart';

part 'subscription_type_model.g.dart';

@JsonSerializable(explicitToJson: true)
class SubscriptionTypeModel extends Equatable {
  const SubscriptionTypeModel({
    required this.name,
    this.statePatches,
    this.changedState,
    this.previousState,
    FilterMatch match = FilterMatch.any,
    List<SubscriptionEventModel>? events = const <SubscriptionEventModel>[],
    List<SubscriptionFilterModel>? filters = const <SubscriptionFilterModel>[],
  })  : match = match,
        events = events ?? const <SubscriptionEventModel>[],
        filters = filters ?? const <SubscriptionFilterModel>[],
        super();

  /// Factory constructor for creating a new `SubscriptionTypeModel`  instance
  factory SubscriptionTypeModel.fromJson(Map<String, dynamic> json) => _$SubscriptionTypeModelFromJson(json);

  final String? name;

  @JsonKey(defaultValue: FilterMatch.any)
  final FilterMatch match;

  final List<SubscriptionEventModel> events;

  final List<SubscriptionFilterModel> filters;

  final bool? changedState;

  final bool? statePatches;

  final bool? previousState;

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SubscriptionTypeModelToJson(this);

  @override
  List<Object?> get props => [
        name,
        events,
        filters,
        changedState,
        statePatches,
        previousState,
      ];
}

enum FilterMatch {
  any,
  all,
}
