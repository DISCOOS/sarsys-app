extension StringX on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }

  String capitalizeAll() {
    return "${this.split(' ').map((s) => s.capitalize()).join(' ')}";
  }
}

extension MapX on Map {
  /// Check if map contains data at given path
  bool hasPath(String ref) => elementAt(ref) != null;

  /// Get element with given reference on format '/name1/name2/name3'
  /// equivalent to map['name1']['name2']['name3'].
  ///
  /// Returns [null] if not found
  T elementAt<T>(String path, {T defaultValue}) {
    final parts = path.split('/');
    dynamic found = parts.skip(parts.first.isEmpty ? 1 : 0).fold(this, (parent, name) {
      if (parent is Map<String, dynamic>) {
        if (parent.containsKey(name)) {
          return parent[name];
        }
      }
      final element = (parent ?? {});
      return element is Map
          ? element[name]
          : element is List && element.isNotEmpty
              ? element[int.parse(name)]
              : defaultValue;
    });
    return (found ?? defaultValue) as T;
  }

  /// Get [List] of type [T] at given path
  List<T> listAt<T>(String path, {List<T> defaultList}) {
    final list = elementAt(path);
    return list == null ? defaultList : List<T>.from(list);
  }

  /// Get [Map] with keys of type [S] and values of type [T] at given path
  Map<S, T> mapAt<S, T>(String path, {Map<S, T> defaultMap}) {
    final map = elementAt(path);
    return map == null ? defaultMap : Map<S, T>.from(map);
  }
}

extension IterableX<T> on Iterable<T> {
  T get firstOrNull => this.isNotEmpty ? this.first : null;
  Iterable<T> whereNotNull([dynamic map(T element)]) =>
      where((element) => map == null ? element != null : map(element) != null);

  Iterable<T> toPage({int offset = 0, int limit = 20}) {
    if (offset < 0 || limit < 0) {
      throw ArgumentError('Offset and limit can not be negative');
    } else if (offset > length) {
      throw ArgumentError('Index out of bounds: offset $offset > length $length');
    } else if (offset == 0 && limit == 0) {
      return toList();
    }
    return skip(offset).take(limit);
  }
}
