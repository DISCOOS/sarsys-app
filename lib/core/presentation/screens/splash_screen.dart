import 'package:SarSys/core/size_config.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
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
                  child: _buildTitle(context),
                ),
                FractionallySizedBox(
                  heightFactor: 0.8,
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: _buildIcon('sar-team-2.png'),
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
                                  "Vent litt",
                                  style: rationaleStyle,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Center(
                                child: Text(
                                  "Konfigurerer",
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
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

  Image _buildIcon(String asset) => Image.asset(
        'assets/images/$asset',
        height: SizeConfig.blockSizeVertical * 30 * (SizeConfig.isPortrait ? 1 : 2.5),
        width: SizeConfig.blockSizeHorizontal * 60 * (SizeConfig.isPortrait ? 1 : 2.5),
        alignment: Alignment.center,
      );
}
