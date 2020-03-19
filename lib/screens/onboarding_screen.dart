import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intro_views_flutter/Models/page_view_model.dart';
import 'package:intro_views_flutter/intro_views_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _commander = true;
  bool _onboard = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _commander = (UserRole.commander == BlocProvider.of<AppConfigBloc>(context)?.config?.toRole());
  }

  @override
  Widget build(BuildContext context) {
    return IntroViewsFlutter(
      [
        _buildWelcomePage(),
        _buildDemoPage(),
        _buildFinishPage(),
      ],
      showSkipButton: false,
      doneText: Text('FERDIG'),
      pageButtonTextStyles: TextStyle(
        color: Colors.white,
        fontSize: 14.0,
      ),
      showBackButton: true,
      showNextButton: true,
      columnMainAxisAlignment: MainAxisAlignment.start,
      backText: Text('TILBAKE'),
      nextText: Text('NESTE'),
      onTapDoneButton: () async {
        await BlocProvider.of<UserBloc>(context).logout();
        final configBloc = BlocProvider.of<AppConfigBloc>(context);
        await configBloc.update(
          onboarding: _onboard,
          demoRole: _commander ? enumName(UserRole.commander) : enumName(UserRole.personnel),
        );
        final authn = BlocProvider.of<UserBloc>(context).isAuthenticated;
        Navigator.pushReplacementNamed(context, authn ? 'incidents' : 'login');
      },
    );
  }

  PageViewModel _buildWelcomePage() {
    return PageViewModel(
      pageColor: const Color(0xFF749859),
      title: Text('SARSys'),
      body: Column(
        children: <Widget>[
          Text(
            'Søk og redning gjort enkelt',
          ),
          SizedBox(height: 16.0),
          Text(
            'Ingen data i appen er reelle. Enheter, apparater og posisjoner simuleres.',
            textScaleFactor: 0.75,
          ),
        ],
      ),
      mainImage: Image.asset(
        'assets/images/map.png',
        height: 250.0,
        width: 250.0,
        alignment: Alignment.center,
      ),
    );
  }

  PageViewModel _buildDemoPage() {
    return PageViewModel(
      pageColor: Colors.orange[600],
      title: Text('SARSys'),
      body: Column(
        children: <Widget>[
          Text(
            'Hvilken rolle du vil teste?',
          ),
          Expanded(
            child: _buildSwith(
              _commander,
              leftSide: translateUserRole(UserRole.personnel),
              rightSide: translateUserRole(UserRole.commander),
              onChanged: (value) => setState(() => _commander = value),
            ),
          ),
        ],
      ),
      mainImage: Image.asset(
        'assets/images/sar-team-2.png',
        height: 250.0,
        width: 250.0,
        alignment: Alignment.center,
      ),
    );
  }

  PageViewModel _buildFinishPage() {
    return PageViewModel(
      pageColor: Color(0xFF7bd4ff),
      title: Text('SARSys'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Text(
              'Det var alt!',
            ),
          ),
          Text(
            "Du vil bli logget inn som "
            "${_commander ? translateUserRole(UserRole.commander) : translateUserRole(UserRole.personnel)}. \n"
            "Alle brukernavn og passord godtas i demonstrasjonsmodus.",
            textScaleFactor: 0.75,
          ),
        ],
      ),
      mainImage: Image.asset(
        'assets/images/cabin.png',
        height: 250.0,
        width: 250.0,
        alignment: Alignment.center,
      ),
    );
  }

  Row _buildSwith(
    bool value, {
    @required String leftSide,
    @required String rightSide,
    @required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Text(
          leftSide,
          textScaleFactor: 0.8,
          style: TextStyle(color: Colors.white.withOpacity(value ? 0.5 : 1.0)),
        ),
        Switch(
          value: _commander,
          activeColor: Colors.white,
          activeTrackColor: Colors.orange[900],
          inactiveTrackColor: Colors.orange[900],
          onChanged: onChanged,
        ),
        Text(
          rightSide,
          textScaleFactor: 0.8,
          style: TextStyle(color: Colors.white.withOpacity(_commander ? 1.0 : 0.5)),
        ),
      ],
    );
  }
}
