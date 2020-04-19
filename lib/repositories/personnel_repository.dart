import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/personnel_service.dart';
import 'package:hive/hive.dart';
import 'package:json_patch/json_patch.dart';

class PersonnelRepository {
  PersonnelRepository(this.service, {this.compactWhen = 10});
  final PersonnelService service;
  final int compactWhen;

  Personnel operator [](String uuid) => _box.get(uuid);

  int get length => _box.length;
  Map<String, Personnel> get map => Map.unmodifiable(_box.toMap());
  Iterable<String> get keys => List.unmodifiable(_box.keys);
  Iterable<Personnel> get values => List.unmodifiable(_box.values);

  bool containsKey(String uuid) => _box.keys.contains(uuid);
  bool containsValue(Personnel personnel) => _box.values.contains(personnel);

  String _iuuid;
  String get iuuid => _iuuid;

  Box<Personnel> _box;
  bool get isReady => _box?.isOpen == true && _box.containsKey(iuuid);
  void _assert() {
    if (!isReady) {
      throw '$PersonnelRepository is not ready';
    }
  }

  Future<Box<Personnel>> _open(String iuuid) async {
    await _box?.compact();
    await _box?.close();
    _iuuid = iuuid;
    return Hive.openBox(
      '${PersonnelRepository}_$iuuid',
      encryptionKey: await Storage.hiveKey<Personnel>(),
      compactionStrategy: (_, deleted) => compactWhen < deleted,
    );
  }

  /// Get [Personnel] count
  int count({
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      exclude?.isNotEmpty == false
          ? _box.length
          : _box.values.where((personnel) => !exclude.contains(personnel.status)).length;

  /// Find personnel from user
  List<Personnel> find(
    User user, {
    List<PersonnelStatus> exclude: const [PersonnelStatus.Retired],
  }) =>
      values
          .where((personnel) => !exclude.contains(personnel.status))
          .where((personnel) => personnel.userId == user.userId);

  /// GET ../personnels
  Future<List<Personnel>> load(String iuuid) async {
    var response = await service.load(iuuid);
    if (response.is200) {
      _box = await _open(iuuid);
      await _box.putAll(Map.fromEntries(response.body.map(
        (personnel) => MapEntry(personnel.id, personnel),
      )));
      return response.body;
    }
    throw response;
  }

  /// POST ../personnels
  Future<Personnel> create(String tuuid, Personnel personnel) async {
    _assert();
    var response = await service.create(tuuid, personnel);
    if (response.is200) {
      return _put(
        personnel,
      );
    }
    throw response;
  }

  /// PATCH ../personnels/{personnelId}
  Future<Personnel> update(Personnel personnel) async {
    _assert();
    var response = await service.update(personnel);
    if (response.is204) {
      return _put(
        personnel,
      );
    }
    throw response;
  }

  /// PUT ../personnels/{personnelId}
  Future<Personnel> patch(Personnel personnel) async {
    _assert();
    final old = this[personnel.id];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, personnel.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    var response = await service.update(Personnel.fromJson(newJson));
    if (response.is204) {
      return _put(
        personnel,
      );
    }
    throw response;
  }

  /// DELETE ../personnels/{personnelId}
  Future<Personnel> delete(Personnel personnel) async {
    _assert();
    var response = await service.delete(personnel);
    if (response.is204) {
      // Any tracking is removed by listening to this event in TrackingBloc
      _box.delete(personnel.id);
      return personnel;
    }
    throw response;
  }

  Future<List<Personnel>> unload() async {
    _assert();
    final personnels = values.toList();
    _box.delete(iuuid);
    return personnels;
  }

  Personnel _put(Personnel personnel) {
    _box.put(personnel.id, personnel);
    return personnel;
  }
}
