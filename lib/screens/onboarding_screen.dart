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
        final configBloc = BlocProvider.of<AppConfigBloc>(context);
        configBloc.update(
          onboarding: false,
          demoRole: _commander ? enumName(UserRole.Commander) : enumName(UserRole.Personnel),
        );
        final authn = BlocProvider.of<UserBloc>(context).isAuthenticated;
        Navigator.pushReplacementNamed(context, authn ? 'incidents' : 'login');
      },
    );
  }

  PageViewModel _buildWelcomePage() {
    return PageViewModel(
      pageColor: const Color(0xFF749859),
//          pageColor: const Color(0xFF03A9F4),
      title: Text('SarSys'),
      body: Column(
        children: <Widget>[
          Text(
            'Søk og redning gjort enkelt',
          ),
          SizedBox(height: 16.0),
          Text(
            'Denne appen er en test av brukergrensesnitt og funksjonalitet. '
            'Ingen data i appen er reelle. Enheter, apparater og posisjoner simuleres.',
            style: TextStyle(fontSize: 16.0),
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
      title: Text('SarSys'),
      body: Column(
        children: <Widget>[
          Text(
            'Hvilken rolle du vil teste?',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(
                  translateUserRole(UserRole.Personnel),
                  textScaleFactor: 0.8,
                  style: TextStyle(color: Colors.white.withOpacity(_commander ? 0.5 : 1.0)),
                ),
                Switch(
                  value: _commander,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.orange[900],
                  inactiveTrackColor: Colors.orange[900],
                  onChanged: (value) => setState(() => _commander = value),
                ),
                Text(
                  translateUserRole(UserRole.Commander),
                  textScaleFactor: 0.8,
                  style: TextStyle(color: Colors.white.withOpacity(_commander ? 1.0 : 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
      mainImage: Image.asset(
        'assets/images/sar-team 2.png',
        height: 250.0,
        width: 250.0,
        alignment: Alignment.center,
      ),
    );
  }

  PageViewModel _buildFinishPage() {
    return PageViewModel(
      pageColor: Color(0xFF7bd4ff),
      title: Text('SarSys'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Text(
              'Det var alt!',
            ),
          ),
          Text(
            "Du vil bli logget inn som "
            "${_commander ? translateUserRole(UserRole.Commander) : translateUserRole(UserRole.Personnel)}. \n"
            "I demonstasjonsmodus godtas alle brukernavn og passord",
            textScaleFactor: 0.8,
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
}
