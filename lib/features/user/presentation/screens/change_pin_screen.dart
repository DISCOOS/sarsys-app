import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ChangePinScreen extends StatefulWidget {
  static const ROUTE = 'change/pin';

  const ChangePinScreen({
    Key key,
    this.returnTo,
    this.popOnClose = false,
  }) : super(key: key);
  final String returnTo;
  final bool popOnClose;

  @override
  ChangePinScreenState createState() => ChangePinScreenState();
}

class ChangePinScreenState extends State<ChangePinScreen> with TickerProviderStateMixin {
  static const color = Color(0xFF0d2149);
  final _formKey = GlobalKey<FormState>();

  /// Next pin
  String _pin;

  /// Forces user to enter current pin before changing it
  bool _verifyPin = false;

  /// Asks user to enter new pin
  bool _newPin = false;

  /// Asks user to confirm new pin
  bool _confirmPin = false;

  /// Test result for each digit entered
  bool _wrongPin = false;

  /// Change pin
  bool _changePin = false;

  /// Indicates that all four digits are entered
  bool get _pinComplete => _pinController?.text?.length == 1;

  /// Securing with pin is in progress
  bool _isSecuring = false;

  AnimationController _animController;

  FocusNode _focusNode;
  ScrollController _scrollController;
  TextEditingController _pinController;

  TextTheme textTheme;
  TextStyle titleStyle;
  TextStyle emailStyle;

  UserBloc _bloc;

