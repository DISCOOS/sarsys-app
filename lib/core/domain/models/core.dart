import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:equatable/equatable.dart';
import 'package:json_patch/json_patch.dart';

abstract class JsonObject<T> extends Equatable {
  JsonObject(List fields) : _props = [...fields];
  T toJson();

  final List<Object> _props;

  @override
  List<Object> get props => _props;
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
  }) {
    final isRoot = dataField == null || dataField == '.';
    if (json.hasPath(entriesField)) {
      return json
          .listAt(entriesField)
          .map((json) => factory(isRoot ? json : Map.from(json).elementAt(dataField)))
          .toList();
    }
    return <T>[];
  }

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

  /// Calculate key-stable patches enforcing
  /// a 'append-only' rule for keys and
  /// replace-only for arrays (remove are
  /// only allowed for arrays).
  ///
  /// This is important to allow for partial
  /// updates to an existing object that is
  /// semantically consistent with the HTTP
  /// PATCH method by only including keys
  /// in [next] should be updated, keeping
  /// the rest unchanged.
  ///
  static List<Map<String, dynamic>> diff(JsonObject o1, JsonObject o2) {
    final current = o1.toJson();
    final next = o2.toJson();
    final patches = JsonPatch.diff(current, next)
      ..removeWhere(
        (diff) {
          var isRemove = diff['op'] == 'remove';
          if (isRemove) {
            final elements = (diff['path'] as String).split('/');
            if (elements.length > 1) {
              // Get path to list by removing index
              final path = elements.take(elements.length - 1).join('/');
              if (current is Map && path.isNotEmpty) {
                final value = current.elementAt(path);
                isRemove = value is! List;
              }
            }
          }
          return isRemove;
        },
      );
    return patches;
  }

  static Map<String, dynamic> patch(
    JsonObject oldJson,
    JsonObject newJson, {
    bool strict = false,
  }) {
    final patches = diff(
      oldJson?.toJson() ?? {},
      newJson?.toJson() ?? {},
    );
    return apply(oldJson, patches, strict: strict);
  }

  static Map<String, dynamic> apply(
    JsonObject oldJson,
    List<Map<String, dynamic>> patches, {
    bool strict = false,
  }) {
    return JsonPatch.apply(oldJson, patches, strict: strict);
  }
}
