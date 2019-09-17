import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:system_setting/system_setting.dart';

class PermissionController {
  final PromptCallback onPrompt;
  final MessageCallback onMessage;
  final AppConfigBloc configBloc;

  bool _resolving = false;
  bool get resolving => _resolving;

  PermissionController({
    @required this.configBloc,
    this.onPrompt,
    this.onMessage,
  });

  PermissionRequest get storageRequest => PermissionRequest(
        group: PermissionGroup.storage,
        title: "Lagring",
        rationale: "Du har tidligere avslått tilgang til lagring. "
            "Du må akseptere tilgang før kartdata kan lagres lokalt.",
        onDisabledMessage: "Lagring er avslått",
        onDeniedMessage: "Lagring er ikke tillatt",
        onCheck: () => _updateAppConfig(
          storage: true,
        ),
      );

  PermissionRequest get locationWhenInUseRequest => PermissionRequest(
        group: PermissionGroup.locationWhenInUse,
        title: "Stedstjenester",
        rationale: "Du har tidligere avslått deling av posisjon. "
            "Du må akseptere deling av lokasjon med appen for å se hvor du er.",
        onDisabledMessage: "Stedstjenester er avslått",
        onDeniedMessage: "Lokalisering er ikke tillatt",
        settingTarget: SettingTarget.LOCATION,
        onCheck: () => _updateAppConfig(
          locationWhenInUse: true,
        ),
      );

  void init() async {
    await ask(
      storageRequest,
    );
    await ask(
      locationWhenInUseRequest,
    );
  }

  Future ask(PermissionRequest request) async {
    final handler = PermissionHandler();
    final status = await handler.checkServiceStatus(request.group);
    switch (status) {
      case ServiceStatus.enabled:
        handle(
          await handler.checkPermissionStatus(request.group),
          request,
        );
        break;
      case ServiceStatus.disabled:
        _handleServiceDisabled(request);
        break;
      case ServiceStatus.unknown:
      case ServiceStatus.notApplicable:
        if (onMessage != null) onMessage("${request.title} er ikke tilgjengelig");
        break;
      default:
        break;
    }
  }

  Future handle(PermissionStatus status, PermissionRequest request) async {
    var isReady = false;

    // Prevent re-entrant loop
    _resolving = true;

    switch (status) {
      case PermissionStatus.granted:
        if (await _updateAppConfig(locationWhenInUse: true) && onMessage != null)
          onMessage(
            "${request.title} er tilgjengelig",
          );
        isReady = true;
        break;
      case PermissionStatus.restricted:
        if (await _updateAppConfig(locationWhenInUse: true) && onMessage != null)
          onMessage(
            "Tilgang til ${request.title.toLowerCase()} er begrenset",
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
        _handlePermissionRequest("${request.title} er ikke tilgjengelig", request);
        break;
    }
    if (isReady && request.onReady != null) request.onReady();

    _resolving = false;
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
      onMessage(reason, action: "LØS", onPressed: () async {
        await _onAction(handler, request);
      });
  }

  Future _onAction(PermissionHandler handler, PermissionRequest request) async {
    var prompt = true;
    // Only supported on Android, iOS always return false
    if (await handler.shouldShowRequestPermissionRationale(request.group)) {
      prompt = onPrompt != null && await onPrompt(request.title, request.rationale);
    }
    if (prompt) {
      var response = await handler.requestPermissions([request.group]);
      var status = response[request.group];
      if ([PermissionStatus.granted, PermissionStatus.restricted].contains(status)) {
        handle(status, request);
      } else if (onMessage != null) {
        onMessage("${request.title} er ikke tilgjengelig");
      }
    }
  }

  void _handleServiceDenied(PermissionRequest request) async {
    final handler = PermissionHandler();
    var check = await handler.checkServiceStatus(request.group);
    if (check == ServiceStatus.disabled) {
      _handleServiceDisabled(request);
    } else {
      _handlePermissionRequest(request.onDeniedMessage, request);
    }
  }

  void _handleServiceDisabled(PermissionRequest request) async {
    if (onMessage == null)
      _onOpenSetting(request);
    else
      onMessage(request.onDisabledMessage, action: "LØS", onPressed: () async {
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
  final PermissionGroup group;
  final String onDeniedMessage;
  final String onDisabledMessage;
  final AsyncValueGetter<bool> onCheck;

  final VoidCallback onReady;
  final SettingTarget settingTarget;

  PermissionRequest({
    @required this.title,
    @required this.rationale,
    @required this.group,
    @required this.onCheck,
    @required this.onDeniedMessage,
    @required this.onDisabledMessage,
    this.onReady,
    this.settingTarget,
  });

  PermissionRequest copyWith({
    VoidCallback onReady,
  }) {
    return PermissionRequest(
      title: this.title,
      rationale: this.rationale,
      group: this.group,
      onDeniedMessage: this.onDeniedMessage,
      onDisabledMessage: this.onDisabledMessage,
      onCheck: this.onCheck,
      onReady: onReady ?? this.onReady,
      settingTarget: this.settingTarget,
    );
  }
}
