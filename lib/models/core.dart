import 'package:equatable/equatable.dart';
import 'package:json_patch/json_patch.dart';

abstract class JsonObject<T> extends Equatable {
  JsonObject(List fields) : super(fields);
  T toJson();
}

abstract class Aggregate<T> extends JsonObject<T> {
  Aggregate(this.uuid, {List fields = const []}) : super([uuid, ...fields]);
  final String uuid;
}

abstract class EntityObject<T> extends JsonObject<T> {
  EntityObject(this.id, {List fields = const []}) : super([id, ...fields]);
  final String id;
}

abstract class ValueObject<T> extends JsonObject<T> {
  ValueObject(List fields) : super(fields);
}

class JsonUtils {
  static List<Map<String, dynamic>> diff(JsonObject o1, JsonObject o2) {
    return JsonPatch.diff(o1.toJson(), o2.toJson());
  }

  static Map<String, dynamic> patch(JsonObject oldJson, JsonObject newJson) {
    final patches = JsonPatch.diff(oldJson.toJson(), newJson.toJson());
    return JsonPatch.apply(oldJson, patches, strict: false);
  }
}
