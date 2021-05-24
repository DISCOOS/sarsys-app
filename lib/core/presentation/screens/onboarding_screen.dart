import 'dart:async';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/settings/presentation/screens/first_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Screen implementing the Top user benefits model in Material Design, see
/// https://material.io/design/communication/onboarding.html#top-user-benefits-model
///
/// Code is based on
/// https://medium.com/aubergine-solutions/create-an-onboarding-page-indicator-in-3-minutes-in-flutter-a2bd97ceeaff
class OnboardingScreen extends StatefulWidget {
  static const ROUTE = 'onboarding';
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();

  Timer timer;

  @override
  void initState() {
    super.initState();
    _scheduleScroll();
    controller.addListener(() {
      _scheduleScroll();
    });
  }

  Timer _scheduleScroll() {
    timer ??= Timer(Duration(seconds: 3), () {
      if (mounted) {
        if (index < views.length - 1) {
          index++;
        } else {
          index = 0;
        }

        controller.animateToPage(
          index,
          curve: Curves.linearToEaseOut,
          duration: Duration(milliseconds: 450),
        );
        timer = null;
        _scheduleScroll();
      }
    });
    return timer;
  }

  int index = 0;

  List<Widget> views;

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    views = [
      _buildTopBenefit(
        asset: 'map.png',
        rationale: 'Enkelt å bruke',
        statement: 'Standardisert og komplett støtteverktøy',
      ),
      _buildTopBenefit(
        asset: 'sar-team-2.png',
        rationale: 'Digital samvirke',
        statement: 'For alle i redningstjenesten',
      ),
      _buildTopBenefit(
        asset: 'cabin.png',
        rationale: 'Alltid klar til bruk',
        statement: 'Sikkert, robust og tilgjengelig offline',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Stack(
              alignment: AlignmentDirectional.bottomCenter,
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: _buildTitle(),
                ),
                Container(
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

  Column _buildBottomBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 32, bottom: 24.0),
          child: Center(
            child: Container(
              height: 42,
              child: ElevatedButton(
                child: Text('KOM I GANG'),
                onPressed: () async {
                  timer?.cancel();
                  timer = null;
                  await context.read<AppConfigBloc>().updateWith(
                        onboarded: true,
                      );
                  Navigator.pushReplacementNamed(context, FirstSetupScreen.ROUTE);
                },
              ),
            ),
          ),
        ),
        Container(
          height: 56,
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(bottom: 16),
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
      ],
    );
  }

  Widget _buildTitle() {
    final primaryColor = Theme.of(context).primaryColor;
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.headline6.copyWith(
      color: primaryColor,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      fontSize: SizeConfig.safeBlockVertical * 8,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child: Text(
        'SARSYS',
        style: titleStyle,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTopBenefit({String asset, String rationale, String statement}) {
    final primaryColor = Theme.of(context).primaryColor;
    final textTheme = Theme.of(context).textTheme;
    final rationaleStyle = textTheme.headline6.copyWith(
      color: primaryColor,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      fontSize: SizeConfig.safeBlockVertical * 4.0,
    );
    final statementStyle = Theme.of(context).textTheme.subtitle2.copyWith(
          fontSize: SizeConfig.safeBlockVertical * 2.5,
        );

    return Container(
      child: FractionallySizedBox(
        widthFactor: 0.9,
        heightFactor: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: SizeConfig.safeBlockVertical * 8 + 32,
                ),
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: _buildIcon(asset),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: SizeConfig.safeBlockVertical),
                  child: Center(
                    child: Text(
                      rationale,
                      style: rationaleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: Text(
                      statement,
                      style: statementStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Image _buildIcon(String asset) => Image.asset(
        'assets/images/$asset',
        height: SizeConfig.blockSizeVertical * 30 * (SizeConfig.isPortrait ? 1 : 2.5),
        width: SizeConfig.blockSizeHorizontal * 60 * (SizeConfig.isPortrait ? 1 : 2.5),
        alignment: Alignment.center,
      );

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
