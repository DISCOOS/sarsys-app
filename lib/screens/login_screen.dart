import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum LoginType {
  automatic,
  changePin,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key key, this.type = LoginType.automatic}) : super(key: key);
  final LoginType type;

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends RouteWriter<LoginScreen, void> with TickerProviderStateMixin {
  static const color = Color(0xFF0d2149);
  final _formKey = GlobalKey<FormState>();

  String _pin = "";
  String _username = "";
  bool _wrongPin = false;
  bool _verifyPin = false;
  bool _securePin = false;
  bool _pinComplete = false;
  bool _securePending = false;

  AnimationController _animController;
  StreamSubscription<UserState> _subscription;

  FocusNode _focusNode = FocusNode();
  ScrollController _scrollController = ScrollController();
  TextEditingController _pinController = TextEditingController();

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  UserBloc _handle(BuildContext context) {
    final bloc = BlocProvider.of<UserBloc>(context);
    _subscription?.cancel();
    _subscription = bloc.state.listen((UserState state) {
      switch (state.runtimeType) {
        case UserUnlocked:
        case UserAuthenticated:
          if (bloc.isReady && LoginType.automatic == widget.type) {
            Navigator.pushReplacementNamed(context, 'incident/list');
          }
          break;
      }
    });
    return bloc;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController?.dispose();
    _scrollController?.dispose();
    _animController = null;
    _scrollController = null;
    /* _focusNode is disposed automatically by PinCodeTextField */
    _focusNode = null;
    /* _pinController is disposed automatically by PinCodeTextField */
    _pinController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
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
    );
  }

  Widget _buildBody(BuildContext context) {
    UserBloc bloc = _handle(context);
    return StreamBuilder<UserState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        return AnimatedCrossFade(
          duration: Duration(microseconds: 300),
          crossFadeState: _inProgress(snapshot, bloc) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: _buildProgress(context),
          secondChild: _buildForm(context, snapshot, bloc),
        );
      },
    );
  }

  bool _inProgress(AsyncSnapshot<UserState> snapshot, UserBloc bloc) =>
      bloc.isReady && !changePin || snapshot.hasData && (snapshot.data.isPending() || _securePending);

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
                  'Logger deg inn, vent litt',
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

  Container _buildForm(
    BuildContext context,
    AsyncSnapshot<UserState> snapshot,
    UserBloc bloc,
  ) {
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
                ..._buildFields(snapshot, bloc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields(AsyncSnapshot<UserState> snapshot, UserBloc bloc) {
    var fields = _isError(snapshot) ? [_buildErrorText(snapshot, bloc)] : <Widget>[];

    if (changePin || !bloc.isSecured) {
      return fields..add(_buildSecure(bloc));
    } else if (bloc.isLocked) {
      _pinController.clear();
      return fields..addAll(_buildUnlock(bloc));
    }
    return fields..add(_buildAuthenticate(bloc));
  }

  bool _isError(AsyncSnapshot<UserState> snapshot) => snapshot.hasData && snapshot.data is UserException;

  Widget _buildErrorText(AsyncSnapshot<UserState> snapshot, UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          _toError(snapshot.data, bloc),
          style: _toStyle(
            context,
            22,
            FontWeight.bold,
            color: Colors.redAccent,
          ),
          textAlign: TextAlign.center,
        ),
      );

  String _toError(UserException state, UserBloc bloc) {
    if (state is UserUnauthorized) {
      return bloc.isLocked ? 'Feil pinkode' : 'Feil brukernavn eller passord';
    } else if (state is UserForbidden) {
      return 'Ingen tilgang';
    }
    return '';
  }

  SafeArea _buildTitle(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            "SARSys",
            style: _toStyle(context, 42, FontWeight.bold),
          ),
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
        height: 200.0,
        width: 200.0,
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

  Widget _buildSecure(UserBloc bloc) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          if (_verifyPin) {
            if (!_securePin) {
              _securePin = true;
              _pinController.clear();
            }
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _toPinText(),
                style: _toStyle(context, 22, FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              _buildPinInput(
                setState: setState,
              ),
              Flexible(
                child: _verifyPin
                    ? _buildSecureAction(bloc, enabled: _pinComplete)
                    : _buildNewPinAction(bloc, setState, enabled: !_wrongPin && _pinComplete),
              ),
            ],
          );
        },
      );

  String _toPinText() => _verifyPin
      ? (_wrongPin ? 'Riktig pinkode er $_pin' : 'Pinkode er riktig')
      : changePin ? 'Endre pin' : 'Oppgi ny pinkode';

  Widget _buildNewPinAction(UserBloc bloc, StateSetter setState, {bool enabled}) => _buildAction(
        'Velg',
        () {
          _pinComplete = false;
          _focusNode.requestFocus();
          setState(() => _verifyPin = true);
        },
        enabled: enabled,
      );

  Widget _buildSecureAction(UserBloc bloc, {bool enabled}) => _buildAction(
        'Lagre',
        () async {
          await bloc.secure(
            Security.fromPin(_pin),
          );
          _resetPin();
          _securePending = true;
          // If already in state 'UserUnlocked' no event will be fired.
          if (bloc.isUnlocked) {
            Navigator.pushReplacementNamed(context, 'incident/list');
          }
        },
        enabled: enabled,
      );

  void _resetPin() {
    _pin = "";
    _username = "";
    _wrongPin = false;
    _verifyPin = false;
    _securePin = false;
    _pinComplete = false;
  }

  bool get changePin => LoginType.changePin == widget.type;

  List<Widget> _buildUnlock(UserBloc bloc) => [
        Text(
          'Lås opp med pinkode',
          style: _toStyle(context, 22, FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        _buildPinInput(),
        _buildUnlockAction(bloc),
      ];

  Widget _buildUnlockAction(UserBloc bloc) => _buildAction(
        'Lås opp',
        () => bloc.unlock(pin: _pin),
      );

  Widget _buildPinInput({StateSetter setState}) => Padding(
        padding: const EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
        child: PinCodeTextField(
          length: 4,
          obsecureText: false,
          autoFocus: true,
          animationType: AnimationType.fade,
          shape: PinCodeFieldShape.box,
          textInputType: TextInputType.numberWithOptions(),
          animationDuration: Duration(milliseconds: 300),
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 50,
          activeFillColor: color,
          controller: _pinController,
          focusNode: _focusNode,
          onChanged: (value) {
            _pinComplete = value.length == 4;
            if (!_pinComplete) {
              if (setState != null) {
                setState(() {});
              }
            }
            _wrongPin = _pin != value;
          },
          onCompleted: (value) {
            if (!_verifyPin) {
              _pin = value;
            }
            _pinComplete = true;
            _pinController.clear();
            if (setState != null) {
              setState(() {});
            }
          },
        ),
      );

  Widget _buildAuthenticate(UserBloc bloc) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Logg deg på med din organisasjonskonto',
            style: _toStyle(context, 22, FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          _buildEmailInput(),
          Flexible(
            child: _buildAuthenticateAction(bloc),
          ),
        ],
      );

  Widget _buildEmailInput() => Padding(
        padding: const EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
        child: TextFormField(
          maxLines: 1,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          autofocus: false,
          scrollPadding: EdgeInsets.all(90),
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            hintText: 'Påloggingsadresse',
          ),
          validator: (value) => value.isEmpty ? 'Påloggingsadresse må fylles ut' : null,
          onSaved: (value) => _username = value,
        ),
      );

  Widget _buildAuthenticateAction(UserBloc bloc) => _buildAction(
        'Logg på',
        () => bloc.authenticate(username: _username),
      );

  Widget _buildAction(String label, Function() onPressed, {bool enabled = true}) => Padding(
        padding: EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 0.0),
        child: SizedBox(
          height: 48,
          child: RaisedButton(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
            color: Color.fromRGBO(00, 41, 73, 1),
            child: Text(label, style: TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: enabled
                ? () {
                    if (_validateAndSave()) {
                      FocusScopeNode currentFocus = FocusScope.of(context);
                      if (!currentFocus.hasPrimaryFocus) {
                        currentFocus.unfocus();
                      }
                      onPressed();
                    }
                  }
                : null,
          ),
        ),
      );
}
