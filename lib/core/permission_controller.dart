import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:catcher/catcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/utils/ui.dart';

class PermissionController {
  PermissionController({
    @required this.configBloc,
    this.onMessage,
    this.onPrompt,
  }) : assert(configBloc != null, "AppConfigBloc is required");

  static const String IOS = "ios";
  static const String ANDROID = "android";
  static const List<String> ALL_OS = const [ANDROID, IOS];

  static const List<PermissionGroup> REQUIRED = const [
    PermissionGroup.storage,
    PermissionGroup.locationWhenInUse,
  ];

  final PromptCallback onPrompt;
  final AppConfigBloc configBloc;
  final ActionCallback<PermissionRequest> onMessage;

  bool _resolving = false;
  bool get resolving => _resolving;

  Set<PermissionGroup> _permissions = {};

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
    PromptCallback onPrompt,
    ActionCallback<PermissionRequest> onMessage,
  }) =>
      PermissionController(
        configBloc: configBloc,
        onMessage: onMessage ?? this.onMessage,
        onPrompt: onPrompt ?? this.onPrompt,
      )
        .._resolving = _resolving
        .._permissions = _permissions;

  /// Get [PermissionGroup.storage] request
  PermissionRequest get storageRequest => PermissionRequest(
        platforms: [ANDROID],
        group: PermissionGroup.storage,
        title: "Minnekort",
        rationale: "Du må akseptere tilgang for å lese kartdata fra minnekort.",
        disabledMessage: "Tilgang til minnekort er avslått.",
        deniedMessage: "Tilgang til minnekort er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått tilgang til minnekort.",
        consequence: "Du kan ikke lese kartdata lagret lokalt.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        onCheck: () => _updateAppConfig(
          storage: true,
        ),
      );

  /// Get [PermissionGroup.locationWhenInUseRequest] request
  PermissionRequest get locationWhenInUseRequest => PermissionRequest(
        platforms: ALL_OS,
        group: PermissionGroup.locationWhenInUse,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er og lagre spor under aksjoner.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        onCheck: () => _updateAppConfig(
          locationWhenInUse: true,
        ),
      );

  /// Get [PermissionGroup.locationWhenInUseRequest] request
  PermissionRequest get locationAlwaysRequest => PermissionRequest(
        platforms: ALL_OS,
        group: PermissionGroup.locationAlways,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er og lagre spor under aksjoner.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: PermissionRequest.SETTINGS_APPLICATION,
        onCheck: () => _updateAppConfig(
          locationWhenInUse: true,
        ),
      );

  void init({
    List<PermissionGroup> permissions = REQUIRED,
    VoidCallback onReady,
  }) async {
    _permissions.addAll(permissions ?? REQUIRED);
    if (_permissions.contains(PermissionGroup.storage))
      await ask(
        storageRequest.copyWith(onReady: onReady),
      );
    if (_permissions.contains(PermissionGroup.locationWhenInUse))
      await ask(
        locationWhenInUseRequest.copyWith(onReady: onReady),
      );
  }

  Future<PermissionStatus> check(PermissionRequest request) async {
    final handler = PermissionHandler();
    return await handler.checkPermissionStatus(request.group);
  }

  Future<PermissionStatus> ask(PermissionRequest request) async {
    if (request.platforms.contains(Platform.operatingSystem)) {
      final handler = PermissionHandler();
      final status = await handler.checkServiceStatus(request.group);
      switch (status) {
        case ServiceStatus.enabled:
        case ServiceStatus.notApplicable:
          await handle(
            await handler.checkPermissionStatus(request.group),
            request,
          );
          break;
        case ServiceStatus.disabled:
          await _handleServiceDisabled(request);
          break;
        case ServiceStatus.unknown:
          if (onMessage != null)
            onMessage(
              "${request.title} er ikke tilgjengelig. ${request.consequence}",
              data: request,
            );
          break;
        default:
          break;
      }
    }
    return check(request);
  }

  Future<bool> handle(PermissionStatus status, PermissionRequest request) async {
    var isReady = false;

    // Prevent re-entrant loop
    _resolving = true;

    if (request.platforms.contains(Platform.operatingSystem)) {
      switch (status) {
        case PermissionStatus.granted:
          if (await _updateAppConfig(locationWhenInUse: true) && onMessage != null)
            onMessage(
              "${request.title} er tilgjengelig",
              data: request,
            );
          isReady = true;
          break;
        case PermissionStatus.restricted:
          if (await _updateAppConfig(locationWhenInUse: true) && onMessage != null)
            onMessage(
              "Tilgang til ${toBeginningOfSentenceCase(request.title)} tillates ikke",
              data: request,
            );
          isReady = true;
          break;
        case PermissionStatus.denied:
          await _handleServiceDenied(request);
          break;
        case PermissionStatus.disabled:
          await _handleServiceDenied(request);
          break;
        default:
          await _handlePermissionRequest("${request.title} er ikke tilgjengelig. ${request.consequence}", request);
          break;
      }
      if (isReady && request.onReady != null) request.onReady();
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
    bool storage,
    bool locationWhenInUse,
  }) async {
    var notify = true;
    if (configBloc.isReady) {
      final config = configBloc.config;
      notify = config.locationWhenInUse != locationWhenInUse;
      if (notify) {
        await configBloc.updateWith(locationWhenInUse: locationWhenInUse);
      }
    }
    return notify;
  }

  Future _handlePermissionRequest(String reason, PermissionRequest request) async {
    final handler = PermissionHandler();
    if (onMessage == null)
      await _onAction(handler, request);
    else
      onMessage(reason, action: "LØS", data: request, onPressed: () async {
        await _onAction(handler, request);
      });
  }

  Future _onAction(PermissionHandler handler, PermissionRequest request) async {
    var prompt = true;

    /// TODO: Move userDeniedGroupBefore counter to AppConfig
    final prefs = await SharedPreferences.getInstance();
    var status = await handler.checkPermissionStatus(request.group);
    // In case permissions was granted in app settings screen
    if ([PermissionStatus.denied, PermissionStatus.restricted].contains(status)) {
      var deniedBefore = prefs.getInt("userDeniedGroupBefore_${request.group}") ?? 0;
      // Only supported on Android, iOS always return false
      if (deniedBefore > 0 || await handler.shouldShowRequestPermissionRationale(request.group)) {
        prompt = onPrompt == null
            ? true
            : await onPrompt(
                request.title,
                _toRationale(
                  request,
                  deniedBefore > 0,
                ));
      }
      if (prompt) {
        if (deniedBefore < 2) {
          await _request(handler, request, prefs, deniedBefore);
        } else {
          // In case permissions was granted in app settings screen
          var status = await handler.checkPermissionStatus(request.group);
          if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
            await prefs.setInt("userDeniedGroupBefore_${request.group}", 0);
            handle(status, request);
          } else {
            await _onOpenSetting(request);
          }
        }
      }
    }
  }

  Future _request(
      PermissionHandler handler, PermissionRequest request, SharedPreferences prefs, int deniedBefore) async {
    try {
      var response = await handler.requestPermissions([request.group]);
      var status = response[request.group];
      if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
        await prefs.setInt("userDeniedGroupBefore_${request.group}", 0);
        handle(status, request);
      } else {
        await prefs.setInt("userDeniedGroupBefore_${request.group}", ++deniedBefore);
        if (onMessage != null) {
          onMessage(
            "${request.title} er ikke tilgjengelig. ${request.consequence}",
            data: request,
          );
        }
      }
    } on PlatformException catch (e, stackTrace) {
      // TODO: Implement request queue for sequential processing
      if (e.code != 'ERROR_ALREADY_REQUESTING_PERMISSIONS') {
        Catcher.reportCheckedError(e, stackTrace);
      }
    }
  }

  String _toRationale(PermissionRequest request, bool deniedBefore) {
    var rationale = request.rationale;
    if (deniedBefore) rationale = "${request.deniedBefore} $rationale";
    return rationale;
  }

  Future _handleServiceDenied(PermissionRequest request) async {
    final handler = PermissionHandler();
    var check = await handler.checkPermissionStatus(request.group);
    if (check == PermissionStatus.disabled) {
      await _handleServiceDisabled(request);
    } else {
      await _handlePermissionRequest(request.deniedMessage, request);
    }
  }

  Future _handleServiceDisabled(PermissionRequest request) async {
    if (onMessage == null)
      await _onOpenSetting(request);
    else
      onMessage(request.disabledMessage, action: "LØS", data: request, onPressed: () async {
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
      await PermissionHandler().checkPermissionStatus(request.group),
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
  final PermissionGroup group;
  final String deniedMessage;
  final String disabledMessage;
  final String consequence;
  final AsyncValueGetter<bool> onCheck;

  final VoidCallback onReady;
  final String settingTarget;

  final List<String> platforms;

  PermissionRequest({
    @required this.platforms,
    @required this.title,
    @required this.rationale,
    @required this.consequence,
    @required this.deniedBefore,
    @required this.group,
    @required this.onCheck,
    @required this.deniedMessage,
    @required this.disabledMessage,
    this.onReady,
    this.settingTarget,
  });

  PermissionRequest copyWith({
    VoidCallback onReady,
  }) {
    return PermissionRequest(
      title: this.title,
      group: this.group,
      platforms: this.platforms,
      rationale: this.rationale,
      consequence: this.consequence,
      deniedBefore: this.deniedBefore,
      deniedMessage: this.deniedMessage,
      disabledMessage: this.disabledMessage,
      onCheck: this.onCheck,
      onReady: onReady ?? this.onReady,
      settingTarget: this.settingTarget,
    );
  }
}
