import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import 'package:SarSys/mock/user_service_mock.dart';
import 'package:SarSys/features/operation/domain/entities/Author.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/core/data/services/service.dart';

const PASSCODE = 'T123';

class OperationBuilder {
  static Operation create(
    String userId, {
    int since = 0,
    String ouuid,
    String iuuid,
    String passcode = PASSCODE,
  }) {
    return OperationModel.fromJson(
      createOperationAsJson(
        ouuid: ouuid ?? Uuid().v4(),
        iuuid: iuuid ?? Uuid().v4(),
        since: since,
        userId: userId,
        passcode: passcode,
      ),
    );
  }

  static Map<String, dynamic> createOperationAsJson({
    int since,
    String iuuid,
    String ouuid,
    String userId,
    String passcode,
  }) {
    final rnd = math.Random();
    return json.decode(
      '{'
      '"uuid": "$ouuid",'
      '"type": "search",'
      '"status": "planned",'
      '"name": "Savnet person",'
      '"resolution": "unresolved",'
      '"incident": {"uuid": "$iuuid"},'
      '"reference": "2019-RKH-245$since",'
      '"justification": "Mann, 32 år, økt selvmordsfare.",'
      '"ipp": ${createLocationAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
      '"meetup": ${createLocationAsJson(59.5 + rnd.nextDouble() * 0.01, 10.09 + rnd.nextDouble() * 0.01)},'
      '"talkgroups": ['
      '{"name": "RK-RIKS-1", "type": "tetra"}'
      '],'
      '"passcodes": ${createPasscodesAsJson(passcode)},'
      '"author": ${createAuthor(userId)}'
      '}',
    );
  }

  static createLocationAsJson(double lat, double lon) {
    return json.encode(Location(
      point: Point.fromCoords(
        lat: lat,
        lon: lon,
      ),
    ).toJson());
  }

  static createRandomPasscodesAsJson() {
    return json.encode(Passcodes.random(6).toJson());
  }

  static createPasscodesAsJson(String passcode) {
    return json.encode(Passcodes(commander: passcode, personnel: passcode).toJson());
  }

  static createAuthor(String userId) => json.encode(Author.now(userId));
}

class OperationServiceMock extends Mock implements OperationService {
  static final Map<String, Operation> _operations = {};

  Operation add(
    String userId, {
    int since = 0,
    String uuid,
    String passcode = PASSCODE,
  }) {
    final operation = OperationBuilder.create(
      userId,
      ouuid: uuid,
      since: since,
      passcode: passcode,
    );
    _operations[operation.uuid] = operation;
    return operation;
  }

  Operation remove(uuid) {
    return _operations.remove(uuid);
  }

  OperationServiceMock reset() {
    _operations.clear();
    return this;
  }

  static MapEntry<String, Operation> _buildEntry(
    String uuid,
    int since,
    User user,
    String passcode,
  ) =>
      MapEntry(
        uuid,
        OperationModel.fromJson(
          OperationBuilder.createOperationAsJson(
            ouuid: uuid,
            since: since,
            userId: user.userId,
            passcode: passcode,
          ),
        ),
      );

  static OperationService build(
    UserRepository users, {
    @required final UserRole role,
    @required final String passcode,
    List<String> iuuids = const [],
    final int count = 0,
  }) {
    _operations.clear();
    final user = users.user;
    final OperationServiceMock mock = OperationServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized", role).toUser();

    // Only generate operations for automatically generated incidents
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        _operations.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i, user, passcode),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i, unauthorized, passcode)
        ]);
      }
    });

    when(mock.fetchAll()).thenAnswer((_) async {
      final authorized = await users.load();
      if (authorized == null) {
        return ServiceResponse.unauthorized();
      }
      if (_operations.isEmpty) {
        var user = await users.load();
        _operations.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i, user, passcode),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i, unauthorized, passcode)
        ]);
      }
      return ServiceResponse.ok(body: _operations.values.toList(growable: false));
    });
    when(mock.create(any)).thenAnswer((_) async {
      final authorized = await users.load();
      if (authorized == null) {
        return ServiceResponse.unauthorized();
      }
      final Operation operation = _.positionalArguments[0];
      final created = OperationModel(
        uuid: operation.uuid,
        name: operation.name,
        type: operation.type,
        passcodes: Passcodes(
          commander: passcode,
          personnel: passcode,
        ),
        ipp: operation.ipp,
        author: operation.author,
        meetup: operation.meetup,
        status: operation.status,
        incident: operation.incident,
        reference: operation.reference,
        commander: operation.commander,
        talkgroups: operation.talkgroups,
        resolution: operation.resolution,
        justification: operation.justification,
      );
      _operations.putIfAbsent(created.uuid, () => created);
      return ServiceResponse.created();
    });
    when(mock.update(any)).thenAnswer((_) async {
      var operation = _.positionalArguments[0];
      if (_operations.containsKey(operation.uuid)) {
        _operations.update(
          operation.uuid,
          (_) => operation,
          ifAbsent: () => operation,
        );
        return ServiceResponse.ok(body: operation);
      }
      return ServiceResponse.notFound(message: "Not found. Operation ${operation.uuid}");
    });
    when(mock.delete(any)).thenAnswer((_) async {
      var uuid = _.positionalArguments[0];
      if (_operations.containsKey(uuid)) {
        _operations.remove(uuid);
        return ServiceResponse.noContent();
      }
      return ServiceResponse.notFound(message: "Not found. Operation $uuid");
    });
    return mock;
  }
}
