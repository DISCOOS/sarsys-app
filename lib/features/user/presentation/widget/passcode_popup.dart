import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';

class PasscodeRoute extends PopupRoute {
  final Operation operation;
  final _formKey = new GlobalKey<FormState>();

  String _passcode = "";

  PasscodeRoute(this.operation);

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
    final bloc = context.bloc<UserBloc>();
    return Center(
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8.0),
        child: _buildBody(context, bloc),
      ),
    );
  }

  Widget _buildBody(BuildContext context, UserBloc bloc) {
    return FractionallySizedBox(
      widthFactor: 0.8,
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StreamBuilder<UserState>(
                stream: bloc,
                builder: (context, snapshot) {
                  var forbidden = _passcode.length > 0 && snapshot.hasData && snapshot.data.isError();
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        forbidden
                            ? "Feil tilgangskode, forsøk igjen"
                            : "${operation.reference ?? operation.name} krever tilgangskode",
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: forbidden ? Colors.red : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
              Divider(),
              _buildPasscodeInput(),
              SizedBox(
                height: 16,
              ),
              _buildPrimaryButton(context, bloc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeInput() {
    return Align(
      child: Padding(
        padding: EdgeInsets.fromLTRB(0.0, 15.0, 8.0, 0.0),
        child: TextFormField(
          maxLines: 1,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tilgangskode',
            icon: Icon(
              Icons.lock,
              color: Colors.grey,
            ),
          ),
          validator: (value) => value.isEmpty ? 'Tilgangskode må fylles ut' : null,
          onSaved: (value) => _passcode = value,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, UserBloc bloc) {
    return RaisedButton(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
      color: Color.fromRGBO(00, 41, 73, 1),
      child: Text('LÅS OPP', style: TextStyle(fontSize: 20.0, color: Colors.white)),
      onPressed: () async {
        if (_validateAndSave()) {
          if (await bloc.authorize(operation, _passcode)) {
            await joinOperation(operation);
            Navigator.pushReplacementNamed(context, 'incident');
          }
        }
      },
    );
  }

  bool _validateAndSave() {
    final form = _formKey.currentState;
    final valid = form.validate();
    if (valid) {
      form.save();
    }
    return valid;
  }
}