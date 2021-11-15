

import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';

import 'callbacks.dart';
import 'error_handler.dart';

class PermissionController {
  PermissionController({
    required this.configBloc,
    this.onMessage,
    this.onPrompt,
  }) : assert(configBloc != null, "AppConfigBloc is required");

  static const String IOS = "ios";
  static const String ANDROID = "android";
  static const List<String> ALL_OS = const [ANDROID, IOS];

  static const List<Permission> REQUIRED = const [
    Permission.storage,
    Permission.locationWhenInUse,
    Permission.activityRecognition,
  ];

  final PromptCallback? onPrompt;
  final AppConfigBloc configBloc;
  final ActionCallback<PermissionRequest>? onMessage;

  bool _resolving = false;
  bool get resolving => _resolving;

  Set<Permission> _permissions = {};

  Stream<PermissionResponse> get responses => _responses.stream;
  StreamController<PermissionResponse> _responses = StreamController.broadcast();

  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _responses.close();
  }

  /// Clone with given parameters.
  ///
  /// Will copy resolving state and current permissions
  PermissionController cloneWith({
    PromptCallback? onPrompt,
    ActionCallback<PermissionRequest>? onMessage,
  }) =>
      PermissionController(
        configBloc: configBloc,
        onMessage: onMessage ?? this.onMessage,
        onPrompt: onPrompt ?? this.onPrompt,
      )
        .._resolving = _resolving
        .._permissions = _permissions;

  /// Get [Permission.storage] request
  PermissionRequest get storageRequest => PermissionRequest(
        platforms: [ANDROID],
        permission: Permission.storage,
        title: "Minnekort",
        rationale: "Du må akseptere tilgang for å lese kartdata fra minnekort.",
        disabledMessage: "Tilgang til minnekort er avslått.",
        deniedMessage: "Tilgang til minnekort er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått tilgang til minnekort.",
        consequence: "Du kan ikke lese kartdata lagret lokalt.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        update: (bool value) => _updateAppConfig(
          storage: value,
        ),
      );

  /// Get [Permission.location] request
  PermissionRequest get locationRequest => PermissionRequest(
        platforms: ALL_OS,
        permission: Permission.location,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er og lagre spor under aksjoner.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        update: (bool value) => _updateAppConfig(
          locationWhenInUse: value,
        ),
      );

  /// Get [Permission.locationWhenInUseRequest] request
  PermissionRequest get locationWhenInUseRequest => PermissionRequest(
        platforms: ALL_OS,
        permission: Permission.locationWhenInUse,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er og lagre spor under aksjoner.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        update: (bool value) => _updateAppConfig(
          locationWhenInUse: value,
        ),
      );

  /// Get [Permission.locationWhenInUseRequest] request
  PermissionRequest get locationAlwaysRequest => PermissionRequest(
        platforms: ALL_OS,
        permission: Permission.locationAlways,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er og lagre spor under aksjoner.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        update: (bool value) => _updateAppConfig(
          locationAlways: value,
        ),
      );

  /// Get [Permission.activityRecognition] request
  PermissionRequest get activityRecognitionRequest => PermissionRequest(
        platforms: [ANDROID],
        permission: Permission.activityRecognition,
        title: "Aktivitetsgjenkjenning",
        rationale: "Du må akseptere tilgang til aktivtetsgjenkjenning for at "
            "lokasjonstjenesten skal kunne spare batteri når appen ikke "
            "er i bevegelse.",
        disabledMessage: "Aktivitetsgjenkjenning er avslått.",
        deniedMessage: "Aktivitetsgjenkjenning er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått tilgang til aktivitetsgjenkjenning.",
        consequence: "Lokasjonstjenesten vil bruke mer batteri enn normalt.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        update: (bool value) => _updateAppConfig(
          activityRecognition: value,
        ),
      );

  void init({
    List<Permission> permissions = REQUIRED,
    VoidCallback? onReady,
  }) async {
    _permissions.addAll(permissions ?? REQUIRED);
    if (_permissions.contains(Permission.storage))
      await ask(
        storageRequest.copyWith(onReady: onReady),
      );
    if (_permissions.contains(Permission.locationWhenInUse))
      await ask(
        locationWhenInUseRequest.copyWith(onReady: onReady),
      );
  }

  Future<PermissionStatus> check(PermissionRequest request) async {
    return await request.permission.status;
  }

  Future<PermissionStatus> ask(PermissionRequest request) async {
    if (request.platforms.contains(Platform.operatingSystem)) {
      if (request.permission is PermissionWithService) {
        final permission = request.permission as PermissionWithService;
        final status = await permission.serviceStatus;
        switch (status) {
          case ServiceStatus.enabled:
            await handle(
              await request.permission.status,
              request,
            );
            break;
          case ServiceStatus.disabled:
            await _handleServiceDisabled(request);
            break;
          case ServiceStatus.notApplicable:
            if (onMessage != null)
              onMessage!(
                "${request.title} er ikke tilgjengelig. ${request.consequence}",
                data: request,
              );
            break;
          default:
            break;
        }
      } else {
        await handle(
          await request.permission.status,
          request,
        );
      }
    }
    return check(request);
  }

  Future<bool> handle(PermissionStatus status, PermissionRequest request) async {
    // Prevent re-entrant loop
    _resolving = true;

    var isReady = false;

    if (request.platforms.contains(Platform.operatingSystem)) {
      switch (status) {
        case PermissionStatus.granted:
          if (await request.update(true) && onMessage != null)
            onMessage!(
              "${request.title} er tilgjengelig",
              data: request,
            );
          isReady = true;
          break;
        case PermissionStatus.restricted:
          if (await request.update(false) && onMessage != null)
            onMessage!(
              "Tilgang til ${toBeginningOfSentenceCase(request.title)} tillates ikke",
              data: request,
            );
          isReady = true;
          break;
        case PermissionStatus.denied:
          await _handleServiceDenied(request);
          break;
        default:
          // Check if permission has a service that could be disabled
          if (request.permission is PermissionWithService) {
            final permission = request.permission as PermissionWithService;
            final serviceStatus = await permission.serviceStatus;
            if (serviceStatus.isDisabled) {
              await _handleServiceDenied(request);
            }
          }
          await _handlePermissionRequest(
            "${request.title} er ikke tilgjengelig. ${request.consequence}",
            request,
          );
          break;
      }
      if (isReady && request.onReady != null) request.onReady!();
    }
    _resolving = false;

    // Notify listeners?
    if (!_disposed) {
      _responses.add(
        PermissionResponse(request, status),
      );
    }
    return isReady;
  }

  Future<bool> _updateAppConfig({
    bool? storage,
    bool? locationAlways,
    bool? locationWhenInUse,
    bool? activityRecognition,
  }) async {
    var notify = false;
    if (configBloc.isReady) {
      final config = configBloc.config;
      notify = config.storage != (storage ?? config.storage) ||
          config.locationAlways != (locationAlways ?? config.locationAlways) ||
          config.locationWhenInUse != (locationWhenInUse ?? config.locationWhenInUse) ||
          config.activityRecognition != (activityRecognition ?? config.activityRecognition);
      if (notify) {
        await configBloc.updateWith(
          storage: storage,
          locationAlways: locationAlways,
          locationWhenInUse: locationWhenInUse,
          activityRecognition: activityRecognition,
        );
      }
    }
    return notify;
  }

  Future _handlePermissionRequest(String reason, PermissionRequest request) async {
    if (onMessage == null)
      await _onAction(request);
    else
      onMessage!(reason, action: "LØS", data: request, onPressed: () async {
        await _onAction(request);
      });
  }

  Future _onAction(PermissionRequest request) async {
    var prompt = true;

    final prefs = await SharedPreferences.getInstance();
    final status = await request.permission.status;
    if (status.isPermanentlyDenied) {
      await _onOpenSetting(request);
    } else if ([PermissionStatus.denied, PermissionStatus.restricted].contains(status)) {
      var deniedBefore = prefs.getInt("userDeniedGroupBefore_${request.permission}") ?? 0;
      // Only supported on Android, iOS always return false
      if (deniedBefore > 0 || await request.permission.shouldShowRequestRationale) {
        prompt = onPrompt == null
            ? true
            : await onPrompt!(
                request.title,
                _toRationale(
                  request,
                  deniedBefore > 0,
                ));
      }
      if (prompt) {
        if (deniedBefore < 2) {
          await _request(request, prefs, deniedBefore);
        } else {
          // In case permissions was granted in app settings screen
          var status = await request.permission.status;
          if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
            await prefs.setInt("userDeniedGroupBefore_${request.permission}", 0);
            handle(status, request);
          } else {
            await _onOpenSetting(request);
          }
        }
      }
    }
  }

  Future _request(
    PermissionRequest request,
    SharedPreferences prefs,
    int deniedBefore,
  ) async {
    try {
      final status = await request.permission.request();
      if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
        await prefs.setInt("userDeniedGroupBefore_${request.permission}", 0);
        handle(status, request);
      } else {
        await prefs.setInt("userDeniedGroupBefore_${request.permission}", ++deniedBefore);
        if (onMessage != null) {
          onMessage!(
            "${request.title} er ikke tilgjengelig. ${request.consequence}",
            data: request,
          );
        }
      }
    } on PlatformException catch (e, stackTrace) {
      // TODO: Implement request queue for sequential processing
      if (e.code != 'ERROR_ALREADY_REQUESTING_PERMISSIONS') {
        SarSysApp.reportCheckedError(e, stackTrace);
      }
    }
  }

  String _toRationale(PermissionRequest request, bool deniedBefore) {
    var rationale = request.rationale;
    if (deniedBefore) rationale = "${request.deniedBefore} $rationale";
    return rationale;
  }

  Future _handleServiceDenied(PermissionRequest request) async {
    if (request.permission is PermissionWithService) {
      final permission = request.permission as PermissionWithService;
      var check = await permission.serviceStatus;
      if (check == ServiceStatus.disabled) {
        return await _handleServiceDisabled(request);
      }
    }
    await _handlePermissionRequest(request.deniedMessage, request);
  }

  Future _handleServiceDisabled(PermissionRequest request) async {
    if (onMessage == null)
      await _onOpenSetting(request);
    else
      onMessage!(request.disabledMessage, action: "LØS", data: request, onPressed: () async {
        await _onOpenSetting(request);
      });
  }

  Future _onOpenSetting(PermissionRequest request) async {
    // Will only work on Android. For iOS, this plugin only opens the app setting screen Settings application,
    // as using url schemes to open inner setting path is a violation of Apple's regulations. Using url scheme
    // to open settings can also leads to possible App Store rejection.
    switch (request.settingTarget) {
      case PermissionRequest.SETTINGS_LOCATION:
        await AppSettings.openLocationSettings();
        break;
      case PermissionRequest.SETTINGS_APPLICATION:
        await AppSettings.openAppSettings();
        break;
    }
    await handle(
      await request.permission.status,
      request,
    );
  }
}

