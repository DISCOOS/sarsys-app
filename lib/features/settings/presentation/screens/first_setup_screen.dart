import 'dart:io';

import 'package:SarSys/core/presentation/widgets/stepped_page.dart';
import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/user/domain/entities/Security.dart';
import 'package:SarSys/features/user/presentation/screens/login_screen.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/descriptions.dart';
import 'package:SarSys/core/presentation/widgets/permission_setup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen implementing the Self-Select model in Material Design, see
/// https://material.io/design/communication/onboarding.html#self-select-model
///
class FirstSetupScreen extends StatefulWidget {
  static const ROUTE = 'first_setup';
  @override
  _FirstSetupScreenState createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final _permissionsKey = GlobalKey<PermissionSetupState>();

  List<Widget> views;

  SecurityMode _mode = SecurityMode.personal;

  String _idpHint = 'rodekors';
  final _idpHints = {
    'rodekors': 'Røde Kors Hjelpekorps',
  };

  // Minimum requirements
  bool get isComplete =>
      (isLocationWhenInUseGranted || isLocationAlwaysGranted) && (isStorageGranted || !Platform.isAndroid);

  bool get isStorageGranted => _isStorageGranted || (_permissionsKey?.currentState?.isStorageGranted ?? false);
  bool _isStorageGranted = false;

  bool get isLocationAlwaysGranted =>
      _isLocationAlwaysGranted || (_permissionsKey?.currentState?.isLocationAlwaysGranted ?? false);
  bool _isLocationAlwaysGranted = false;

  bool get isLocationWhenInUseGranted =>
      _isLocationWhenInUseGranted || (_permissionsKey?.currentState?.isLocationWhenInUseGranted ?? false);
  bool _isLocationWhenInUseGranted = false;

  bool get isActivityRecognitionGranted =>
      _isActivityRecognitionGranted || (_permissionsKey?.currentState?.isActivityRecognitionGranted ?? false);
  bool _isActivityRecognitionGranted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    views = [
      _buildSettingPage(
        title: 'Bruksmodus',
        explanation: 'Du må nullstille appen for å endre bruksmønster',
        child: _buildSecuritySetup(),
      ),
      _buildSettingPage(
        title: 'Tillatelser',
        explanation: ['SARSYS trenger tilgang til posisjon', if (Platform.isAndroid) ' og lagring'].join(),
        child: PermissionSetup(
          key: _permissionsKey,
          onChanged: (response) {
            switch (response.request.permission) {
              case Permission.locationAlways:
                setState(
                  () => _isLocationAlwaysGranted = PermissionStatus.granted == response.status,
                );
                break;
              case Permission.locationWhenInUse:
                setState(
                  () => _isLocationWhenInUseGranted = PermissionStatus.granted == response.status,
                );
                break;
              default:
                switch (response.request.permission) {
                  case Permission.storage:
                    setState(
                      () => _isStorageGranted = PermissionStatus.granted == response.status,
                    );
                    break;
                  case Permission.activityRecognition:
                    setState(
                      () => _isActivityRecognitionGranted = PermissionStatus.granted == response.status,
                    );
                    break;
                }
            }
          },
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SteppedScreen(
      views: views,
      isComplete: (_) => isComplete,
      onCancel: (_) async {
        final answer = await prompt(
          context,
          'Bekreftelse',
          'Dette vil lukke appen. Vil du fortsette?',
        );
        if (answer) {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      onComplete: (_) async {
        // Disable automatic permission prompts (toast are still shown when applicable)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("checkPermission", false);
        await context.bloc<AppConfigBloc>().updateWith(
              firstSetup: true,
              securityMode: _mode,
              storage: isStorageGranted,
              locationAlways: isLocationAlwaysGranted,
              locationWhenInUse: isLocationWhenInUseGranted,
              activityRecognition: isActivityRecognitionGranted,
            );
        Navigator.pushReplacementNamed(
          context,
          LoginScreen.ROUTE,
        );
      },
    );
  }

  ListView _buildSecuritySetup() {
    return ListView(
      itemExtent: 88,
      children: <Widget>[
        ListTile(
          title: Text('Personlig modus'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Text('Hvis appen kun benyttes av deg'),
          ),
          leading: Radio<SecurityMode>(
            value: SecurityMode.personal,
            groupValue: _mode,
            onChanged: (value) => setState(
              () {
                _mode = value;
              },
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => alert(
              context,
              title: "Bruksmodus og sikkerhet",
              content: SecurityModePersonalDescription(),
            ),
          ),
        ),
        ListTile(
          title: Text('Delt modus'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Text('Hvis appen benyttes av flere'),
          ),
          leading: Radio<SecurityMode>(
            value: SecurityMode.shared,
            groupValue: _mode,
            onChanged: (value) => setState(() {
              _mode = value;
            }),
          ),
          trailing: IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => alert(
              context,
              title: "Bruksmodus og sikkerhet",
              content: SecurityModeSharedDescription(),
            ),
          ),
        ),
        if (SecurityMode.shared == _mode)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: ListTile(
              title: Text('Velg organisasjon'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Kun brukere i valgt organisasjon kan logge på',
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Expanded(
                      child: buildDropdown<String>(
                        value: _idpHint,
                        isDense: false,
                        items: _idpHints.keys
                            .map(
                              (idpHint) => DropdownMenuItem(
                                value: idpHint,
                                child: Text(_idpHints[idpHint]),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _idpHint = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }

  Widget _buildSettingPage({
    @required String title,
    @required String explanation,
    @required Widget child,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.headline6.copyWith(
      color: primaryColor,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      fontSize: SizeConfig.safeBlockHorizontal * 6,
    );
    final explanationStyle = Theme.of(context).textTheme.caption.copyWith(
          fontSize: SizeConfig.safeBlockHorizontal * 3.8,
        );

    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: Text(
                  title,
                  style: titleStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Center(
                child: Text(
                  explanation,
                  style: explanationStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: child,
        ),
      ],
    );
  }
}
