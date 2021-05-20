import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/core/presentation/widgets/descriptions.dart';

typedef PasscodeCallback = Future<bool> Function(Operation operation, String passcode);

class PasscodePage extends StatefulWidget {
  PasscodePage({
    Key key,
    @required this.operation,
    @required this.onComplete,
    @required this.onAuthorize,
    this.requireCommand = false,
    this.onVerify,
  }) : super(key: key) {
    assert(operation != null, 'Operation is required');
  }

  final Operation operation;
  final bool requireCommand;
  final ValueNotifier<bool> onVerify;
  final PasscodeCallback onAuthorize;
  final ValueChanged<bool> onComplete;

  @override
  _PasscodePageState createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _focusNode = FocusNode();

  String _passcode = '';
  bool _verifying = false;

  @override
  void didUpdateWidget(PasscodePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onVerify != oldWidget.onVerify) {
      oldWidget.onVerify?.removeListener(_verifyPassCode);
    }
    widget.onVerify?.addListener(_verifyPassCode);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            selected: true,
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: () => widget.onComplete(false),
            ),
            title: Text(
              'Oppgi tilgangskode',
              style: Theme.of(context).textTheme.headline6,
            ),
            subtitle: Text(
              "${[translateOperationType(widget.operation.type), widget.operation.name].join(' ').trim()}",
              style: Theme.of(context).textTheme.subtitle1,
              textAlign: TextAlign.left,
            ),
          ),
          Divider(),
          StreamBuilder<UserState>(
            stream: context.bloc<UserBloc>(),
            initialData: context.bloc<UserBloc>().state,
            builder: (context, snapshot) {
              final forbidden = _passcode.length > 0 && snapshot.hasData && snapshot.data.isError();
              final authorization = context.bloc<UserBloc>().getAuthorization(widget.operation);
              final command = _verifying && !authorization.withCommanderCode && widget.requireCommand;
              return _buildPasscodeInput(
                errorText: forbidden || command
                    ? (command ? 'Du må oppgi tilgangskode for aksjonsledelse' : 'Feil tilgangskode, forsøk igjen')
                    : null,
              );
            },
          ),
          _buildPasscodeDescription(),
        ],
      ),
    );
  }

  Widget _buildPasscodeInput({
    String errorText = null,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: TextFormField(
        maxLines: 1,
        autofocus: true,
        obscureText: true,
        autocorrect: true,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Tilgangskode',
          icon: Icon(
            Icons.lock,
            color: Colors.grey,
          ),
          errorText: errorText,
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
        onFieldSubmitted: (_) => _verifyPassCode(),
      ),
    );
  }

  Widget _buildPasscodeDescription() {
    return Padding(
      padding: EdgeInsets.all(24.0),
      child: PasscodeDescription(
        requireCommand: widget.requireCommand,
      ), // your column
    );
  }

  void _verifyPassCode() async {
    if ((widget.onVerify == null || widget.onVerify.value) && _validateAndSave()) {
      _verifying = true;
      if (await widget.onAuthorize(widget.operation, _passcode)) {
        widget.onComplete(true);
        return;
      }
    }
    _focusNode.requestFocus();
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
