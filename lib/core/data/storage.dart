

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_helper;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:SarSys/core/data/models/conflict_model.dart';
import 'package:SarSys/core/extensions.dart';
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

class Storage {
  static const CURRENT_USER_ID_KEY = 'current_user_id';

  static int _typeId = 0;
  static bool _initialized = false;

  static bool get initialized => _initialized;

  static FlutterSecureStorage get secure => _storage;
  static FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> readUserId() => secure.read(key: CURRENT_USER_ID_KEY);
  static Future<void> writeUserId(String? userId) => Storage.secure.write(
        key: CURRENT_USER_ID_KEY,
        value: userId,
      );
  static Future<void> deleteUserId() => Storage.secure.delete(
        key: CURRENT_USER_ID_KEY,
      );

  static String? userKey(User user, String? suffix) => user == null ? suffix : '${user.userId}_$suffix';

  static Future<String> readUserValue(
    User user, {
    String? suffix,
    String? defaultValue,
  }) =>
      _storage.read(key: userKey(user, suffix)!).then((value) => value!) ?? defaultValue as Future<String>;

  static Future<void> writeUserValue(
    User user, {
    String? suffix,
    String? value,
  }) =>
      _storage.write(key: userKey(user, suffix)!, value: value);

  static Future<void> deleteUserValue(
    User user, {
    String? suffix,
    String? defaultValue,
  }) =>
      _storage.delete(key: userKey(user, suffix)!);

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
        toJson: (data) => data!.toJson(),
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
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Affiliation>(
        fromJson: (data) => AffiliationModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Organisation>(
        fromJson: (data) => OrganisationModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Division>(
        fromJson: (data) => DivisionModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Department>(
        fromJson: (data) => DepartmentModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Incident>(
        fromJson: (data) => IncidentModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Operation>(
        fromJson: (data) => OperationModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Unit>(
        fromJson: (data) => UnitModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Personnel>(
        fromJson: (data) => PersonnelModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Device>(
        fromJson: (data) => DeviceModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
      _registerStorageStateJsonAdapter<Tracking>(
        fromJson: (data) => TrackingModel.fromJson(data),
        toJson: (data) => data!.toJson(),
      );
    }
  }

  static void _registerTypeJsonAdapter<T>({
    Map<String, dynamic> Function(T data)? toJson,
    T Function(Map<String, dynamic> data)? fromJson,
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
    Map<String, dynamic> Function(T? data)? toJson,
    T Function(Map<String, dynamic> data)? fromJson,
  }) {
    Hive.registerAdapter(
      StorageStateJsonAdapter<T>(
        typeId: ++_typeId,
        fromJson: fromJson,
        toJson: toJson,
      ),
    );
  }

  static Future<HiveAesCipher> hiveCipher<T>() async {
    if (_initialized) {
      final type = typeOf<T>();
      final data = await _storage.read(key: '$type.key');
      if (data == null) {
        final key = Hive.generateSecureKey();
        await _storage.write(
          key: '$type.key',
          value: base64UrlEncode(key),
        );
        return HiveAesCipher(key);
      }
      final encryptedKey = base64Url.decode(data);
      return HiveAesCipher(encryptedKey);
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
    required this.value,
    required this.status,
    required this.version,
    required bool? isRemote,
    this.previous,
    this.error,
  }) : _isRemote = isRemote;
  final T value;
  final T? previous;
  final bool? _isRemote;
  final Object? error;
  final StateVersion? version;
  final StorageStatus status;

  bool get isLocal => !_isRemote!;
  bool? get isRemote => _isRemote;

  factory StorageState.created(
    T value,
    StateVersion? version, {
    bool? isRemote = false,
    T? previous,
    Object? error,
  }) =>
      StorageState<T>(
        value: value,
        error: error,
        version: version,
        previous: previous,
        isRemote: isRemote,
        status: StorageStatus.created,
      );

  factory StorageState.updated(
    T value,
    StateVersion? version, {
    bool? isRemote = false,
    T? previous,
    Object? error,
  }) =>
      StorageState<T>(
        value: value,
        error: error,
        version: version,
        previous: previous,
        isRemote: isRemote,
        status: StorageStatus.updated,
      );

  factory StorageState.deleted(
    T value,
    StateVersion? version, {
    bool? isRemote = false,
    T? previous,
    Object? error,
  }) =>
      StorageState<T>(
        value: value,
        error: error,
        version: version,
        previous: previous,
        isRemote: isRemote,
        status: StorageStatus.deleted,
      );

  bool get isError => error != null;
  bool get isConflict => error is ConflictModel;

  bool get isCreated => StorageStatus.created == status;
  bool get isChanged => StorageStatus.updated == status;
  bool get isDeleted => StorageStatus.deleted == status;

  bool get hasValue => value != null;
  bool get hasPrevious => previous != null;
  bool get shouldLoad => !(isCreated && isLocal);

  ConflictModel? get conflict => isConflict ? error as ConflictModel? : null;

  StorageState<T> failed(Object error) => StorageState<T>(
        error: error,
        value: value,
        status: status,
        version: version,
        previous: previous,
        isRemote: _isRemote,
      );

  StorageState<T> remote(
    T value, {
    StorageStatus? status,
    StateVersion? version,
  }) =>
      StorageState<T>(
        value: value,
        error: null,
        isRemote: true,
        previous: previous,
        status: status ?? this.status,
        version: version ?? this.version! + 1,
      );

  StorageState<T> apply(
    T value, {
    required bool replace,
    required bool? isRemote,
    T? previous,
    Object? error,
    StateVersion? version,
  }) {
    if (isCreated && !replace) {
      final next = _isRemote!
          // If current is remote,
          // value MUST HAVE status
          // 'updated'
          ? StorageStatus.updated
          // If current is local,
          // value SHOULD not
          // change stats
          : status;
      return StorageState(
        value: value,
        status: next,
        error: error,
        isRemote: isRemote ?? _isRemote,
        previous: previous ?? this.value,
        // Only increment if state is remote, or if remote is forced
        version: version ?? (isRemote! || !_isRemote! ? this.version : this.version! + 1),
      );
    }
    return this.replace(
      value,
      version: version,
      isRemote: isRemote,
      previous: previous,
    );
  }

  /// Patch [next] state with existing
  /// [value]. Returns [StorageState] with
  /// patched [value] is [value] is an
  /// [JsonObject], otherwise [next].
  StorageState<V> patch<V extends JsonObject?>(StorageState<V> next, V fromJson(Map<String, dynamic>? json)) {
    if (value is JsonObject) {
      final patches = JsonUtils.diff(value as JsonObject, next.value!);
      if (patches.isNotEmpty) {
        next = apply(
          fromJson(
            JsonUtils.apply(
              value as JsonObject,
              patches,
            ),
          ) as T,
          replace: false,
          error: next.error,
          version: next.version,
          isRemote: next.isRemote,
        ) as StorageState<V>;
      } else {
        // Vale not changed, use current
        next = apply(
          next.value as T,
          replace: false,
          error: next.error,
          isRemote: next.isRemote,
        ) as StorageState<V>;
      }
    }

    return next;
  }

  StorageState<T> replace(
    T value, {
    T? previous,
    bool? isRemote,
    StateVersion? version,
  }) {
    switch (status) {
      case StorageStatus.created:
        return StorageState.created(
          value,
          version ?? this.version,
          error: error,
          isRemote: isRemote ?? _isRemote,
          previous: previous ?? this.value,
        );
      case StorageStatus.updated:
        return StorageState.updated(
          value,
          version ?? this.version,
          error: error,
          isRemote: isRemote ?? _isRemote,
          previous: previous ?? this.value,
        );
      case StorageStatus.deleted:
        return StorageState.deleted(
          value,
          version ?? this.version,
          error: error,
          isRemote: isRemote ?? _isRemote,
          previous: previous ?? this.value,
        );
      default:
        throw StorageStateException('Unknown state $status');
    }
  }

  StorageState<T> delete(
    StateVersion version, {
    bool isRemote = false,
    Object? error,
  }) =>
      StorageState.deleted(
        value,
        version,
        error: error,
        isRemote: isRemote ?? _isRemote,
      );

  @override
  String toString() {
    return '$runtimeType {'
        'status: $status, '
        'isRemote: $_isRemote, '
        'value: ${_toValueAsString(value)}, '
        'previous: ${_toValueAsString(previous)}'
        '}';
  }

  String _toValueAsString(T? value) => '${value?.runtimeType} ${value is Aggregate ? '{${value.uuid}}' : ''}';
}

class StorageTransition<T> {
  StorageTransition({this.from, this.to});
  final StorageState<T>? from;
  final StorageState<T>? to;

  StorageStatus? get status => to?.status;
  StateVersion? get version => to?.version;

  bool get isError => to?.isError ?? false;
  bool get isLocal => to?.isLocal ?? false;
  bool get isRemote => to?.isRemote ?? false;
  bool get isCreated => to?.isCreated ?? false;
  bool get isChanged => to?.isChanged ?? false;
  bool get isDeleted => to?.isDeleted ?? false;
  bool get isConflict => to?.isConflict ?? false;
  bool get hasPrevious => to?.hasPrevious ?? false;

  ConflictModel? get conflict => isConflict ? to!.error as ConflictModel? : null;
}

class TypeJsonAdapter<T> extends TypeAdapter<T> {
  TypeJsonAdapter({
    required this.typeId,
    this.toJson,
    this.fromJson,
  });

  @override
  final int typeId;

  final Map<String, dynamic> Function(T value)? toJson;
  final T Function(Map<String, dynamic> value)? fromJson;

  @override
  T read(BinaryReader reader) {
    var json = reader.readMap();
    return fromJson!(Map<String, dynamic>.from(json));
  }

  @override
  void write(BinaryWriter writer, T value) {
    writer.writeMap(toJson!(value));
  }
}

class StorageStateJsonAdapter<T> extends TypeAdapter<StorageState<T?>> {
  StorageStateJsonAdapter({
    required this.typeId,
    this.toJson,
    this.fromJson,
  });

  @override
  final int typeId;

  final Map<String, dynamic> Function(T? value)? toJson;
  final T Function(Map<String, dynamic> value)? fromJson;

  @override
  StorageState<T?> read(BinaryReader reader) {
    var value;
    var error;
    var version;
    var previous;
    var json = reader.readMap();
    try {
      value = _toValue(json, 'value');
      previous = _toValue(json, 'previous');
      version = StateVersion(json.elementAt<int>(
        'version',
        defaultValue: StateVersion.none.value,
      ));
    } on ArgumentError catch (e, stackTrace) {
      error = e;
      SarSysApp.reportCheckedError(error, stackTrace);
    } on Exception catch (e, stackTrace) {
      error = e;
      SarSysApp.reportCheckedError(error, stackTrace);
    }
    return StorageState(
      value: value,
      version: version,
      previous: previous,
      status: _toStatus(json['status'] as String?),
      error: error ?? (json['error'] != null ? json['error'] : null),
      isRemote: json['remote'] != null ? json['remote'] as bool? : false,
    );
  }

  T? _toValue(Map json, String key) => json[key] != null ? fromJson!(Map<String, dynamic>.from(json[key])) : null;

  StorageStatus _toStatus(String? name) {
    final status = StorageStatus.values.firstWhere(
      (value) => enumName(value) == name,
      orElse: () => StorageStatus.created,
    );
    return status;
  }

  @override
  void write(BinaryWriter writer, StorageState<T?> state) {
    var value;
    var previous;
    try {
      value = state.hasValue ? toJson!(state.value) : null;
      previous = state.hasPrevious ? toJson!(state.previous) : null;
    } on ArgumentError catch (error, stackTrace) {
      SarSysApp.reportCheckedError(error, stackTrace);
    } on Exception catch (error, stackTrace) {
      SarSysApp.reportCheckedError(error, stackTrace);
    }
    writer.writeMap({
      'value': value,
      'previous': previous,
      'version': state.version!.value,
      'status': enumName(state.status),
      'error': toError(state),
      'remote': state?._isRemote != null ? state._isRemote : null,
    });
  }

  dynamic toError(StorageState state) {
    if (!state.isError) {
      return null;
    }
    final object = state.error;
    if (object is ServiceException) {
      return object.response!.error;
    }
    if (object is Map) {
      return object['error'];
    }
    return '$object';
  }
}

/// Event number in stream
class StateVersion {
  const StateVersion(this.value);

  factory StateVersion.fromJson(Map<String, dynamic> json) => StateVersion(
        json.elementAt<int>(
          'number',
          defaultValue: StateVersion.none.value,
        ),
      );

  // First event in stream
  static const first = StateVersion(0);

  // Empty stream
  static const none = StateVersion(-1);

  // Last event in stream
  static const last = StateVersion(-2);

  /// Test if event number is NONE
  bool get isNone => this == none;

  /// Test if first event number in stream
  bool get isFirst => this == first;

  /// Test if last event number in stream
  bool get isLast => this == last;

  /// Event number value
  final int? value;

  StateVersion operator +(int number) => StateVersion(value! + number);
  StateVersion operator -(int number) => StateVersion(value! - number);
  bool operator >(StateVersion number) => value! > number.value!;
  bool operator <(StateVersion number) => value! < number.value!;
  bool operator >=(StateVersion number) => value! >= number.value!;
  bool operator <=(StateVersion number) => value! <= number.value!;

  @override
  String toString() {
    return (isLast ? 'HEAD' : value).toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StateVersion && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class StorageStateException implements Exception {
  StorageStateException(this.error, {this.state, this.stackTrace});
  final Object error;
  final StorageState? state;
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'StorageStateException: $error, state: $state, stackTrace: $stackTrace}';
  }
}
