import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => new LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = new GlobalKey<FormState>();

  String _username = "";
  String _password = "";
  StreamSubscription<bool> subscription;

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
        Navigator.pushReplacementNamed(context, 'incidents');
      }
    });
    return bloc;
  }

  @override
  void dispose() {
    super.dispose();
    if (subscription != null) {
      subscription.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: Container(
        color: Colors.white,
        child: Container(
          padding: EdgeInsets.all(16.0),
          constraints: BoxConstraints(maxWidth: 400.0),
          child: _buildBody(context),
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
              padding: EdgeInsets.all(16.0),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  Center(child: CircularProgressIndicator()),
                  // Logo
                  Padding(
                    padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      radius: 80.0,
                      child: Image.asset('assets/logo.png'),
                    ),
                  ),
                  Center(
                    child: Text("Logger inn, vennligst vent"),
                  )
                ],
              ),
            ),
            secondChild: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      SafeArea(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 32.0),
                            child: Text(
                              "SarSys",
                              style: Theme.of(context).textTheme.title.copyWith(
                                    fontSize: 32,
                                    color: Color(0xFF0d2149),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      // Logo
                      Padding(
                        padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0),
                        child: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 40.0,
                          child: Image.asset('assets/logo.png'),
                        ),
                      ),
                      if (snapshot.hasData && snapshot.data is UserException)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _toError(snapshot.data),
                              style: TextStyle(color: Colors.red, height: 1.0, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      _buildEmailInput(),
                      _buildPasswordInput(),
                      _buildPrimaryButton(bloc),
                    ],
                  ),
                )),
          );
        });
  }

  Widget _buildEmailInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        autofocus: false,
        textCapitalization: TextCapitalization.none,
        decoration: new InputDecoration(
            hintText: 'Brukernavn',
            icon: new Icon(
              Icons.person,
              color: Colors.grey,
            )),
        validator: (value) => value.isEmpty ? 'Brukernavn må fylles ut' : null,
        onSaved: (value) => _username = value,
      ),
    );
  }

  Widget _buildPasswordInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        obscureText: true,
        autofocus: false,
        decoration: new InputDecoration(
          hintText: 'Passord',
          icon: new Icon(
            Icons.lock,
            color: Colors.grey,
          ),
        ),
        validator: (value) => value.isEmpty ? 'Passord må fylles ut' : null,
        onSaved: (value) => _password = value,
      ),
    );
  }

  Widget _buildPrimaryButton(UserBloc bloc) {
    return new Padding(
        padding: EdgeInsets.fromLTRB(0.0, 24.0, 0.0, 0.0),
        child: SizedBox(
          height: 40.0,
          width: 60.0,
          child: RaisedButton(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
            color: Color.fromRGBO(00, 41, 73, 1),
            child: new Text('Logg inn', style: new TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: () {
              if (_validateAndSave()) {
                bloc.login(_username, _password);
              }
            },
          ),
        ));
  }

  String _toError(UserException state) {
    if (state is UserUnauthorized) {
      return 'Feil brukernavn eller passord';
    } else if (state is UserForbidden) {
      return 'Ingen tilgang';
    }
    return '';
  }
}
