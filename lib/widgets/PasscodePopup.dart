import 'dart:async';

import 'package:SarSys/blocs/IncidentBloc.dart';
import 'package:SarSys/blocs/UserBloc.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasscodeRoute extends PopupRoute {
  final Incident incident;
  final _formKey = new GlobalKey<FormState>();

  String _passcode = "";
  StreamSubscription<bool> subscription;

  PasscodeRoute(this.incident);

  @override
  bool get maintainState => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black.withOpacity(0.6);

  @override
  String get barrierLabel => "Tap to cancel passcode popup";

  @override
  Duration get transitionDuration => Duration(microseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    UserBloc bloc = _handle(context);
    return Center(
      child: Material(
        child: DecoratedBox(
          child: _buildBody(context, bloc),
          decoration: BoxDecoration(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserBloc bloc) {
    return FractionallySizedBox(
      widthFactor: 0.9,
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              StreamBuilder<UserState>(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var forbidden = _passcode.length > 0 && snapshot.hasData && snapshot.data is UserException;
                  return Center(
                    child: Text(
                      forbidden
                          ? "Feil tilgangskode, forsøk igjen"
                          : "Skriv inn tilgangskode for ${incident.reference ?? incident.name}",
                      style: TextStyle(fontSize: 16.0, color: forbidden ? Colors.red : Colors.black),
                    ),
                  );
                },
              ),
              _buildPasscodeInput(),
              _buildPrimaryButton(bloc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeInput() {
    return Padding(
      padding: EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: TextFormField(
        maxLines: 1,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Tilgangscode',
          icon: Icon(
            Icons.lock,
            color: Colors.grey,
          ),
        ),
        validator: (value) => value.isEmpty ? 'Tilgangskode må fylles ut' : null,
        onSaved: (value) => _passcode = value,
      ),
    );
  }

  Widget _buildPrimaryButton(UserBloc bloc) {
    return Padding(
        padding: EdgeInsets.fromLTRB(0.0, 25.0, 0.0, 0.0),
        child: SizedBox(
          width: 88.0,
          child: RaisedButton(
            elevation: 2.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
            color: Color.fromRGBO(00, 41, 73, 1),
            child: Text('LÅS OPP', style: TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: () {
              if (_validateAndSave()) {
                bloc.authorize(incident, _passcode);
              }
            },
          ),
        ));
  }

  UserBloc _handle(BuildContext context) {
    final bloc = BlocProvider.of<UserBloc>(context);
    if (subscription != null) {
      subscription.cancel();
    }
    subscription = bloc.authorized(incident).listen((isAuthorized) {
      if (isAuthorized) {
        final bloc = BlocProvider.of<IncidentBloc>(context);
        bloc.select(incident.id);
        Navigator.pushReplacementNamed(context, 'incident');
      }
    });
    return bloc;
  }

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }
}
