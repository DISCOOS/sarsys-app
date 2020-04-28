import 'package:equatable/equatable.dart';

abstract class Aggregate extends Equatable {
  Aggregate(this.uuid) : super([uuid]);
  final String uuid;
}

abstract class EntityObject extends Equatable {
  EntityObject(this.id) : super([id]);
  final String id;
}

abstract class ValueObject extends Equatable {
  ValueObject(List fields) : super(fields);
}
