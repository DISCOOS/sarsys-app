import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef PasscodeCallback = Future<bool> Function(Operation operation, String passcode);

class PasscodePage extends StatefulWidget {
  PasscodePage({
    Key key,
    @required this.operation,
    @required this.onComplete,
    @required this.onAuthorize,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;
  final PasscodeCallback onAuthorize;
  final ValueChanged<bool> onComplete;

  @override
  _PasscodePageState createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
  final _formKey = new GlobalKey<FormState>();

  String _passcode = '';

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StreamBuilder<UserState>(
            stream: context.bloc<UserBloc>(),
            initialData: context.bloc<UserBloc>().state,
            builder: (context, snapshot) {
              var forbidden = _passcode.length > 0 && snapshot.hasData && snapshot.data.isError();
              return Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => widget.onComplete(false),
                  ),
                  Text(
                    forbidden
                        ? "Feil tilgangskode, forsøk igjen"
                        : "${[
                            translateOperationType(widget.operation.type),
                            widget.operation.name
                          ].join(' ').trim()} krever tilgangskode",
                    style: Theme.of(context).textTheme.headline6,
                    textAlign: TextAlign.center,
                  ),
                ],
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
          autofocus: true,
          obscureText: true,
          autocorrect: true,
          decoration: InputDecoration(
            hintText: 'Tilgangskode',
            icon: Icon(
              Icons.lock,
              color: Colors.grey,
            ),
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
            ),
          ],
          validator: (value) => value.isEmpty ? 'Tilgangskode må fylles ut' : null,
          onSaved: (value) => _passcode = value,
          onChanged: (value) {
            if (value.isEmpty) {
              _passcode = '';
              setState(() {});
            }
          },
          onFieldSubmitted: (_) => _unlock(),
        ),
      ),
    );
  }

  Future _unlock() async {
    if (_validateAndSave()) {
      if (await widget.onAuthorize(widget.operation, _passcode)) {
        if (mounted) {
          widget.onComplete(true);
        }
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