  bool _validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  @override
  void initState() {
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _pinController = TextEditingController();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _bloc = context.bloc<UserBloc>();
    _verifyPin = _bloc.isSecured;
    _newPin = !_verifyPin;
//    _pin = null;
//    _wrongPin = false;
//    _changePin = false;
//    _confirmPin = false;
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    textTheme ??= Theme.of(context).textTheme;
    titleStyle ??= textTheme.subtitle2.copyWith(
      fontSize: SizeConfig.safeBlockVertical * 2.5,
    );
    emailStyle ??= textTheme.bodyText2.copyWith(
      color: textTheme.caption.color,
      fontSize: SizeConfig.safeBlockVertical * 2.1,
    );

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: _bloc.isSecured ? _buildAppBar(context) : null,
      body: SafeArea(
        child: Center(
          child: FractionallySizedBox(
            alignment: Alignment.center,
            widthFactor: 0.90,
            heightFactor: 0.90,
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
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
        title: Text(
          'Endre pin',
        ),
        centerTitle: false,
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => _popTo(context),
        ));
  }

  Widget _buildBody(BuildContext context) {
    _requesFocus();

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
                ..._buildFields(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _requesFocus() {
    if (!(_pinComplete || _isPopped || _isSecuring)) {
      _focusNode.requestFocus();
    }
  }

  List<Widget> _buildFields() {
    final isError = _isError();
    var fields = isError ? [_buildErrorText()] : <Widget>[];
    if (isError) {
      _pinController.clear();
    }
    return fields..add(_buildSecure());
  }

  bool _isError() => _bloc.state.isError();

  Widget _buildErrorText() => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          'Feil pinkode',
          style: _toStyle(
            context,
            16,
            FontWeight.bold,
            color: Colors.redAccent,
          ),
          textAlign: TextAlign.center,
        ),
      );

  Widget _buildTitle(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Text(
          "SARSys",
          style: _toStyle(context, 42, FontWeight.bold),
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
      Theme.of(context).textTheme.headline6.copyWith(
            fontSize: size,
            color: color,
            fontWeight: weight,
          );

  Image _buildIcon() => Image.asset(
        'assets/images/sar-team-2.png',
        height: SizeConfig.blockSizeVertical * 20 * (SizeConfig.isPortrait ? 1 : 2.5),
        width: SizeConfig.blockSizeHorizontal * 40 * (SizeConfig.isPortrait ? 1 : 2.5),
        alignment: Alignment.center,
      );

  Widget _buildSecure() => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildFullName(_bloc.user),
              ),
              Text(
                _toPinText(),
                style: _toPinTextStyle(context),
                textAlign: TextAlign.center,
              ),
              _buildPinInput(
                setState: setState,
              ),
              _buildSecureAction(enabled: _changePin),
            ],
          );
        },
      );

  TextStyle _toPinTextStyle(BuildContext context) => _toStyle(
        context,
        22,
        FontWeight.bold,
        color: _wrongPin && _pinComplete ? Colors.red : null,
      );

  String _toPinText() {
    if (_verifyPin) {
      return _wrongPin ? 'Feil pin' : 'Oppgi din pinkode';
    } else if (_confirmPin) {
      return 'Bekreft ny pinkode er $_pin';
    } else if (_changePin) {
      return _bloc.isSecured ? 'Endre til ny pinkode' : 'Opprett pinkode';
    }
    return 'Oppgi ny pinkode';
  }

  Widget _buildSecureAction({bool enabled}) => buildAction(
        _bloc.isSecured ? 'ENDRE' : 'OPPRETT',
        () async {
          try {
            _isSecuring = true;
            await _bloc.secure(
              _pin,
              locked: false,
            );
            _popTo(context);
          } on Exception {
            /* Is handled by StreamBuilder */
            _isSecuring = false;
          }
        },
        enabled: enabled,
      );

  Widget _buildFullName(User user) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              user.fullName,
              style: titleStyle,
            ),
          ),
          Flexible(
            child: Text(
              user.email,
              style: emailStyle,
            ),
          ),
        ],
      );

  Widget _buildPinInput({StateSetter setState}) => Container(
        constraints: BoxConstraints(minWidth: 215, maxWidth: 215),
        padding: const EdgeInsets.only(top: 24.0),
        child: PinCodeTextField(
          length: 4,
          autoFocus: true,
          obsecureText: false,
          enabled: !_changePin,
          inputFormatters: [
            WhitelistingTextInputFormatter(RegExp('[0-9]')),
          ],
          textInputAction: TextInputAction.send,
          animationType: AnimationType.fade,
          shape: PinCodeFieldShape.box,
          autoDismissKeyboard: false,
          textInputType: TextInputType.numberWithOptions(),
          animationDuration: Duration(milliseconds: 300),
          borderRadius: BorderRadius.circular(5),
          fieldHeight: 50,
          fieldWidth: 50,
          activeFillColor: color,
          focusNode: _focusNode,
          controller: _pinController,
          autoDisposeController: false,
          autoDisposeFocusNode: false,
          onChanged: (_) {},
          onCompleted: (value) => _onCompleted(
            value,
            setState,
          ),
        ),
      );

  void _onCompleted(String value, StateSetter setState) async {
    if (_verifyPin) {
      _wrongPin = _bloc.user.security.pin != value;
      _verifyPin = _wrongPin;
      _newPin = !_wrongPin;
    } else if (_newPin) {
      _pin = value;
      _newPin = false;
      _confirmPin = true;
    } else if (_confirmPin) {
      _wrongPin = _pin != value;
      _confirmPin = _wrongPin;
      _changePin = !_confirmPin;
    }
    if (!(_changePin || _isPopped)) {
      _pinController.clear();
      _focusNode.requestFocus();
    }
    if (setState != null) {
      setState(() {});
    }
  }

  Widget buildAction(
    String label,
    Function() onPressed, {
    bool enabled = true,
    Type type = RaisedButton,
    Widget icon,
    Color color = const Color.fromRGBO(00, 41, 73, 1),
    bool validate = true,
  }) =>
      Container(
        constraints: BoxConstraints(
          minHeight: 56,
          maxHeight: 56,
          minWidth: 215,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: _buildButton(
            color,
            label,
            enabled,
            onPressed,
            type,
            icon: icon,
            validate: validate,
          ),
        ),
      );

  Widget _buildButton(
    Color color,
    String label,
    bool enabled,
    onPressed(),
    Type type, {
    Widget icon,
    bool validate = true,
  }) {
    if (type == OutlineButton) {
      return _buildOutlineButton(
        label,
        enabled,
        onPressed,
        icon: icon,
        validate: validate,
      );
    }
    return _buildRaisedButton(
      color,
      label,
      enabled,
      onPressed,
      icon: icon,
      validate: validate,
    );
  }

  Widget _buildRaisedButton(
    Color color,
    String label,
    bool enabled,
    onPressed(), {
    Widget icon,
    bool validate = true,
  }) =>
      RaisedButton(
        color: color,
        elevation: 2.0,
        padding: icon == null ? null : EdgeInsets.only(left: 16.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.8, color: Colors.white),
                textAlign: icon == null ? TextAlign.center : TextAlign.left,
              ),
            ),
          ],
        ),
        onPressed: enabled ? () => _onActionPressed(validate, onPressed) : null,
      );

  void _onActionPressed(bool validate, onPressed()) {
    if (!validate || _validateAndSave()) {
      FocusScopeNode currentFocus = FocusScope.of(context);
      if (!currentFocus.hasPrimaryFocus) {
        currentFocus.unfocus();
      }
      onPressed();
    }
  }

  Widget _buildOutlineButton(
    String label,
    bool enabled,
    onPressed(), {
    Widget icon,
    bool validate = true,
  }) =>
      OutlineButton(
        padding: icon == null ? null : EdgeInsets.only(left: 16.0),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Text(
              label,
              style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.8),
              textAlign: icon == null ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
        onPressed: enabled ? () => _onActionPressed(validate, onPressed) : null,
      );

  bool _isPopped = false;

  void _popTo(BuildContext context) {
    if (!_isPopped) {
      _isPopped = true;
      if (widget.popOnClose) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(
          context,
          widget.returnTo ?? OperationsScreen.ROUTE,
        );
      }
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    _scrollController?.dispose();
    _focusNode.dispose();
    _pinController.dispose();
    _animController = null;
    _scrollController = null;
    _focusNode = null;
    _pinController = null;
    super.dispose();
  }
}
