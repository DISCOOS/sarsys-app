import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/service.dart';
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
  static toNull(value) => null;

  static List<T> toList<T>(
    Map<String, dynamic> json,
    JsonDecoder<T> factory, {
    String dataField = 'data',
    String entriesField = 'entries',
  }) =>
      json.hasPath(entriesField)
          ? json.listAt(entriesField).map((json) => factory(Map.from(json).elementAt(dataField))).toList()
          : <T>[];

  static PagedList<T> toPagedList<T>(
    Map<String, dynamic> json,
    JsonDecoder<T> factory, {
    String dataField = 'data',
    String entriesField = 'entries',
  }) =>
      PagedList<T>(
        toList(
          json,
          factory,
          dataField: dataField,
          entriesField: entriesField,
        ),
        PageResult.from(json),
      );

  static dynamic toJson<T extends JsonObject>(
    T value, {
    List<String> retain = const [],
    List<String> remove = const [],
  }) {
    assert(
      !(retain?.isNotEmpty == true && remove?.isNotEmpty == true),
      'Only use retain or remove',
    );
    final json = value.toJson();
    if (retain?.isNotEmpty == true) {
      json.removeWhere(
        (key, _) => !retain.contains(key),
      );
    } else if (remove?.isNotEmpty == true) {
      json.removeWhere(
        (key, _) => remove.contains(key),
      );
    }
    return json;
  }

  /// Append-only operations allowed
  static const appendOnly = ['add', 'replace', 'move'];

  static List<Map<String, dynamic>> diff(
    JsonObject o1,
    JsonObject o2, {
    List<String> ops = appendOnly,
  }) {
    final patches = JsonPatch.diff(o1.toJson(), o2.toJson());
    patches.removeWhere((diff) => !ops.contains(diff['op']));
    return patches;
  }

  static Map<String, dynamic> patch(
    JsonObject oldJson,
    JsonObject newJson, {
    bool strict = false,
    List<String> ops = appendOnly,
  }) {
    final patches = diff(
      oldJson?.toJson() ?? {},
      newJson?.toJson() ?? {},
      ops: ops,
    );
    return apply(oldJson, patches, strict: strict);
  }

  static Map<String, dynamic> apply(
    JsonObject oldJson,
    List<Map<String, dynamic>> patches, {
    bool strict = false,
    List<String> ops = appendOnly,
  }) {
    return JsonPatch.apply(oldJson, patches, strict: strict);
  }
}
