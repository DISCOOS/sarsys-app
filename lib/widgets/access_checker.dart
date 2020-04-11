import 'dart:async';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/screens/first_setup_screen.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/screens/onboarding_screen.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessChecker extends StatefulWidget {
  final Widget child;
  final AppConfigBloc configBloc;
  final List<PermissionGroup> permissions;

  const AccessChecker({
    Key key,
    @required this.child,
    @required this.configBloc,
    this.permissions = PermissionController.REQUIRED,
  })  : assert(child != null, "Child widget is required"),
        super(key: key);

  @override
  _AccessCheckerState createState() => _AccessCheckerState();
}

class _AccessCheckerState extends State<AccessChecker> with AutomaticKeepAliveClientMixin {
  bool _checkPermission;
  bool _listening = false;
  PermissionController controller;
  StreamSubscription<UserState> _subscription;

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listening = false;
    _subscription?.cancel();
    _subscription = BlocProvider.of<UserBloc>(context)?.state?.listen((state) {
      // Skip initial event
      if (_listening && (state.isUnset() || state.isLocked())) {
        final config = BlocProvider.of<AppConfigBloc>(context)?.config;
        if (config?.onboarded != true) {
          Navigator.of(context)?.pushReplacementNamed(OnboardingScreen.ROUTE);
        } else if (config?.firstSetup != true) {
          Navigator.of(context)?.pushReplacementNamed(FirstSetupScreen.ROUTE);
        } else {
          Navigator.of(context)?.pushReplacementNamed(LoginScreen.ROUTE);
        }
      }
      _listening = true;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateKeepAlive();
    return Provider.value(
      value: _ensure(),
      child: widget.child,
    );
  }

  PermissionController _ensure() {
    controller ??= PermissionController(
      configBloc: widget.configBloc,
      onMessage: _onMessage,
      onPrompt: _onPrompt,
    );
    return controller;
  }

  void _check() {
    if (_checkPermission) {
      _ensure().init(
        permissions: widget.permissions,
      );
      _checkPermission = false;
      _storeToPrefs();
    }
  }

  // Ensure that permissions are only checked once
  void _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _checkPermission = prefs.getBool("checkPermission") ?? true;
    _check();
  }

  void _storeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("checkPermission", _checkPermission);
  }

  Future<bool> _onPrompt(String title, String message) {
    return prompt(context, title, message);
  }

  void _onMessage(String message, {String action, VoidCallback onPressed, PermissionRequest data}) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data?.title ?? "Tilgang"),
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: Text(action ?? 'OK'),
              onPressed: () {
                Navigator.of(context).pop();
                if (onPressed != null) onPressed();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
