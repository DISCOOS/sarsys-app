import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/size_config.dart';
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
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return IntroViewsFlutter(
      [
        _buildWelcomePage(),
        _buildRationale(),
        _buildFinishPage(),
      ],
      showSkipButton: true,
      fullTransition: 200,
      doneButtonPersist: true,
      doneText: Text('OPPSETT'),
      pageButtonTextStyles: TextStyle(
        color: Colors.white,
        fontSize: 14.0,
      ),
      columnMainAxisAlignment: MainAxisAlignment.start,
      onTapDoneButton: () async {
        final configBloc = BlocProvider.of<AppConfigBloc>(context);
        await configBloc.update(
          onboarding: false,
        );
        final authn = BlocProvider.of<UserBloc>(context).isReady;
        Navigator.pushReplacementNamed(context, authn ? 'incidents' : 'login');
      },
    );
  }

  PageViewModel _buildWelcomePage() => PageViewModel(
        pageColor: const Color(0xFF749859),
        title: _buildTitle('SARSYS'),
        mainImage: _buildIcon(
          'map.png',
        ),
        body: _buildText(
          'Søk og redning gjort enkelt',
          factor: 4,
          fontWeight: FontWeight.normal,
        ),
      );

  PageViewModel _buildRationale() => PageViewModel(
        pageColor: Colors.orange[600],
        title: _buildTitle('SARSYS'),
        mainImage: _buildIcon(
          'sar-team-2.png',
        ),
        body: _buildWithHeadline(
          'Digitalt samvirke',
          'Standardisert og for alle i redningstjenesten',
        ),
      );

  PageViewModel _buildFinishPage() => PageViewModel(
        pageColor: Color(0xFF7bd4ff),
        title: _buildTitle('SARSYS'),
        mainImage: _buildIcon(
          'cabin.png',
        ),
        body: _buildWithHeadline(
          'Alltid klar til bruk',
          'Sikkert, robust og offline',
        ),
      );

  Container _buildWithHeadline(String title, String statement) => Container(
        alignment: Alignment.center,
        child: Stack(
          overflow: Overflow.visible,
          children: <Widget>[
            Positioned(
              top: -32,
              child: Container(
                width: SizeConfig.screenWidth - 32,
                child: Center(
                  child: _buildText(
                    title,
                    factor: 5.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildText(
                statement,
                factor: 3.5,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  Widget _buildTitle(String text) => _buildText(
        text,
        factor: 8,
        fontWeight: FontWeight.w700,
      );

  Widget _buildText(
    String statement, {
    double factor = 4.5,
    FontWeight fontWeight = FontWeight.normal,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(statement,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: fontWeight,
              color: Colors.white,
              fontSize: SizeConfig.safeBlockVertical * factor * (SizeConfig.isPortrait ? 1 : 1.2),
            )),
      );

  Image _buildIcon(String asset) => Image.asset(
        'assets/images/$asset',
        height: SizeConfig.blockSizeVertical * 20 * (SizeConfig.isPortrait ? 1 : 2.5),
        width: SizeConfig.blockSizeHorizontal * 60 * (SizeConfig.isPortrait ? 1 : 2.5),
        alignment: Alignment.center,
      );
}
