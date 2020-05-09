import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/screens/login_screen.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/descriptions.dart';
import 'package:SarSys/widgets/permission_setup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen implementing the Self-Select model in Material Design, see
/// https://material.io/design/communication/onboarding.html#self-select-model
///
/// Code is based on
/// https://medium.com/aubergine-solutions/create-an-onboarding-page-indicator-in-3-minutes-in-flutter-a2bd97ceeaff
class FirstSetupScreen extends StatefulWidget {
  static const ROUTE = 'first_setup';
  @override
  _FirstSetupScreenState createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  final controller = PageController();
  final _permissionsKey = GlobalKey<PermissionSetupState>();

  Timer timer;

  int index = 0;

  List<Widget> views;

  SecurityMode _mode = SecurityMode.personal;

  String _organization = Defaults.orgId;

  bool get isComplete => isLocationGranted && (isStorageGranted || !Platform.isAndroid);

  bool get isStorageGranted => _isStorageGranted || (_permissionsKey?.currentState?.isStorageGranted ?? false);
  bool _isStorageGranted = false;

  bool get isLocationGranted => _isLocationGranted || (_permissionsKey?.currentState?.isLocationGranted ?? false);
  bool _isLocationGranted = false;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
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
            if (response.request.group == PermissionGroup.location) {
              setState(() => _isLocationGranted = PermissionStatus.granted == response.status);
            } else if (response.request.group == PermissionGroup.storage) {
              setState(() => _isStorageGranted = PermissionStatus.granted == response.status);
            }
          },
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Stack(
              alignment: AlignmentDirectional.topCenter,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: PageView.builder(
                    pageSnapping: true,
                    itemCount: views.length,
                    physics: ClampingScrollPhysics(),
                    onPageChanged: (int page) {
                      getChangedPageAndMoveBar(page);
                    },
                    controller: controller,
                    itemBuilder: (context, index) {
                      return views[index];
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
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
                        value: _organization,
                        isDense: false,
                        items: [
                          DropdownMenuItem(
                            value: Defaults.orgId,
                            child: Text('Røde Kors Hjelpekorps'),
                          )
                        ],
                        onChanged: (value) => setState(() => _organization = value),
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

  Widget _buildBottomBar() {
    return BottomAppBar(
      elevation: 4.0,
      child: Container(
        height: 56,
        child: Stack(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: FlatButton(
                disabledTextColor: Theme.of(context).bottomAppBarColor,
                child: Text('FORRIGE'),
                onPressed: index == 0
                    ? null
                    : () => controller.animateToPage(
                          index = max(0, --index),
                          curve: Curves.linearToEaseOut,
                          duration: const Duration(milliseconds: 500),
                        ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: <Widget>[
                  Container(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (int i = 0; i < views.length; i++)
                          if (i == index) ...[circleBar(true)] else circleBar(false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FlatButton(
                child: Text(index == views.length - 1 ? (isComplete ? 'FERDIG' : 'AVSLUTT') : 'NESTE'),
                onPressed: () async {
                  if (index < views.length - 1) {
                    controller.animateToPage(
                      index = min(views.length - 1, ++index),
                      curve: Curves.linearToEaseOut,
                      duration: const Duration(milliseconds: 500),
                    );
                  } else {
                    if (isComplete) {
                      // Disable automatic permission prompts (toast are still shown when applicable)
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool("checkPermission", false);
                      await context.bloc<AppConfigBloc>().update(
                            firstSetup: true,
                            securityMode: _mode,
                            storage: isStorageGranted,
                            locationWhenInUse: isLocationGranted,
                          );
                      Navigator.pushReplacementNamed(context, LoginScreen.ROUTE);
                    } else {
                      final answer = await prompt(
                        context,
                        'Bekreftelse',
                        'Dette vil lukke appen. Vil du fortsette?',
                      );
                      if (answer) {
                        SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                      }
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
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

  Widget circleBar(bool isActive) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 150),
      margin: EdgeInsets.symmetric(horizontal: 8),
      height: isActive ? 8 : 7,
      width: isActive ? 8 : 7,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
    );
  }

  void getChangedPageAndMoveBar(int page) {
    index = page;
    setState(() {});
  }
}
