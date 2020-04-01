import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:catcher/catcher_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum LoginType {
  automatic,
  changePin,
  switchUser,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key key, this.type = LoginType.automatic, this.returnTo}) : super(key: key);
  final LoginType type;
  final String returnTo;

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
  bool _popWhenReady = false;

  UserError _lastError;

  AnimationController _animController;
  StreamSubscription<UserState> _subscription;

  ScrollController _scrollController = ScrollController();
  FocusNode _focusNode = FocusNode();
  _PinTextEditingController _pinController = _PinTextEditingController();

  bool get automatic => LoginType.automatic == widget.type;
  bool get changePin => LoginType.changePin == widget.type;
  bool get switchUser => LoginType.switchUser == widget.type;

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    UserBloc bloc = _toBloc(context);
    return StreamBuilder<UserState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          return Scaffold(
            backgroundColor: Colors.grey[300],
            appBar: !automatic && bloc.isReady ? _buildAppBar(context) : null,
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
                      child: _buildBody(context, bloc),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
        title: Text(automatic ? 'Logg på' : changePin ? 'Endre pin' : 'Bytt bruker'),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => _popTo(context),
        ));
  }

  Widget _buildBody(BuildContext context, UserBloc bloc) {
    return AnimatedCrossFade(
      duration: Duration(microseconds: 300),
      crossFadeState: _inProgress(bloc) ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      firstChild: _buildProgress(context),
      secondChild: _buildForm(context, bloc),
    );
  }

  bool _inProgress(UserBloc bloc) =>
      bloc.isReady && !(changePin || switchUser) || bloc?.currentState?.isPending() == true;

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
                ..._buildFields(bloc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFields(UserBloc bloc) {
    final isError = _isError(bloc);
    var fields = isError ? [_buildErrorText(bloc)] : <Widget>[];
    if (isError) {
      _pinController.clear();
    }

    if (bloc.isAuthenticated) {
      if (changePin || !bloc.isSecured) {
        return fields..add(_buildSecure(bloc));
      } else if (bloc.isLocked) {
        _pinController.clear();
        return fields..addAll(_buildUnlock(bloc));
      }
    }
    return fields..add(_buildAuthenticate(bloc));
  }

  bool _isError(UserBloc bloc) => bloc.currentState is UserException;

  Widget _buildErrorText(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          _toError(bloc),
          style: _toStyle(
            context,
            16,
            FontWeight.bold,
            color: Colors.redAccent,
          ),
          textAlign: TextAlign.center,
        ),
      );

  String _toError(UserBloc bloc) {
    if (bloc.currentState is UserUnauthorized) {
      return bloc.isSecured ? bloc.isLocked ? 'Feil pinkode' : 'Feil brukernavn eller passord' : 'Du må logge inn';
    } else if (bloc.currentState is UserForbidden) {
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
            children: [
              _buildFullName(bloc),
              Text(
                _toPinText(),
                style: _toStyle(context, 22, FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              _buildPinInput(
                bloc,
                setState: setState,
              ),
              _verifyPin
                  ? _buildSecureAction(bloc, enabled: _pinComplete)
                  : _buildNewPinAction(bloc, setState, enabled: !_wrongPin && _pinComplete),
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
        'Endre',
        () async {
          try {
            await bloc.secure(
              Security.fromPin(_pin),
            );
            _resetPin();
            _popTo(context);
          } on Exception {/* Is handled by StreamBuilder */}
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

  List<Widget> _buildUnlock(UserBloc bloc) => [
        _buildFullName(bloc),
        Text(
          'Lås opp med pinkode',
          style: _toStyle(context, 22, FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        _buildPinInput(bloc),
      ];

  Widget _buildFullName(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          bloc.user.fullName,
          style: _toStyle(context, 16, FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );

  Widget _buildPinInput(UserBloc bloc, {StateSetter setState}) => Container(
        constraints: BoxConstraints(minWidth: 215, maxWidth: 215),
        padding: const EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
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
          textInputType: TextInputType.numberWithOptions(),
          animationDuration: Duration(milliseconds: 300),
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 50,
          activeFillColor: color,
          controller: _pinController,
          focusNode: _focusNode,
          onChanged: (value) => _onChanged(
            value,
            setState,
            bloc,
          ),
          onCompleted: (value) => _onCompleted(
            value,
            setState,
          ),
        ),
      );

  void _onCompleted(String value, StateSetter setState) {
    if (!_verifyPin) {
      _pin = value;
    }
    _pinComplete = true;
    _pinController.clear();
    if (setState != null) {
      setState(() {});
    }
  }

  void _onChanged(String value, StateSetter setState, UserBloc bloc) async {
    _pinComplete = value.length == 4;
    _wrongPin = _pin != value;
    // Evaluate pin if not complete or if not changing and is wrong
    if (!_pinComplete || !changePin && _pinComplete && _wrongPin) {
      if (setState != null) {
        setState(() {});
      }
    }
    // Automatic approval?
    else if (bloc.isSecured && !(changePin || _wrongPin)) {
      try {
        await bloc.unlock(pin: _pin);
      } on Exception {/* Is handled by StreamBuilder */}
    }
  }

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
        'Fortsett',
        () async {
          try {
            _popWhenReady = true;
            await bloc.authenticate(username: _username);
          } on Exception {/* Is handled by StreamBuilder */}
        },
      );

  Widget _buildAction(String label, Function() onPressed, {bool enabled = true}) => Container(
        constraints: BoxConstraints(
          minHeight: 72,
          maxHeight: 72,
          minWidth: 215,
        ),
        child: Padding(
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
        ),
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
      case UserAuthenticated:
        // Only close login if user is authenticated and app is secured with pin
        if (bloc.isReady && (automatic || _popWhenReady)) {
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

  Future<Object> _popTo(BuildContext context) => Navigator.pushReplacementNamed(
        context,
        widget.returnTo ?? 'incident/list',
      );

  @override
  void dispose() {
    _subscription?.cancel();
    _animController?.dispose();
    _scrollController?.dispose();
    _pinController.release().dispose();
    _animController = null;
    _scrollController = null;
    /* _focusNode is disposed automatically by PinCodeTextField */
    _focusNode = null;
    _pinController = null;
    super.dispose();
  }
}

class _PinTextEditingController extends TextEditingController {
  bool released = false;

  TextEditingController release() {
    released = true;
    return this;
  }

  @override
  void dispose() {
    if (released) {
      super.dispose();
    }
  }
}
