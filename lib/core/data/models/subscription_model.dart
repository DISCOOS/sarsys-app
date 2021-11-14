

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'subscription_type_model.dart';

part 'subscription_model.g.dart';

@JsonSerializable(explicitToJson: true)
class SubscriptionModel extends Equatable {
  const SubscriptionModel({
    this.maxCount = defaultCount,
    this.minPeriod = defaultPeriod,
    List<SubscriptionTypeModel>? types = const <SubscriptionTypeModel>[],
  })  : types = types ?? const <SubscriptionTypeModel>[],
        super();

  /// Factory constructor for creating a new `SubscriptionModel`  instance
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => _$SubscriptionModelFromJson(json);

  static const int defaultCount = 100;
  static const Duration defaultPeriod = Duration(seconds: 1);
  static const SubscriptionModel defaultModel = SubscriptionModel();

  /// Maximum number of changes to cache before pushing to apps
  final int? maxCount;

  /// Minimum number of seconds between pushing changes to apps
  final Duration? minPeriod;

  /// List of subscription types that defines which changes to subscribe to
  final List<SubscriptionTypeModel> types;

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SubscriptionModelToJson(this);

  @override
  List<Object?> get props => [
        types,
        maxCount,
        minPeriod,
      ];
}
