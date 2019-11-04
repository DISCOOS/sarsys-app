import 'dart:io';
import 'package:intl/intl.dart';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_setting/system_setting.dart';

class PermissionController {
  static const String IOS = "ios";
  static const String ANDROID = "android";
  static const List<String> ALL_OS = const [ANDROID, IOS];

  static const List<PermissionGroup> REQUIRED = const [
    PermissionGroup.storage,
    PermissionGroup.locationWhenInUse,
  ];

  final PromptCallback onPrompt;
  final MessageCallback<PermissionRequest> onMessage;
  final AppConfigBloc configBloc;

  bool _resolving = false;
  bool get resolving => _resolving;

  Set<PermissionGroup> _permissions = {};

  PermissionController({
    @required this.configBloc,
    this.onPrompt,
    this.onMessage,
  }) : assert(configBloc != null, "AppConfigBloc is required");

  /// Clone with given parameters.
  ///
  /// Will copy resolving state and current permissions
  PermissionController cloneWith({
    PromptCallback onPrompt,
    MessageCallback<PermissionRequest> onMessage,
  }) {
    return PermissionController(
      configBloc: configBloc,
      onMessage: onMessage ?? this.onMessage,
      onPrompt: onPrompt ?? this.onPrompt,
    )
      .._resolving = _resolving
      .._permissions = _permissions;
  }

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
        onCheck: () => _updateAppConfig(
          storage: true,
        ),
      );

  /// Get [PermissionGroup.locationWhenInUseRequest] request
  PermissionRequest get locationWhenInUseRequest => PermissionRequest(
        platforms: ALL_OS,
        group: PermissionGroup.locationWhenInUse,
        title: "Stedstjenester",
        rationale: "Du må akseptere deling av lokasjon med appen for å se hvor du er.",
        disabledMessage: "Stedstjenester er avslått.",
        deniedMessage: "Lokalisering er ikke tillatt.",
        deniedBefore: "Du har tidligere avslått deling av posisjon.",
        consequence: "Du kan ikke vise hvor du er i kartet eller lagre sporet ditt automatisk.",
        settingTarget: SettingTarget.LOCATION,
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

  Future<bool> ask(PermissionRequest request) async {
    var allowed = false;
    if (request.platforms.contains(Platform.operatingSystem)) {
      final handler = PermissionHandler();
      final status = await handler.checkServiceStatus(request.group);
      switch (status) {
        case ServiceStatus.enabled:
        case ServiceStatus.notApplicable:
          allowed = await handle(
            await handler.checkPermissionStatus(request.group),
            request,
          );
          break;
        case ServiceStatus.disabled:
          _handleServiceDisabled(request);
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
    return allowed;
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
              "Tilgang til ${toBeginningOfSentenceCase(request.title)} er begrenset",
              data: request,
            );
          isReady = true;
          break;
        case PermissionStatus.denied:
          _handleServiceDenied(request);
          break;
        case PermissionStatus.disabled:
          _handleServiceDenied(request);
          break;
        default:
          _handlePermissionRequest("${request.title} er ikke tilgjengelig. ${request.consequence}", request);
          break;
      }
      if (isReady && request.onReady != null) request.onReady();
    }
    _resolving = false;

    return isReady;
  }

  Future<bool> _updateAppConfig({
    bool storage,
    bool locationWhenInUse,
  }) async {
    var notify = true;
    if (configBloc.isReady) {
      final config = configBloc.config;
      notify = config != (await configBloc.update(locationWhenInUse: locationWhenInUse));
    }
    return notify;
  }

  void _handlePermissionRequest(String reason, PermissionRequest request) async {
    final handler = PermissionHandler();
    if (onMessage == null)
      _onAction(handler, request);
    else
      onMessage(reason, action: "LØS", data: request, onPressed: () async {
        await _onAction(handler, request);
      });
  }

  Future _onAction(PermissionHandler handler, PermissionRequest request) async {
    var prompt = true;
    final prefs = await SharedPreferences.getInstance();
    var deniedBefore = prefs.getBool("userDeniedGroupBefore_${request.group}") ?? false;
    // Only supported on Android, iOS always return false
    if (await handler.shouldShowRequestPermissionRationale(request.group)) {
      prompt = onPrompt != null && await onPrompt(request.title, _toRationale(request, deniedBefore));
    }
    if (prompt) {
      var response = await handler.requestPermissions([request.group]);
      var status = response[request.group];
      if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
        handle(status, request);
      } else if (onMessage != null) {
        onMessage(
          "${request.title} er ikke tilgjengelig. ${request.consequence}",
          data: request,
        );
      }
    }
  }

  String _toRationale(PermissionRequest request, bool deniedBefore) {
    var rationale = request.rationale;
    if (deniedBefore) rationale = "${request.deniedBefore} $rationale";
    return rationale;
  }

  void _handleServiceDenied(PermissionRequest request) async {
    final handler = PermissionHandler();
    var check = await handler.checkServiceStatus(request.group);
    if (check == ServiceStatus.disabled) {
      _handleServiceDisabled(request);
    } else {
      _handlePermissionRequest(request.deniedMessage, request);
    }
  }

  void _handleServiceDisabled(PermissionRequest request) async {
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
    await SystemSetting.goto(request.settingTarget);
    handle(
      await PermissionHandler().checkPermissionStatus(request.group),
      request,
    );
  }
}

class PermissionRequest {
  final String title;
  final String rationale;
  final String deniedBefore;
  final PermissionGroup group;
  final String deniedMessage;
  final String disabledMessage;
  final String consequence;
  final AsyncValueGetter<bool> onCheck;

  final VoidCallback onReady;
  final SettingTarget settingTarget;

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
