import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:SarSys/models/AppConfig.dart';

import 'package:SarSys/models/AuthToken.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static int _typeId = 0;
  static bool _initialized = false;

  static bool get initialized => _initialized;

  static FlutterSecureStorage get secure => _storage;
  static FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future init() async {
    if (!_initialized) {
      if (!kIsWeb) {
        var appDir = await getApplicationDocumentsDirectory();
        // Initialize hive
        Hive.init(path_helper.join(appDir.absolute.path, 'hive'));
      }

      // DO NOT RE-ORDER THESE, only append! Hive expects typeId to be stable
      _registerStorageStateJsonAdapter<AppConfig>(
        fromJson: (data) => AppConfig.fromJson(data),
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
        fromJson: (data) => Incident.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Unit>(
        fromJson: (data) => Unit.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Personnel>(
        fromJson: (data) => Personnel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Device>(
        fromJson: (data) => Device.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Tracking>(
        fromJson: (data) => Tracking.fromJson(data),
        toJson: (data) => data.toJson(),
      );

      _initialized = true;
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

  static Future destroy() async {
    if (_initialized) {
      // Deletes only open boxes
      await Hive.deleteFromDisk();
      // Delete all remaining hive files
      var appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory(
        path_helper.join(appDir.absolute.path, 'hive'),
      );
      if (hiveDir.existsSync()) {
        await hiveDir.delete(recursive: true);
      }
      // Delete content in secure storage
      await _storage.deleteAll();
      // Delete all shared preferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.clear();
    }
    throw 'Storage not initialized';
  }
}

enum StorageStatus {
  local,
  remote,
  changed,
  deleted,
}

class StorageState<T> {
  StorageState({this.value, this.status});
  final T value;
  final StorageStatus status;

  factory StorageState.local(T value) => StorageState<T>(value: value, status: StorageStatus.local);
  factory StorageState.remote(T value) => StorageState<T>(value: value, status: StorageStatus.remote);
  factory StorageState.changed(T value) => StorageState<T>(value: value, status: StorageStatus.changed);
  factory StorageState.deleted(T value) => StorageState<T>(value: value, status: StorageStatus.deleted);

  get isLocal => StorageStatus.local == status;
  get isRemote => StorageStatus.remote == status;
  get isChanged => StorageStatus.changed == status;
  get isDeleted => StorageStatus.deleted == status;

  StorageState<T> replace(T value) {
    switch (status) {
      case StorageStatus.local:
        return StorageState.local(value);
      case StorageStatus.remote:
      case StorageStatus.changed:
      case StorageStatus.deleted:
        return StorageState.changed(value);
      default:
        throw StorageStateException('Unknown state $status');
    }
  }

  StorageState<T> delete() => StorageState.deleted(value);
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
    return fromJson(json as Map<String, dynamic>);
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
      value: json['value'] != null ? fromJson(json['value'] as Map<String, dynamic>) : null,
    );
  }

  StorageStatus _toStatus(String name) {
    return StorageStatus.values.firstWhere(
      (value) => enumName(value) == name,
      orElse: () => StorageStatus.local,
    );
  }

  @override
  void write(BinaryWriter writer, StorageState<T> state) {
    writer.writeMap({
      'state': enumName(state.status),
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
