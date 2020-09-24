import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasscodePage extends StatefulWidget {
  PasscodePage({
    Key key,
    @required this.operation,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;

  @override
  _PasscodePageState createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
  final _formKey = new GlobalKey<FormState>();

  String _passcode = "";

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StreamBuilder<UserState>(
            stream: context.bloc<UserBloc>(),
            builder: (context, snapshot) {
              var forbidden = _passcode.length > 0 && snapshot.hasData && snapshot.data.isError();
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    forbidden
                        ? "Feil tilgangskode, forsøk igjen"
                        : "${[
                            translateOperationType(widget.operation.type),
                            widget.operation.name
                          ].join(' ').trim()} krever tilgangskode",
                    style: Theme.of(context).textTheme.headline6,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          Divider(),
          _buildPasscodeInput(),
        ],
      ),
    );
  }

  Widget _buildPasscodeInput() {
    return Align(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
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
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          validator: (value) => value.isEmpty ? 'Tilgangskode må fylles ut' : null,
          onSaved: (value) => _passcode = value,
          onFieldSubmitted: (_) => _unlock(context.bloc<UserBloc>()),
        ),
      ),
    );
  }

  Future _unlock(UserBloc bloc) async {
    if (_validateAndSave()) {
      if (await bloc.authorize(widget.operation, _passcode)) {
        await joinOperation(widget.operation);
        Navigator.pushReplacementNamed(context, UserScreen.ROUTE_OPERATION);
      }
    }
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
