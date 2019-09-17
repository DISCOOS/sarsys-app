import 'dart:io';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageController {
  final PromptCallback onPrompt;
  final MessageCallback onMessage;
  final AppConfigBloc configBloc;

  Directory _appDir;

  StorageController({
    @required this.onPrompt,
    @required this.onMessage,
    @required this.configBloc,
  });
  Directory get appDir => _appDir;

  ValueNotifier<bool> _isReady = ValueNotifier<bool>(false);
  ValueNotifier<bool> get isReady => _isReady;

  void init() async {
    final controller = PermissionController(
      onPrompt: onPrompt,
      onMessage: onMessage,
      configBloc: configBloc,
    );
    await controller.ask(
      controller.storageRequest.copyWith(
        onReady: () => _onReady(),
      ),
    );
  }

  void _onReady() async {
    _appDir = await getApplicationSupportDirectory();
    _isReady.value = await _appDir.exists();
  }
}
