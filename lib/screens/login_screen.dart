import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends RouteWriter<LoginScreen, void> with SingleTickerProviderStateMixin {
  static const color = Color(0xFF0d2149);
  final _formKey = new GlobalKey<FormState>();

  String _username = "";
  StreamSubscription<bool> subscription;
  AnimationController _controller;

  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();
  }

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
    if (subscription != null) {
      subscription.cancel();
    }
    subscription = bloc.authenticated.listen((isAuthenticated) {
      if (isAuthenticated) {
        Navigator.pushReplacementNamed(context, 'incident/list');
      }
    });
    return bloc;
  }

  @override
  void dispose() {
    subscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
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
            crossFadeState: snapshot.hasData && snapshot.data.isAuthenticating()
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Container(
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
            ),
            secondChild: Container(
                padding: EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              "SARSys",
                              style: _toStyle(context, 42, FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      // Logo
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildIcon(),
                      ),
                      if (snapshot.hasData && snapshot.data is UserException)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _toError(snapshot.data),
                            style: TextStyle(
                              color: Colors.red,
                              height: 1.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        'Logg deg på med din organisasjonskonto',
                        style: _toStyle(context, 22, FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      _buildEmailInput(),
                      _buildPrimaryButton(bloc),
                    ],
                  ),
                )),
          );
        });
  }

  TextStyle _toStyle(BuildContext context, double size, FontWeight weight) =>
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

  Widget _buildEmailInput() => Padding(
        padding: const EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
        child: new TextFormField(
          maxLines: 1,
          keyboardType: TextInputType.emailAddress,
          autofocus: false,
          scrollPadding: EdgeInsets.all(90),
          textCapitalization: TextCapitalization.none,
          decoration: new InputDecoration(
            hintText: 'Påloggingsadresse',
          ),
          validator: (value) => value.isEmpty ? 'Påloggingsadresse må fylles ut' : null,
          onSaved: (value) => _username = value,
        ),
      );

  Widget _buildPrimaryButton(UserBloc bloc) => Padding(
        padding: EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
        child: SizedBox(
          height: 40.0,
          width: 60.0,
          child: RaisedButton(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
            color: Color.fromRGBO(00, 41, 73, 1),
            child: new Text('Logg på', style: new TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: () {
              if (_validateAndSave()) {
                FocusScopeNode currentFocus = FocusScope.of(context);
                if (!currentFocus.hasPrimaryFocus) {
                  currentFocus.unfocus();
                }
                bloc.login(username: _username);
              }
            },
          ),
        ),
      );

  String _toError(UserException state) {
    if (state is UserUnauthorized) {
      return 'Feil brukernavn eller passord';
    } else if (state is UserForbidden) {
      return 'Ingen tilgang';
    }
    return '';
  }
}
