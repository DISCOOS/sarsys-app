

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:SarSys/core/data/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'package:SarSys/features/operation/domain/entities/Passcodes.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/data/services/operation_service.dart';
import '../mock/user_service_mock.dart';
import 'package:SarSys/features/operation/domain/entities/Author.dart';
import 'package:SarSys/core/domain/models/Location.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/domain/repositories/user_repository.dart';
import 'package:SarSys/core/data/services/service.dart';

const PASSCODE = 'T123';

class OperationBuilder {
  static Operation create(
    String? userId, {
    int since = 0,
    String? ouuid,
    String? iuuid,
    String passcode = PASSCODE,
  }) {
    return OperationModel.fromJson(
      createOperationAsJson(
        ouuid: ouuid ?? Uuid().v4(),
        iuuid: iuuid ?? Uuid().v4(),
        since: since,
        userId: userId,
        passcode: passcode,
      )!,
    );
  }

  static Map<String, dynamic>? createOperationAsJson({
    int? since,
    String? iuuid,
    String? ouuid,
    String? userId,
    String? passcode,
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

  static createPasscodesAsJson(String? passcode) {
    return json.encode(Passcodes(commander: passcode, personnel: passcode).toJson());
  }

  static createAuthor(String? userId) => json.encode(Author.now(userId));
}

class OperationServiceMock extends Mock implements OperationService {
  static final Map<String?, StorageState<Operation>> _operationRepo = {};

  Operation add(
    String? userId, {
    int since = 0,
    String? iuuid,
    String? ouuid,
    String passcode = PASSCODE,
  }) {
    final operation = OperationBuilder.create(
      userId,
      iuuid: iuuid,
      ouuid: ouuid,
      since: since,
      passcode: passcode,
    );
    final state = StorageState.created(
      operation,
      StateVersion.first,
      isRemote: true,
    );
    _operationRepo[operation.uuid] = state;
    return operation;
  }

  StorageState<Operation>? remove(uuid) {
    return _operationRepo.remove(uuid);
  }

  OperationServiceMock reset() {
    _operationRepo.clear();
    return this;
  }

  static MapEntry<String, StorageState<Operation>> _buildEntry(
    String uuid,
    int since,
    User user,
    String passcode,
  ) =>
      MapEntry(
        uuid,
        StorageState.created(
          OperationModel.fromJson(
            OperationBuilder.createOperationAsJson(
              ouuid: uuid,
              since: since,
              userId: user.userId,
              passcode: passcode,
            )!,
          ),
          StateVersion.first,
          isRemote: true,
        ),
      );

  static OperationService build(
    UserRepository users, {
    required final UserRole role,
    required final String passcode,
    List<String> iuuids = const [],
    final int count = 0,
  }) {
    _operationRepo.clear();
    final user = users.user;
    final OperationServiceMock mock = OperationServiceMock();
    final unauthorized = UserServiceMock.createToken("unauthorized", role).toUser();
    final StreamController<OperationMessage> controller = StreamController.broadcast();

    // Only generate operations for automatically generated incidents
    iuuids.forEach((iuuid) {
      if (iuuid.startsWith('a:')) {
        _operationRepo.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i, user, passcode),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i, unauthorized, passcode)
        ]);
      }
    });

    when(mock.getList()).thenAnswer((_) async {
      final user = await users.load();
      if (user == null) {
        return ServiceResponse.unauthorized();
      }
      if (_operationRepo.isEmpty) {
        var user = await users.load();
        _operationRepo.addEntries([
          for (var i = 1; i <= count ~/ 2; i++) _buildEntry("a:x$i", i, user, passcode),
          for (var i = count ~/ 2 + 1; i <= count; i++) _buildEntry("a:y$i", i, unauthorized, passcode)
        ]);
      }
      return ServiceResponse.ok(
        body: _operationRepo.values.toList(growable: false),
      );
    });

    // Mock websocket stream
    when(mock.messages).thenAnswer((_) => controller.stream);

    when(mock.create(any!)).thenAnswer((_) async {
      final user = await users.load();
      if (user == null) {
        return ServiceResponse.unauthorized();
      }
      final state = _.positionalArguments[0] as StorageState<Operation>;
      if (!state.version!.isFirst) {
        return ServiceResponse.badRequest(
          message: "Aggregate has not version 0: $state",
        );
      }
      final uuid = state.value.uuid;
      final Operation operation = state.value;
      final created = OperationModel(
        uuid: uuid,
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
      _operationRepo[uuid] = state.remote(
        created,
        version: state.version,
      );
      return ServiceResponse.ok(
        body: _operationRepo[uuid],
      );
    });

    when(mock.update(any!)).thenAnswer((_) async {
      final next = _.positionalArguments[0] as StorageState<Operation>;
      final uuid = next.value.uuid;
      if (_operationRepo.containsKey(uuid)) {
        final state = _operationRepo[uuid]!;
        final delta = next.version!.value! - state.version!.value!;
        if (delta != 1) {
          return ServiceResponse.badRequest(
            message: "Wrong version: expected ${state.version! + 1}, actual was ${next.version}",
          );
        }
        _operationRepo[uuid] = state.apply(
          next.value,
          replace: false,
          isRemote: true,
        );
        return ServiceResponse.ok(
          body: _operationRepo[uuid],
        );
      }
      return ServiceResponse.notFound(
        message: "Operation not found: $uuid",
      );
    });

    when(mock.delete(any!)).thenAnswer((_) async {
      final state = _.positionalArguments[0] as StorageState<Operation>;
      final uuid = state.value.uuid;
      if (_operationRepo.containsKey(uuid)) {
        return ServiceResponse.ok(
          body: _operationRepo.remove(uuid),
        );
      }
      return ServiceResponse.notFound(
        message: "Operation not found: $uuid",
      );
    });
    return mock;
  }
}
