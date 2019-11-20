import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageController {
  final PromptCallback onPrompt;
  final AppConfigBloc configBloc;
  final AsyncMessageCallback onMessage;

  PermissionController _controller;

  Directory _appDir;

  StorageController({
    @required this.onPrompt,
    @required this.onMessage,
    @required this.configBloc,
    PermissionController controller,
  }) : this._controller = controller;

  Directory get appDir => _appDir;

  ValueNotifier<bool> _isReady = ValueNotifier<bool>(false);
  ValueNotifier<bool> get isReady => _isReady;

  void init() async {
    if (_controller == null) {
      _controller = PermissionController(
        onPrompt: onPrompt,
        onMessage: onMessage,
        configBloc: configBloc,
      );
    }
    _controller.init(
      permissions: [PermissionGroup.storage],
      onReady: () => _onReady(),
    );
  }

  void _onReady() async {
    _appDir = await getApplicationSupportDirectory();
    _isReady.value = await _appDir.exists();
  }
}
