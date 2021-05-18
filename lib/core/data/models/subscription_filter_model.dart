import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';

part 'subscription_filter_model.g.dart';

@JsonSerializable(explicitToJson: true)
class SubscriptionFilterModel extends Equatable {
  const SubscriptionFilterModel({
    @required this.pattern,
  }) : super();

  /// Factory constructor for creating a new `SubscriptionFilterModel`  instance
  factory SubscriptionFilterModel.fromJson(Map<String, dynamic> json) => _$SubscriptionFilterModelFromJson(json);

  final String pattern;

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$SubscriptionFilterModelToJson(this);

  @override
  List<Object> get props => [pattern];
}
