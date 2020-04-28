import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

import 'core.dart';

part 'Author.g.dart';

@JsonSerializable()
class Author extends ValueObject {
  final String userId;
  final DateTime timestamp;

  Author({
    @required this.userId,
    @required this.timestamp,
  }) : super([
          userId,
          timestamp,
        ]);

  /// Factory constructor for `Author` with timestamp now
  factory Author.now(String userId) {
    return Author(
      userId: userId,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for creating a new `Author` instance
  factory Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);

  /// Declare support for serialization to JSON
  Map<String, dynamic> toJson() => _$AuthorToJson(this);
}
