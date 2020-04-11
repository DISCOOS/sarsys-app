import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/models/User.dart';
import 'package:catcher/core/catcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'incidents_screen.dart';

class UnlockScreen extends StatefulWidget {
  static const ROUTE = 'change/pin';

  const UnlockScreen({
    Key key,
    this.returnTo,
    this.popOnClose = false,
  }) : super(key: key);
  final String returnTo;
  final bool popOnClose;

  @override
  UnlockScreenState createState() => UnlockScreenState();
}

class UnlockScreenState extends State<UnlockScreen> with TickerProviderStateMixin {
  static const color = Color(0xFF0d2149);
  final _formKey = GlobalKey<FormState>();

  /// Pin code entered by user
  String _pin;

  /// Test result for each digit entered
  bool _wrongPin = false;

  /// Indicates that all four digits are entered
  bool _pinComplete = false;

  /// State for async result processing from [UserState] stream
  bool _popWhenReady = false;

  UserError _lastError;

  AnimationController _animController;
  StreamSubscription<UserState> _subscription;

  FocusNode _focusNode;
  ScrollController _scrollController;
  TextEditingController _pinController;

  TextTheme textTheme;
  TextStyle titleStyle;
  TextStyle emailStyle;

  UserBloc _bloc;

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _pinController = TextEditingController();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _bloc = _toBloc(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    textTheme ??= Theme.of(context).textTheme;
    titleStyle ??= textTheme.subhead.copyWith(
      fontSize: SizeConfig.safeBlockVertical * 2.5,
    );
    emailStyle ??= textTheme.body1.copyWith(
      color: textTheme.caption.color,
      fontSize: SizeConfig.safeBlockVertical * 2.1,
    );

    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            alignment: Alignment.center,
            widthFactor: 0.90,
            heightFactor: 0.90,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Container(
                  child: _buildBody(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return AnimatedCrossFade(
      duration: Duration(microseconds: 300),
      crossFadeState: _inProgress() ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildProgress(context),
      secondChild: _buildForm(context),
    );
  }

  bool _inProgress() => _bloc?.currentState?.isPending() == true;

  Container _buildProgress(BuildContext context) {
    _animController ??= AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _animController.repeat();

    return Container(
      padding: EdgeInsets.all(24.0),
      child: ListView(
        shrinkWrap: true,
        reverse: true,
        controller: _scrollController,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 300,
                  child: _buildRipple(
                    _buildIcon(),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  'Låser opp, vent litt',
                  style: _toStyle(context, 22, FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container _buildForm(BuildContext context) {
    _animController?.stop(canceled: false);
    if (!_pinComplete) {
      _focusNode.requestFocus();
    }

    return Container(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          reverse: true,
          controller: _scrollController,
          children: [
            Column(
              children: [
                _buildTitle(context),
                // Logo
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _buildIcon(),
                ),
                ..._buildFields(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields() {
    final isError = _isError();
    var fields = isError ? [_buildErrorText()] : <Widget>[];
    if (isError) {
      _pinController.clear();
    }
    return fields..add(_buildSecure());
  }

  bool _isError() => _bloc.currentState is UserException;

  Widget _buildErrorText() => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          'Feil pinkode',
          style: _toStyle(
            context,
            16,
            FontWeight.bold,
            color: Colors.redAccent,
          ),
          textAlign: TextAlign.center,
        ),
      );

  Widget _buildTitle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          "SARSys",
          style: _toStyle(context, 42, FontWeight.bold),
        ),
      ),
    );
  }

  TextStyle _toStyle(
    BuildContext context,
    double size,
    FontWeight weight, {
    Color color = color,
  }) =>
      Theme.of(context).textTheme.title.copyWith(
            fontSize: size,
            color: color,
            fontWeight: weight,
          );

  Image _buildIcon() => Image.asset(
        'assets/images/sar-team-2.png',
        height: SizeConfig.blockSizeVertical * 20 * (SizeConfig.isPortrait ? 1 : 2.5),
        width: SizeConfig.blockSizeHorizontal * 40 * (SizeConfig.isPortrait ? 1 : 2.5),
        alignment: Alignment.center,
      );

  Widget _buildRipple(Widget icon) => AnimatedBuilder(
        animation: CurvedAnimation(
          parent: _animController,
          curve: Curves.elasticInOut,
        ),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _buildCircle(200 + (24 * _animController.value)),
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

  Widget _buildSecure() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildFullName(_bloc.user),
              ),
              Text(
                _wrongPin ? 'Feil pinkode' : 'Oppgi din pinkode',
                style: _toPinTextStyle(context),
                textAlign: TextAlign.center,
              ),
              _buildPinInput(
                setState: setState,
              ),
              _buildDivider(),
              _buildLogoutAction(enabled: true),
            ],
          );
        },
      );

  TextStyle _toPinTextStyle(BuildContext context) => _toStyle(
        context,
        22,
        FontWeight.bold,
        color: _wrongPin && _pinComplete ? Colors.red : null,
      );

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Stack(
        children: [
          Divider(),
          Center(
            child: Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'ELLER',
                style: theme.textTheme.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutAction({bool enabled}) => buildAction(
        'LOGG AV',
        () async {
          try {
            await _bloc.logout();
          } on Exception {/* Is handled by StreamBuilder */}
        },
        enabled: enabled,
      );

  Widget _buildFullName(User user) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              user.fullName,
              style: titleStyle,
            ),
          ),
          Flexible(
            child: Text(
              user.email,
              style: emailStyle,
            ),
          ),
        ],
      );

  Widget _buildPinInput({StateSetter setState}) => Container(
        constraints: BoxConstraints(minWidth: 215, maxWidth: 215),
        padding: const EdgeInsets.only(top: 24.0),
        child: PinCodeTextField(
          length: 4,
          obsecureText: false,
          autoFocus: true,
          inputFormatters: [
            WhitelistingTextInputFormatter(RegExp('[0-9]')),
          ],
          textInputAction: TextInputAction.send,
          animationType: AnimationType.fade,
          shape: PinCodeFieldShape.box,
          autoDismissKeyboard: false,
          textInputType: TextInputType.numberWithOptions(),
          animationDuration: Duration(milliseconds: 300),
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 50,
          activeFillColor: color,
          focusNode: _focusNode,
          controller: _pinController,
          autoDisposeController: false,
          autoDisposeFocusNode: false,
          onChanged: (_) {},
          onCompleted: (value) => _onCompleted(
            value,
            setState,
          ),
        ),
      );

  void _onCompleted(String value, StateSetter setState) async {
    _pin = value;
    _wrongPin = _bloc.user.security.pin != value;

    _pinComplete = true;
    if (_wrongPin) {
      _pinController.clear();
      _focusNode.requestFocus();
      if (setState != null) {
        setState(() {});
      }
    } else {
      _popWhenReady = true;
      await _bloc.unlock(
        pin: _pin,
      );
    }
  }

  Widget buildAction(
    String label,
    Function() onPressed, {
    bool enabled = true,
    Type type = RaisedButton,
    Widget icon,
    Color color = const Color.fromRGBO(00, 41, 73, 1),
    bool validate = true,
  }) =>
      Container(
        constraints: BoxConstraints(
          minHeight: 56,
          maxHeight: 56,
          minWidth: 215,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: _buildButton(
            color,
            label,
            enabled,
            onPressed,
            type,
            icon: icon,
            validate: validate,
          ),
        ),
      );

  Widget _buildButton(
    Color color,
    String label,
    bool enabled,
    onPressed(),
    Type type, {
    Widget icon,
    bool validate = true,
  }) {
    if (type == OutlineButton) {
      return _buildOutlineButton(
        label,
        enabled,
        onPressed,
        icon: icon,
        validate: validate,
      );
    }
    return _buildRaisedButton(
      color,
      label,
      enabled,
      onPressed,
      icon: icon,
      validate: validate,
    );
  }

  Widget _buildRaisedButton(
    Color color,
    String label,
    bool enabled,
    onPressed(), {
    Widget icon,
    bool validate = true,
  }) =>
      RaisedButton(
        color: color,
        elevation: 2.0,
        padding: icon == null ? null : EdgeInsets.only(left: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.8, color: Colors.white),
                textAlign: icon == null ? TextAlign.center : TextAlign.left,
              ),
            ),
          ],
        ),
        onPressed: enabled ? () => _onActionPressed(validate, onPressed) : null,
      );

  void _onActionPressed(bool validate, onPressed()) {
    if (!validate || _validateAndSave()) {
      FocusScopeNode currentFocus = FocusScope.of(context);
      if (!currentFocus.hasPrimaryFocus) {
        currentFocus.unfocus();
      }
      onPressed();
    }
  }

  Widget _buildOutlineButton(
    String label,
    bool enabled,
    onPressed(), {
    Widget icon,
    bool validate = true,
  }) =>
      OutlineButton(
        padding: icon == null ? null : EdgeInsets.only(left: 16.0),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Text(
              label,
              style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.8),
              textAlign: icon == null ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
        onPressed: enabled ? () => _onActionPressed(validate, onPressed) : null,
      );

  UserBloc _toBloc(BuildContext context) {
    final bloc = BlocProvider.of<UserBloc>(context);
    _subscription?.cancel();
    _subscription = bloc.state.listen((UserState state) {
      _process(state, bloc, context);
    });
    return bloc;
  }

  void _process(UserState state, UserBloc bloc, BuildContext context) {
    switch (state.runtimeType) {
      case UserUnlocked:
        // Only close login if user is authenticated and app is secured with pin
        if (bloc.isAuthenticated && _popWhenReady) {
          _popTo(context);
        }
        break;
      case UserError:
        if (_lastError == null) {
          Catcher.reportCheckedError(
            state.data,
            (state as UserError).stackTrace,
          );
          _lastError = state;
        }
        break;
      default:
        _lastError = null;
        break;
    }
  }

  bool _isPopped = false;

  void _popTo(BuildContext context) {
    if (!_isPopped) {
      _isPopped = true;
      if (widget.popOnClose) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(
          context,
          widget.returnTo ?? IncidentsScreen.ROUTE,
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController?.dispose();
    _scrollController?.dispose();
    _focusNode.dispose();
    _pinController.dispose();
    _animController = null;
    _scrollController = null;
    _focusNode = null;
    _pinController = null;
    super.dispose();
  }
}
