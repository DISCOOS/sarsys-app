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
  String _nextPin = "";
  String _username = "";
  bool _wrongPin = false;
  bool _verifyPin = false;
  bool _securePin = false;
  bool _pinChanged = false;
  bool _pinComplete = false;
  AnimationController _controller;
  StreamSubscription<UserState> _subscription;

  TextEditingController _pinController;

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
          if (bloc.isReady && LoginType.automatic == widget.type || _pinChanged) {
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
    _controller?.dispose();
    _controller = null;
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
      bloc.isReady || snapshot.hasData && (snapshot.data.isPending());

  Container _buildProgress(BuildContext context) {
    _controller ??= AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();

    return Container(
      padding: EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Text(
            'Logger deg inn, vent litt',
            style: _toStyle(context, 16, FontWeight.w600),
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
    _controller?.stop(canceled: false);
    _pinController ??= TextEditingController();

    return Container(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            _buildTitle(context),
            // Logo
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildIcon(),
            ),
            ..._buildFields(snapshot, bloc),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields(AsyncSnapshot<UserState> snapshot, UserBloc bloc) {
    final isError = snapshot.hasData && snapshot.data is UserException;
    var fields = isError ? [_buildErrorText(snapshot, bloc)] : <Widget>[];

    if (changePin || !bloc.isSecured) {
      return fields..add(_buildSecure(bloc));
    } else if (bloc.isLocked) {
      return fields..addAll(_buildUnlock(bloc));
    }
    return fields..addAll(_buildAuthenticate(bloc));
  }

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
        height: 250.0,
        width: 250.0,
        alignment: Alignment.center,
      );

  Widget _buildRipple(Widget icon) => AnimatedBuilder(
        animation: CurvedAnimation(
          parent: _controller,
          curve: Curves.elasticInOut,
        ),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _buildCircle(250 + (24 * _controller.value)),
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
          color: Colors.lightBlue.withOpacity(_controller.value / 3),
        ),
      );

  Widget _buildSecure(UserBloc bloc) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          if (_verifyPin) {
            _wrongPin = _pin != _nextPin;
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

  String _toPinText() =>
      _verifyPin ? (_wrongPin ? 'Riktig pinkode er $_pin' : 'Pinkode er riktig') : 'Oppgi ny pinkode';

  Widget _buildNewPinAction(UserBloc bloc, StateSetter setState, {bool enabled}) => _buildAction(
        'Velg',
        () => setState(() => _verifyPin = true),
        enabled: enabled,
      );

  Widget _buildSecureAction(UserBloc bloc, {bool enabled}) => _buildAction(
        'Lagre',
        () {
          _pinChanged = changePin;
          bloc.secure(Security.fromPin(_pin));
        },
        enabled: enabled,
      );

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
          animationType: AnimationType.fade,
          shape: PinCodeFieldShape.box,
          animationDuration: Duration(milliseconds: 300),
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 50,
          activeFillColor: color,
          controller: _pinController,
          onChanged: (value) {
            if (_pinComplete) {
              _pinComplete = value.length == 4;
              if (setState != null) {
                setState(() {});
              }
            }
          },
          onCompleted: (value) {
            if (_verifyPin) {
              _nextPin = value;
            } else {
              _pin = value;
            }
            _pinComplete = true;
            if (setState != null) {
              setState(() {});
            }
          },
        ),
      );

  List<Widget> _buildAuthenticate(UserBloc bloc) => [
        Text(
          'Logg deg på med din organisasjonskonto',
          style: _toStyle(context, 22, FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        _buildEmailInput(),
        _buildAuthenticateAction(bloc),
      ];

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
      );
}