class PermissionResponse {
  PermissionResponse(this.request, this.status);
  final PermissionRequest request;
  final PermissionStatus status;
}

class PermissionRequest {
  static const String SETTINGS_LOCATION = 'location';
  static const String SETTINGS_APPLICATION = 'application';

  final String title;
  final String rationale;
  final String deniedBefore;
  final Permission permission;
  final String deniedMessage;
  final String disabledMessage;
  final String consequence;
  final Future<bool> Function(bool value) update;

  final VoidCallback? onReady;
  final String? settingTarget;

  final List<String> platforms;

  PermissionRequest({
    required this.platforms,
    required this.title,
    required this.rationale,
    required this.consequence,
    required this.deniedBefore,
    required this.permission,
    required this.update,
    required this.deniedMessage,
    required this.disabledMessage,
    this.onReady,
    this.settingTarget,
  });

  PermissionRequest copyWith({
    VoidCallback? onReady,
  }) {
    return PermissionRequest(
      title: this.title,
      update: this.update,
      platforms: this.platforms,
      rationale: this.rationale,
      permission: this.permission,
      consequence: this.consequence,
      deniedBefore: this.deniedBefore,
      onReady: onReady ?? this.onReady,
      deniedMessage: this.deniedMessage,
      settingTarget: this.settingTarget,
      disabledMessage: this.disabledMessage,
    );
  }
}
