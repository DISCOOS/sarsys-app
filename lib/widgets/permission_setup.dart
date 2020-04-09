import 'dart:async';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/controllers/permission_controller.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSetup extends StatefulWidget {
  PermissionSetup({Key key, this.onChanged}) : super(key: key);

  final ValueChanged<PermissionResponse> onChanged;
  @override
  PermissionSetupState createState() => PermissionSetupState();
}

class PermissionSetupState extends State<PermissionSetup> {
  PermissionController _permissions;
  Future<PermissionStatus> _storageStatus;
  Future<PermissionStatus> _locationStatus;

  bool get isStorageGranted => _storageGranted;
  bool _storageGranted = false;

  bool _locationGranted = false;
  bool get isLocationGranted => _locationGranted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_permissions == null) {
      _permissions = PermissionController(
        configBloc: BlocProvider.of<AppConfigBloc>(context),
        onPrompt: _onPrompt,
      );
      // Track permission changes and update views
      _permissions.responses.listen((response) async {
        switch (response.request.group) {
          case PermissionGroup.locationWhenInUse:
            setState(() {
              _locationStatus = Future.value(response.status);
              _storageStatus = _permissions.check(_permissions.storageRequest);
            });
            break;
          case PermissionGroup.storage:
            setState(() {
              _storageStatus = Future.value(response.status);
              _locationStatus = _permissions.check(_permissions.locationWhenInUseRequest);
            });
            break;
        }
        if (widget.onChanged != null) {
          widget.onChanged(response);
        }
      });
    }
    _storageStatus = _permissions.check(_permissions.storageRequest);
    _locationStatus = _permissions.check(_permissions.locationWhenInUseRequest);
  }

  @override
  void dispose() {
    _permissions.dispose();
    super.dispose();
  }

  Future<bool> _onPrompt(String title, String message) {
    return prompt(context, title, message);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        itemExtent: 88,
        children: <Widget>[
          ListTile(
            title: Text('Tilgang til posisjon'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 16.0),
              child: Text('For å finne deg selv i kartet og sporing'),
            ),
            trailing: FutureBuilder<PermissionStatus>(
                future: _locationStatus,
                builder: (context, snapshot) {
                  _locationGranted = PermissionStatus.granted == snapshot.data;
                  return snapshot.hasData
                      ? !_locationGranted
                          ? Switch(
                              value: false,
                              onChanged: (value) async {
                                if (value) {
                                  _permissions.ask(
                                    _permissions.locationWhenInUseRequest,
                                  );
                                }
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed: null,
                              iconSize: 32,
                            )
                      : CircularProgressIndicator();
                }),
          ),
          ListTile(
            title: Text('Tilgang til lagring'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 16.0),
              child: Text('For lagring av kartdata lokalt'),
            ),
            trailing: FutureBuilder<PermissionStatus>(
                future: _storageStatus,
                builder: (context, snapshot) {
                  _storageGranted = PermissionStatus.granted == snapshot.data;
                  return snapshot.hasData
                      ? !_storageGranted
                          ? Switch(
                              value: false,
                              onChanged: (value) async {
                                if (value) {
                                  _storageStatus = _permissions.ask(
                                    _permissions.storageRequest,
                                  );
                                }
                              },
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed: null,
                              iconSize: 32,
                            )
                      : CircularProgressIndicator();
                }),
          ),
        ],
      ),
    );
  }
}
