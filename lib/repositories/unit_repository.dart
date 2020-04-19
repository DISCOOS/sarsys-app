import 'package:SarSys/core/storage.dart';
import 'package:hive/hive.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/unit_service.dart';
import 'package:SarSys/core/extensions.dart';

class UnitRepository {
  UnitRepository(this.service, {this.compactWhen = 10});
  final UnitService service;
  final int compactWhen;

  Unit operator [](String uuid) => _box.get(uuid);

  int get length => _box.length;
  Map<String, Unit> get map => Map.unmodifiable(_box.toMap());
  Iterable<String> get keys => List.unmodifiable(_box.keys);
  Iterable<Unit> get values => List.unmodifiable(_box.values);

  bool containsKey(String uuid) => _box.keys.contains(uuid);
  bool containsValue(Unit unit) => _box.values.contains(unit);

  String _iuuid;
  String get iuuid => _iuuid;

  Box<Unit> _box;
  bool get isReady => _box?.isOpen == true && _box.containsKey(iuuid);
  void _assert() {
    if (!isReady) {
      throw '$UnitRepository is not ready';
    }
  }

  Future<Box<Unit>> _open(String iuuid) async {
    await _box?.compact();
    await _box?.close();
    _iuuid = iuuid;
    return Hive.openBox(
      '${UnitRepository}_$iuuid',
      encryptionKey: await Storage.hiveKey<Unit>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// Get [Unit] count
  int count({
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      exclude?.isNotEmpty == false ? _box.length : _box.values.where((unit) => !exclude.contains(unit.status)).length;

  /// Find unit from personnel
  Iterable<Unit> find(
    Personnel personnel, {
    List<UnitStatus> exclude: const [UnitStatus.Retired],
  }) =>
      values
          .where(
            (unit) => !exclude.contains(unit.status),
          )
          .where(
            (unit) => unit.personnel.contains(personnel),
          );

  /// Find and replace given [Personnel]
  Unit findAndReplace(Personnel personnel) {
    final unit = find(personnel, exclude: []).firstOrNull;
    if (unit != null) {
      final next = _findAndRemove(
        unit,
        personnel,
      );
      return unit.cloneWith(
        personnel: next..add(personnel),
      );
    }
    return unit;
  }

  /// Find and remove given [Personnel]
  Unit findAndRemove(Personnel personnel) {
    final unit = find(personnel, exclude: []).firstOrNull;
    if (unit != null) {
      return unit.cloneWith(
        personnel: _findAndRemove(
          unit,
          personnel,
        ),
      );
    }
    return unit;
  }

  List<Personnel> _findAndRemove(
    Unit unit,
    Personnel personnel,
  ) =>
      unit.personnel.toList()
        ..removeWhere(
          (next) => next.id == personnel.id,
        );

  /// Get next available [Unit.number]
  int nextAvailableNumber(bool reuse) {
    if (reuse) {
      var prev = 0;
      final numbers = values
          .where(
            (unit) => UnitStatus.Retired != unit.status,
          )
          .map((unit) => unit.number)
          .toList();
      numbers.sort((n1, n2) => n1.compareTo(n2));
      final candidates = numbers.takeWhile((next) => (next - prev++) == 1).toList();
      return (candidates.length == 0 ? numbers.length : candidates.last) + 1;
    }
    return count(exclude: []) + 1;
  }

  /// GET ../units
  Future<List<Unit>> load(String iuuid) async {
    var response = await service.load(iuuid);
    if (response.is200) {
      _iuuid = iuuid;
      _box = await _open(iuuid);
      await _box.putAll(
        Map.fromEntries(response.body.map(
          (unit) => MapEntry(unit.id, unit),
        )),
      );
      return response.body;
    }
    throw response;
  }

  /// POST ../units
  Future<Unit> create(String tuuid, Unit unit) async {
    _assert();
    var response = await service.create(tuuid, unit);
    if (response.is200) {
      return _put(
        unit,
      );
    }
    throw response;
  }

  /// PATCH ../units/{unitId}
  Future<Unit> update(Unit unit) async {
    _assert();
    var response = await service.update(unit);
    if (response.is204) {
      return _put(
        unit,
      );
    }
    throw response;
  }

  /// PUT ../units/{unitId}
  Future<Unit> patch(Unit unit) async {
    _assert();
    final old = this[unit.id];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, unit.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    var response = await service.update(Unit.fromJson(newJson));
    if (response.is204) {
      return _put(
        unit,
      );
    }
    throw response;
  }

  /// DELETE ../units/{unitId}
  Future<Unit> delete(Unit unit) async {
    _assert();
    var response = await service.delete(unit);
    if (response.is204) {
      // Any tracking is removed by listening to this event in TrackingBloc
      _box.delete(unit.id);
      return unit;
    }
    throw response;
  }

  Future<List<Unit>> unload() async {
    _assert();
    final units = values.toList();
    _box.delete(iuuid);
    return units;
  }

  Unit _put(Unit unit) {
    _box.put(unit.id, unit);
    return unit;
  }
}
