extension MapX on Map {
  /// Check if map contains data at given path
  bool hasPath(String ref) => elementAt(ref) != null;

  /// Get element with given reference on format '/name1/name2/name3'
  /// equivalent to map['name1']['name2']['name3'].
  ///
  /// Returns [null] if not found
  T elementAt<T>(String path) {
    final parts = path.split('/');
    dynamic found = parts.skip(parts.first.isEmpty ? 1 : 0).fold(this, (parent, name) {
      if (parent is Map<String, dynamic>) {
        if (parent.containsKey(name)) {
          return parent[name];
        }
      }
      final element = (parent ?? {});
      return element is Map ? element[name] : element is List && element.isNotEmpty ? element[int.parse(name)] : null;
    });
    return found as T;
  }

  /// Get [List] of type [T] at given path
  List<T> listAt<T>(String path) {
    final list = elementAt(path);
    return list == null ? null : List<T>.from(list);
  }

  /// Get [Map] with keys of type [S] and values of type [T] at given path
  Map<S, T> mapAt<S, T>(String path) {
    final map = elementAt(path);
    return map == null ? null : Map<S, T>.from(map);
  }
}

extension IterableX<T> on Iterable<T> {
  T get firstOrNull => this.isNotEmpty ? this.first : null;
}
