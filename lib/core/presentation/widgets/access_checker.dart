import 'dart:async';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:SarSys/features/user/presentation/screens/unlock_screen.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessChecker extends StatefulWidget {
  final Widget child;
  final AppConfigBloc configBloc;
  final List<Permission> permissions;

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
    _trackAccessChanges();
  }

  void _trackAccessChanges() {
    _subscription?.cancel();
    _subscription = context.bloc<UserBloc>()?.listen((state) {
      // Skip initial event
      if (_listening) {
        if (_shouldLogin(state)) {
          Navigator.of(context)?.pushReplacementNamed(LoginScreen.ROUTE);
        } else if (_shouldUnlock(state)) {
          Navigator.of(context)?.pushReplacementNamed(UnlockScreen.ROUTE);
        }
      }
      _listening = true;
    });
  }

  bool _shouldLogin(UserState state) =>
      state.isUnset() || state.isLocked() || state.isUnauthorized() || state.isForbidden();

  bool _shouldUnlock(UserState state) => state.isLocked();

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
