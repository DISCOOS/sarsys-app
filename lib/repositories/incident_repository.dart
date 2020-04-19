import 'package:SarSys/core/storage.dart';
import 'package:SarSys/services/service.dart';
import 'package:hive/hive.dart';
import 'package:json_patch/json_patch.dart';

import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/services/incident_service.dart';

class IncidentRepository {
  IncidentRepository(this.service, {this.compactWhen = 10});
  final IncidentService service;
  final int compactWhen;

  Incident operator [](String uuid) => _box.get(uuid);

  int get length => _box.length;
  Map<String, Incident> get map => Map.unmodifiable(_box.toMap());
  Iterable<String> get keys => List.unmodifiable(_box.keys);
  Iterable<Incident> get values => List.unmodifiable(_box.values);

  bool containsKey(String uuid) => _box.keys.contains(uuid);
  bool containsValue(Incident incident) => _box.values.contains(incident);

  Box<Incident> _box;
  bool get isReady => _box?.isOpen == true;

  Future<Box<Incident>> _open() async => Hive.openBox(
        '$IncidentRepository',
        encryptionKey: await Storage.hiveKey<Incident>(),
        compactionStrategy: (_, deleted) => compactWhen < deleted,
      );

  Future _prepare() async => _box ??= await _open();

  /// GET ../incidents
  Future<List<Incident>> load() async {
    await _prepare();
    var response = await service.load();
    if (response.is200) {
      await _box.putAll(
        Map.fromEntries(response.body.map(
          (incident) => MapEntry(incident.uuid, incident),
        )),
      );
      return response.body;
    }
    throw IncidentServiceException(
      'Failed to load incidents',
      response: response,
    );
  }

  /// POST ../incidents
  Future<Incident> create(Incident incident) async {
    await _prepare();
    var response = await service.create(incident);
    if (response.is200) {
      return _put(
        incident,
      );
    }
    throw IncidentServiceException(
      'Failed to create incident $incident',
      response: response,
    );
  }

  /// PATCH ../incidents/{incidentId}
  Future<Incident> update(Incident incident) async {
    await _prepare();
    var response = await service.update(incident);
    if (response.is204) {
      return _put(
        incident,
      );
    }
    // TODO: Handle 409 Conflict for Incident
    throw IncidentServiceException(
      'Failed to update incident $incident',
      response: response,
    );
  }

  /// PUT ../incidents/{incidentId}
  Future<Incident> patch(Incident incident) async {
    await _prepare();
    final old = this[incident.uuid];
    final oldJson = old?.toJson() ?? {};
    final patches = JsonPatch.diff(oldJson, incident.toJson());
    final newJson = JsonPatch.apply(old, patches, strict: false);
    return await update(Incident.fromJson(newJson));
  }

  /// DELETE ../incidents/{incidentId}
  Future<Incident> delete(String uuid) async {
    await _prepare();
    final incident = _box.get(uuid);
    if (incident == null) {
      throw IncidentNotFoundException(uuid);
    }
    var response = await service.delete(uuid);
    if (response.is204) {
      // Any tracking is removed by listening to this event in TrackingBloc
      await _box.delete(uuid);
      return incident;
    }
    throw IncidentServiceException(
      'Failed to delete incident $uuid',
      response: response,
    );
  }

  /// Clear incidents from local cache
  Future<List<Incident>> clear() async {
    await _prepare();
    final incidents = values.toList();
    await _box.clear();
    return incidents;
  }

  Future<Incident> _put(Incident incident) async {
    await _box.put(incident.uuid, incident);
    return incident;
  }
}

class IncidentNotFoundException implements Exception {
  IncidentNotFoundException(this.uuid);
  final String uuid;

  @override
  String toString() {
    return 'Incident $uuid not found';
  }
}

class IncidentServiceException implements Exception {
  IncidentServiceException(this.error, {this.response, this.stackTrace});
  final Object error;
  final StackTrace stackTrace;
  final ServiceResponse response;

  @override
  String toString() {
    return 'IncidentServiceException: $error, response: $response, stackTrace: $stackTrace';
  }
}
