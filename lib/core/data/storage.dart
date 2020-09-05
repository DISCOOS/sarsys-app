import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/page_state.dart';
import 'package:SarSys/features/affiliation/data/models/affiliation_model.dart';
import 'package:SarSys/features/affiliation/data/models/department_model.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Department.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';
import 'package:SarSys/features/device/data/models/device_model.dart';
import 'package:SarSys/features/operation/data/models/incident_model.dart';
import 'package:SarSys/features/operation/data/models/operation_model.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/personnel/data/models/personnel_model.dart';
import 'package:SarSys/features/tracking/data/models/tracking_model.dart';
import 'package:SarSys/features/unit/data/models/unit_model.dart';

import 'package:SarSys/features/user/domain/entities/AuthToken.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/operation/domain/entities/Incident.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:catcher/catcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

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
      _registerStorageStateJsonAdapter<Person>(
        fromJson: (data) => PersonModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Affiliation>(
        fromJson: (data) => AffiliationModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Organisation>(
        fromJson: (data) => OrganisationModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Division>(
        fromJson: (data) => DivisionModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Department>(
        fromJson: (data) => DepartmentModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Incident>(
        fromJson: (data) => IncidentModel.fromJson(data),
        toJson: (data) => data.toJson(),
      );
      _registerStorageStateJsonAdapter<Operation>(
        fromJson: (data) => OperationModel.fromJson(data),
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
        fromJson: (data) => TrackingModel.fromJson(data),
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
    @required bool isRemote,
    this.error,
  }) : _isRemote = isRemote;
  final T value;
  final bool _isRemote;
  final Object error;
  final StorageStatus status;

  bool get isLocal => !_isRemote;
  bool get isRemote => _isRemote;

  factory StorageState.created(T value, {bool isRemote = false, Object error}) => StorageState<T>(
        value: value,
        status: StorageStatus.created,
        isRemote: isRemote,
        error: error,
      );
  factory StorageState.updated(T value, {bool isRemote = false, Object error}) => StorageState<T>(
        value: value,
        status: StorageStatus.updated,
        isRemote: isRemote,
        error: error,
      );
  factory StorageState.deleted(T value, {bool isRemote = false, Object error}) => StorageState<T>(
        value: value,
        status: StorageStatus.deleted,
        isRemote: isRemote,
        error: error,
      );

  bool get isError => error != null;
  bool get isConflict => error is ConflictModel;

  bool get isCreated => StorageStatus.created == status;
  bool get isChanged => StorageStatus.updated == status;
  bool get isDeleted => StorageStatus.deleted == status;

  bool get shouldLoad => !(isCreated && isLocal);

  ConflictModel get conflict => isConflict ? error as ConflictModel : null;

  StorageState<T> failed(Object error) => StorageState<T>(
        value: value,
        status: status,
        isRemote: _isRemote,
        error: error,
      );

  StorageState<T> remote(T value) => StorageState<T>(
        value: value,
        status: status,
        isRemote: true,
        error: null,
      );

  StorageState<T> apply(T value, {@required bool isRemote, Object error}) {
    switch (status) {
      case StorageStatus.created:
        return StorageState(
          value: value,
          error: error ?? this.error,
          isRemote: isRemote ?? _isRemote,
          status: _isRemote
              // If current is remote,
              // value MUST HAVE status
              // 'updated'
              ? StorageStatus.updated
              // If current is local,
              // value SHOULD not
              // change stats
              : status,
        );
      default:
        return replace(value, isRemote: isRemote);
    }
  }

  StorageState<T> replace(T value, {bool isRemote}) {
    switch (status) {
      case StorageStatus.created:
        return StorageState.created(value, isRemote: isRemote ?? _isRemote, error: error);
      case StorageStatus.updated:
        return StorageState.updated(value, isRemote: isRemote ?? _isRemote, error: error);
      case StorageStatus.deleted:
        return StorageState.deleted(value, isRemote: isRemote ?? _isRemote, error: error);
      default:
        throw StorageStateException('Unknown state $status');
    }
  }

  StorageState<T> delete() => StorageState.deleted(value);

  @override
  String toString() {
    return '$runtimeType {status: $status, isRemote: $_isRemote, value: ${_toValueAsString()}}';
  }

  String _toValueAsString() => '${value?.runtimeType} ${value is Aggregate ? '{${(value as Aggregate).uuid}}' : ''}';
}

class StorageTransition<T> {
  StorageTransition({this.from, this.to});
  final StorageState<T> from;
  final StorageState<T> to;

  bool get isError => to?.isError ?? false;
  bool get isLocal => to?.isLocal ?? false;
  bool get isRemote => to?.isRemote ?? false;
  bool get isChanged => to?.isChanged ?? false;
  bool get isDeleted => to?.isDeleted ?? false;
  bool get isConflict => to?.isConflict ?? false;

  ConflictModel get conflict => isConflict ? to.error as ConflictModel : null;
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
    var value;
    var error;
    var json = reader.readMap();
    try {
      value = json['value'] != null ? fromJson(Map<String, dynamic>.from(json['value'])) : null;
    } on ArgumentError catch (e, stackTrace) {
      error = e;
      Catcher.reportCheckedError(error, stackTrace);
    } on Exception catch (e, stackTrace) {
      error = e;
      Catcher.reportCheckedError(error, stackTrace);
    }
    return StorageState(
      value: value,
      status: _toStatus(json['status'] as String),
      error: error ?? (json['error'] != null ? json['error'] : null),
      isRemote: json['remote'] != null ? json['remote'] as bool : false,
    );
  }

  StorageStatus _toStatus(String name) {
    final status = StorageStatus.values.firstWhere(
      (value) => enumName(value) == name,
      orElse: () => StorageStatus.created,
    );
    return status;
  }

  @override
  void write(BinaryWriter writer, StorageState<T> state) {
    var value;
    try {
      value = state.value != null ? toJson(state.value) : null;
    } on ArgumentError catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      Catcher.reportCheckedError(error, stackTrace);
    }
    writer.writeMap({
      'value': value,
      'status': enumName(state.status),
      'error': state.isError ? '${state.error}' : null,
      'remote': state?._isRemote != null ? state._isRemote : null,
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
