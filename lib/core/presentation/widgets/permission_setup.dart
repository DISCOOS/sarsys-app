

import 'dart:async';
import 'dart:io';

import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/permission_controller.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionSetup extends StatefulWidget {
  PermissionSetup({Key? key, this.onChanged}) : super(key: key);

  final ValueChanged<PermissionResponse>? onChanged;
  @override
  PermissionSetupState createState() => PermissionSetupState();
}

class PermissionSetupState extends State<PermissionSetup> {
  PermissionController? _permissions;
  Future<PermissionStatus>? _storageStatus;
  Future<PermissionStatus>? _locationAlwaysStatus;
  Future<PermissionStatus>? _locationWhenInUseStatus;
  Future<PermissionStatus>? _activityRecognitionStatus;

  bool get isStorageGranted => _storageGranted;
  bool _storageGranted = false;

  bool _locationWhenInUseGranted = false;
  bool get isLocationWhenInUseGranted => _locationWhenInUseGranted;

  bool _locationAlwaysGranted = false;
  bool get isLocationAlwaysGranted => _locationAlwaysGranted;

  bool _activityRecognitionGranted = false;
  bool get isActivityRecognitionGranted => _activityRecognitionGranted;

  TextStyle get labelTextStyle => TextStyle(fontSize: SizeConfig.labelFontSize);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_permissions == null) {
      _permissions = PermissionController(
        configBloc: context.read<AppConfigBloc>(),
        onPrompt: _onPrompt,
      );
      // Track permission changes and update views
      _permissions!.responses.listen((response) async {
        final Permission permission = response.request.permission;
        if (permission == Permission.locationAlways) {
          setState(() {
            _locationAlwaysStatus = Future.value(response.status);
            _storageStatus ??= _permissions!.check(_permissions!.storageRequest);
            _locationWhenInUseStatus ??= _permissions!.check(_permissions!.locationWhenInUseRequest);
            _activityRecognitionStatus ??= _permissions!.check(_permissions!.activityRecognitionRequest);
          });
        } else if (permission == Permission.locationWhenInUse) {
          setState(() {
            _locationWhenInUseStatus = Future.value(response.status);
            _storageStatus ??= _permissions!.check(_permissions!.storageRequest);
            _locationAlwaysStatus ??= _permissions!.check(_permissions!.locationAlwaysRequest);
            _activityRecognitionStatus ??= _permissions!.check(_permissions!.activityRecognitionRequest);
          });
        } else {
          if (permission == Permission.activityRecognition) {
            setState(() {
              _activityRecognitionStatus = Future.value(response.status);
              _storageStatus ??= _permissions!.check(_permissions!.storageRequest);
              _locationWhenInUseStatus ??= _permissions!.check(_permissions!.locationWhenInUseRequest);
              _locationAlwaysStatus ??= _permissions!.check(_permissions!.locationAlwaysRequest);
            });
          } else if (permission == Permission.storage) {
            setState(() {
              _storageStatus = Future.value(response.status);
              _locationAlwaysStatus ??= _permissions!.check(_permissions!.locationAlwaysRequest);
              _locationWhenInUseStatus ??= _permissions!.check(_permissions!.locationWhenInUseRequest);
              _activityRecognitionStatus ??= _permissions!.check(_permissions!.activityRecognitionRequest);
            });
          }
        }
        if (widget.onChanged != null) {
          widget.onChanged!(response);
        }
      });
    }
    _storageStatus = _permissions!.check(_permissions!.storageRequest);
    _locationAlwaysStatus ??= _permissions!.check(_permissions!.locationAlwaysRequest);
    _locationWhenInUseStatus ??= _permissions!.check(_permissions!.locationWhenInUseRequest);
    _activityRecognitionStatus ??= _permissions!.check(_permissions!.activityRecognitionRequest);
  }

  @override
  void dispose() {
    _permissions!.dispose();
    super.dispose();
  }

  Future<bool> _onPrompt(String title, String message) {
    return prompt(context, title, message);
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return Platform.isAndroid
        ? FutureBuilder<AndroidDeviceInfo>(
            future: DeviceInfoPlugin().androidInfo,
            builder: (context, snapshot) {
              final isAndroid10 = snapshot.hasData ? snapshot.data!.version.sdkInt > 28 : false;
              return snapshot.hasData ? _buildPermissions(isAndroid10) : _buildPermissions(false);
            })
        : _buildPermissions(true);
  }

  Padding _buildPermissions(bool isAndroid10) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        children: <Widget>[
          if (isAndroid10) _buildPermissionLocationWhenInUse() else _buildPermissionLocation(),
          if (isAndroid10) _buildPermissionLocationAlways(),
          if (isAndroid10) _buildPermissionActivityRecognition(),
          if (Platform.isAndroid) _buildPermissionStorage(),
        ],
      ),
    );
  }

  ListTile _buildPermissionStorage() => _buildPermissionCheck(
        title: 'Tilgang til lagring',
        reason: 'For lagring av kartdata på eksternt sd-kort',
        status: _storageStatus,
        request: _permissions!.storageRequest,
        onGranted: (value) => _storageGranted = value,
      );

  ListTile _buildPermissionLocation() => _buildPermissionCheck(
        title: 'Tilgang til posisjon',
        reason: 'For å finne deg selv i kartet og til sporing',
        status: _locationWhenInUseStatus,
        request: _permissions!.locationRequest,
        onGranted: (value) => _locationWhenInUseGranted = value,
      );

  ListTile _buildPermissionLocationWhenInUse() => _buildPermissionCheck(
        title: 'Tilgang til posisjon når appen er i bruk',
        reason: 'For å finne deg selv i kartet og til sporing',
        status: _locationWhenInUseStatus,
        request: _permissions!.locationWhenInUseRequest,
        onGranted: (value) => _locationWhenInUseGranted = value,
      );

  ListTile _buildPermissionLocationAlways() => _buildPermissionCheck(
        title: 'Tilgang til posisjon når appen ikke vises',
        reason: 'For å lagre og dele posisjon når appen ikke '
            'vises, for eksempel når telefonen bæres i '
            'lommen eller er låst',
        status: _locationAlwaysStatus,
        request: _permissions!.locationAlwaysRequest,
        onGranted: (value) => _locationWhenInUseGranted = value,
      );

  ListTile _buildPermissionActivityRecognition() => _buildPermissionCheck(
        title: 'Tilgang til aktivitetsgjenkjenning',
        reason: "Lokasjonstjenesten trenger denne tilgangen for å kunne "
            "spare batteri når appen ikke er i bevegelse",
        status: _activityRecognitionStatus,
        request: _permissions!.activityRecognitionRequest,
        onGranted: (value) => _activityRecognitionGranted = value,
      );

  ListTile _buildPermissionCheck({
    required String title,
    required String reason,
    required PermissionRequest request,
    required ValueSetter<bool> onGranted,
    required Future<PermissionStatus>? status,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0, right: 16.0),
        child: Text(reason),
      ),
      trailing: FutureBuilder<PermissionStatus>(
          future: status,
          builder: (context, snapshot) {
            final granted = PermissionStatus.granted == snapshot.data;
            onGranted(granted);
            return snapshot.hasData
                ? !granted
                    ? Switch(
                        value: false,
                        onChanged: (value) async {
                          if (value) {
                            await _permissions!.ask(request);
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
    );
  }
}
