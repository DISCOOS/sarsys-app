import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:SarSys/features/app_config/data/models/app_config_model.dart';
import 'package:SarSys/features/app_config/domain/entities/AppConfig.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/incident/data/models/incident_model.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/incident/domain/entities/Incident.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/models/core.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

import 'page_state.dart';

class Storage {
  static const CURRENT_USER_ID_KEY = 'current_user_id';

  static int _typeId = 0;
  static bool _initialized = false;

  static bool get initialized => _initialized;

  static FlutterSecureStorage get secure => _storage;
  static FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String> readUserId() => secure.read(key: CURRENT_USER_ID_KEY);
  static Future<void> writeUserId(String userId) => Storage.secure.write(
        key: CURRENT_USER_ID_KEY,
        value: userId,
      );
  static Future<void> deleteUserId() => Storage.secure.delete(
        key: CURRENT_USER_ID_KEY,
      );

  static String userKey(User user, String suffix) => '${user.userId}_$suffix';

  static Future<String> readUserValue(
    User user, {
    String suffix,
    String defaultValue,
  }) =>
      _storage.read(key: userKey(user, suffix)) ?? defaultValue;

  static Future<void> writeUserValue(
    User user, {
    String suffix,
    String value,
  }) =>
      _storage.write(key: userKey(user, suffix), value: value);

  static Future<void> deleteUserValue(
    User user, {
    String suffix,
    String defaultValue,
  }) =>
      _storage.delete(key: userKey(user, suffix));

  static Future init() async {
    if (!_initialized) {
      if (!kIsWeb) {
        var appDir = await getApplicationDocumentsDirectory();
        var hiveDir = Directory(path_helper.join(appDir.path, 'hive'));
        hiveDir.createSync();
        // Initialize hive
        Hive.init(hiveDir.path);
      }

      _register();

      _initialized = true;
    }
    return Future.value();
  }

