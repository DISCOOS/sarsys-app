import 'dart:async';
import 'dart:math';

import 'package:SarSys/core/size_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({
    Key key,
    @required this.onProgress,
  }) : super(key: key);

  final Stream<DownloadProgress> onProgress;

  @override
  _DownloadPageState createState() => _DownloadPageState();
}

class DownloadProgress {
  const DownloadProgress(this.total, this.progress);

  static const DownloadProgress zero = DownloadProgress(100, 0);
  static DownloadProgress percent(int value) => DownloadProgress(100, min(value, 100));

  final int total;
  final int progress;
  double get fraction => progress / total;

  Future<DownloadProgress> linearToPercent(
    StreamSink<DownloadProgress> sink,
    int percent, {
    int steps = 10,
    Duration duration = const Duration(seconds: 2),
  }) async {
    var next = this;
    final delta = max(0, percent - progress) ~/ steps;
    if (delta > 0) {
      final waitFor = duration ~/ steps;
      for (var i = 1; i <= steps; i++) {
        sink.add(
          next = DownloadProgress(100, next.progress + delta),
        );
        await Future.delayed(waitFor);
      }
    }
    return next;
  }
}

class _DownloadPageState extends State<DownloadPage> with TickerProviderStateMixin {
  AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: 1,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
    _animController.repeat();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: _buildTitle(context),
            ),
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      height: 300,
                      child: _buildRipple(
                        _buildIcon('download.png'),
                      ),
                    )
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        child: StreamBuilder<DownloadProgress>(
                            stream: widget.onProgress,
                            initialData: DownloadProgress.zero,
                            builder: (context, snapshot) {
                              final state = snapshot.hasData ? snapshot.data : DownloadProgress.zero;
                              return Text(
                                'Laster ned aksjonen (${(state.fraction * 100).toStringAsFixed(0)} %)',
                                style: statementStyle,
                                textAlign: TextAlign.center,
                              );
                            }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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

  Widget _buildRipple(Widget icon) => AnimatedBuilder(
        animation: CurvedAnimation(
          parent: _animController,
          curve: Curves.elasticOut,
          reverseCurve: Curves.elasticIn,
        ),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _buildCircle(
                _iconWidth + (36 * _animController.value),
              ),
              Align(child: icon),
            ],
          );
        },
      );

  Widget _buildCircle(double radius) => Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.lightBlue.withOpacity(_animController.value / 3),
        ),
      );

  Image _buildIcon(String asset) => Image.asset(
        'assets/images/$asset',
        height: _iconHeight,
        width: _iconWidth,
        alignment: Alignment.center,
      );

  double get _iconHeight => SizeConfig.blockSizeVertical * 30 * (SizeConfig.isPortrait ? 1 : 2.5);
  double get _iconWidth => SizeConfig.blockSizeHorizontal * 60 * (SizeConfig.isPortrait ? 1 : 2.5);
}
