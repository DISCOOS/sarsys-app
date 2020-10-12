import 'package:SarSys/core/presentation/widgets/stepped_page.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/operation/presentation/pages/passcode_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';

class OpenOperationScreen extends StatefulWidget {
  static const String ROUTE = 'open_operation';

  OpenOperationScreen({
    Key key,
    @required this.operation,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;

  @override
  _OpenOperationScreenState createState() => _OpenOperationScreenState();
}

class _OpenOperationScreenState extends State<OpenOperationScreen> with TickerProviderStateMixin {
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

  List<Widget> views;

  bool _isLoading = false;

  bool get isAuthorized => context.bloc<UserBloc>().isAuthorized(widget.operation);

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return SteppedScreen(
      views: views,
      withProgress: false,
      onCancel: _onCancel,
      onComplete: (_) {},
      isComplete: (_) => false,
      onNext: (_) => _joinAndRouteTo(),
      hasNext: (index) => isAuthorized,
    );
  }

  Future _joinAndRouteTo() async {
    _isLoading = true;
    final result = await joinOperation(widget.operation);
    if (result.isRight()) {
      jumpToOperation(context, widget.operation);
    } else {
      Navigator.pop(context);
    }
  }

  void _onCancel(int index) {
    if (_isLoading) {
      leaveOperation();
    }
    Navigator.pop(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    views = [
      if (!isAuthorized) PasscodePage(operation: widget.operation),
      _buildProgress(),
    ];
    if (isAuthorized) {
      _joinAndRouteTo();
    }
  }

  Widget _buildProgress() {
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
                              'Laster ned aksjonen...',
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