  static void _register() {
    if (_typeId == 0) {
      // DO NOT RE-ORDER THESE, only append! Hive expects typeId to be stable
      _registerStorageStateJsonAdapter<AppConfig>(
        fromJson: (data) => AppConfigModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerTypeJsonAdapter<AuthToken>(
        fromJson: (data) => AuthToken.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerTypeJsonAdapter<User>(
        fromJson: (data) => User.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Incident>(
        fromJson: (data) => IncidentModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Unit>(
        fromJson: (data) => UnitModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Personnel>(
        fromJson: (data) => PersonnelModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Device>(
        fromJson: (data) => DeviceModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Tracking>(
        fromJson: (data) => Tracking.fromJson(data),
        toJson: (data) => data.toJson(),
      );
    }
  }

  static void _registerTypeJsonAdapter<T>({
    Map<String, dynamic> Function(T data) toJson,
    T Function(Map<String, dynamic> data) fromJson,
  }) {
    Hive.registerAdapter(
      TypeJsonAdapter<T>(
        typeId: ++_typeId,
        fromJson: fromJson,
        toJson: toJson,
      ),
    );
  }

  static void _registerStorageStateJsonAdapter<T>({
    Map<String, dynamic> Function(T data) toJson,
    T Function(Map<String, dynamic> data) fromJson,
  }) {
    Hive.registerAdapter(
      StorageStateJsonAdapter<T>(
        typeId: ++_typeId,
        fromJson: fromJson,
        toJson: toJson,
      ),
    );
  }

  static Future<List<int>> hiveKey<T>() async {
    if (_initialized) {
      final type = typeOf<T>();
      final data = await _storage.read(key: '$type.key');
      if (data == null) {
        final key = Hive.generateSecureKey();
        await _storage.write(
          key: '$type.key',
          value: jsonEncode(key),
        );
        return key;
      }
      return List<int>.from(jsonDecode(data));
    }
    throw 'Storage not initialized';
  }

  static Future destroy({bool reinitialize = false, bool keepFiles = false}) async {
    _initialized = false;
    try {
      // Deletes only open boxes
      await Hive.deleteFromDisk();
    } on Exception catch (e) {
      // Don't fail on this
      print(e);
    }

    if (!(keepFiles || kIsWeb)) {
      // Delete all remaining hive files
      var appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory(
        path_helper.join(appDir.absolute.path, 'hive'),
      );
      if (hiveDir.existsSync()) {
        hiveDir.deleteSync(recursive: true);
      }
    }

    // Delete content in secure storage
    await _storage.deleteAll();

    // Delete all page states
    await clearPageStates();

    // Delete all shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return reinitialize ? init() : Future.value();
  }
}

enum StorageStatus {
  created,
  updated,
  deleted,
}

class StorageState<T> {
  StorageState({
    @required this.value,
    @required this.status,
    @required bool remote,
  }) : _remote = remote;
  final T value;
  final bool _remote;
  final StorageStatus status;

  bool get isLocal => !_remote;
  bool get isRemote => _remote;

  factory StorageState.created(T value, {bool remote = false}) => StorageState<T>(
        value: value,
        status: StorageStatus.created,
        remote: remote,
      );
  factory StorageState.updated(T value, {bool remote = false}) => StorageState<T>(
        value: value,
        status: StorageStatus.updated,
        remote: remote,
      );
  factory StorageState.deleted(T value, {bool remote = false}) => StorageState<T>(
        value: value,
        status: StorageStatus.deleted,
        remote: remote,
      );

  bool get isCreated => StorageStatus.created == status;
  bool get isChanged => StorageStatus.updated == status;
  bool get isDeleted => StorageStatus.deleted == status;

  StorageState<T> remote(T value) => StorageState<T>(value: value, status: status, remote: true);

  StorageState<T> replace(T value, {bool remote}) {
    switch (status) {
      case StorageStatus.created:
        return StorageState.created(value, remote: remote ?? _remote);
      case StorageStatus.updated:
        return StorageState.updated(value, remote: remote ?? _remote);
      case StorageStatus.deleted:
        return StorageState.deleted(value, remote: remote ?? _remote);
      default:
        throw StorageStateException('Unknown state $status');
    }
  }

  StorageState<T> delete() => StorageState.deleted(value);

  @override
  String toString() {
    return '$runtimeType {value: ${_toValueAsString()}, remote: $_remote, status: $status}';
  }

  String _toValueAsString() => '${value?.runtimeType} ${value is Aggregate ? '{${(value as Aggregate).uuid}}' : ''}';
}

class StorageTransition<T> {
  StorageTransition({this.from, this.to});
  final StorageState<T> from;
  final StorageState<T> to;
}

class TypeJsonAdapter<T> extends TypeAdapter<T> {
  TypeJsonAdapter({
    this.typeId,
    this.toJson,
    this.fromJson,
  });

  @override
  final typeId;

  final Map<String, dynamic> Function(T value) toJson;
  final T Function(Map<String, dynamic> value) fromJson;

  @override
  T read(BinaryReader reader) {
    var json = reader.readMap();
    return fromJson(Map<String, dynamic>.from(json));
  }

  @override
  void write(BinaryWriter writer, T value) {
    writer.writeMap(value != null ? toJson(value) : null);
  }
}

class StorageStateJsonAdapter<T> extends TypeAdapter<StorageState<T>> {
  StorageStateJsonAdapter({
    this.typeId,
    this.toJson,
    this.fromJson,
  });

  @override
  final typeId;

  final Map<String, dynamic> Function(T value) toJson;
  final T Function(Map<String, dynamic> value) fromJson;

  @override
  StorageState<T> read(BinaryReader reader) {
    var json = reader.readMap();
    return StorageState(
      status: _toStatus(json['status'] as String),
      remote: json['remote'] != null ? json['remote'] as bool : false,
      value: json['value'] != null ? fromJson(Map<String, dynamic>.from(json['value'])) : null,
    );
  }

  StorageStatus _toStatus(String name) {
    return StorageStatus.values.firstWhere(
      (value) => enumName(value) == name,
      orElse: () => StorageStatus.created,
    );
  }

  @override
  void write(BinaryWriter writer, StorageState<T> state) {
    writer.writeMap({
      'state': enumName(state.status),
      'remote': state?._remote != null ? state._remote : null,
      'value': state.value != null ? toJson(state.value) : null,
    });
  }
}

class StorageStateException implements Exception {
  StorageStateException(this.error, {this.state, this.stackTrace});
  final Object error;
  final StorageState state;
  final StackTrace stackTrace;

  @override
  String toString() {
    return 'StorageStateException: $error, state: $state, stackTrace: $stackTrace}';
  }
}
