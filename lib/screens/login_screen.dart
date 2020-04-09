import 'dart:async';

import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:SarSys/models/Security.dart';
import 'package:SarSys/models/User.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/services/service_response.dart';
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

  User _user;
  String _pin = "";
  String _username = "";

  /// Login flow
  /// Indicates that new user was requested
  bool _newUser = false;

  /// Change pin: state 1
  /// Forces user to enter current pin before changing it
  bool get verifyPin => changePin && !_newPin;

  /// Change pin: state 2
  /// Enter New pin step
  bool _newPin = false;

  /// Change pin: state 3
  /// Confirm new pin step
  bool _confirmPin = false;

  /// Change pin: state 1 and 3
  /// Test result for each digit entered
  bool _wrongPin = false;

  /// All flows
  /// Indicates that previously entered pin was cleared
  bool _pinCleared = false;

  /// All flows
  /// Indicates that all four digits are entered
  bool _pinComplete = false;

  /// All flows
  /// State for async result processing from [UserState] stream
  bool _popWhenReady = false;

  UserError _lastError;

  AnimationController _animController;
  StreamSubscription<UserState> _subscription;

  FocusNode _focusNode;
  ScrollController _scrollController;
  _PinTextEditingController _pinController;

  bool get newUser => _newUser;
  bool get automatic => LoginType.automatic == widget.type;
  bool get changePin => LoginType.changePin == widget.type;
  bool get switchUser => LoginType.switchUser == widget.type;

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
    _pinController = _PinTextEditingController();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _bloc = _toBloc(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    textTheme ??= Theme.of(context).textTheme;
    titleStyle ??= textTheme.subhead.copyWith(
      fontSize: SizeConfig.safeBlockVertical * 2.5,
    );
    emailStyle ??= textTheme.body1.copyWith(
      color: textTheme.caption.color,
      fontSize: SizeConfig.safeBlockVertical * 2.1,
    );

    return StreamBuilder<UserState>(
        stream: _bloc.state,
        builder: (context, snapshot) {
          return Scaffold(
            backgroundColor: Colors.grey[300],
            appBar: !automatic && _bloc.isReady ? _buildAppBar(context) : null,
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
                        child: _buildBody(context, _bloc),
                      ),
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
        title: Text(
          automatic ? 'Logg på' : changePin ? 'Endre pin' : (newUser ? 'Ny bruker' : 'Bytt bruker'),
        ),
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

  Widget _buildDivider() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Stack(
        children: [
          Divider(),
          Center(
            child: Container(
              color: theme.colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'ELLER',
                style: theme.textTheme.caption,
              ),
            ),
          ),
        ],
      ),
    );
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
      Theme.of(context).textTheme.title.copyWith(
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
          _doClearPin();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: _buildFullName(bloc.user),
              ),
              Text(
                _toPinText(),
                style: _toPinTextStyle(context),
                textAlign: TextAlign.center,
              ),
              _buildPinInput(
                bloc,
                setState: setState,
              ),
              verifyPin || _confirmPin
                  ? _buildSecureAction(bloc, enabled: !_wrongPin && _pinComplete)
                  : _buildNewPinAction(bloc, setState, enabled: !_wrongPin && _pinComplete),
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

  void _doClearPin() {
    if (_confirmPin) {
      if (!_pinCleared) {
        _pinCleared = true;
        _pinController.clear();
      }
    }
  }

  String _toPinText() {
    if (verifyPin) {
      return _wrongPin ? 'Feil pin' : 'Oppgi din pinkode';
    }
    if (_confirmPin) {
      return _wrongPin ? 'Bekreft ny pinkode er $_pin' : 'Pinkode er bekreftet';
    }
    return changePin ? 'Endre din pinkode' : 'Oppgi din nye pinkode';
  }

  Widget _buildNewPinAction(UserBloc bloc, StateSetter setState, {bool enabled}) => _buildAction(
        'FORTSETT',
        () {
          _pinComplete = false;
          _focusNode.requestFocus();
          setState(() => _confirmPin = true);
        },
        enabled: enabled,
      );

  Widget _buildSecureAction(UserBloc bloc, {bool enabled}) => _buildAction(
        verifyPin ? 'BEKREFT' : 'OPPRETT',
        () async {
          try {
            if (verifyPin) {
              _pinComplete = false;
              _focusNode.requestFocus();
              _wrongPin = _pin != bloc.user?.security?.pin;
              setState(() {
                _pin = '';
                _pinController.clear();
                _newPin = !_wrongPin;
              });
            } else {
              await bloc.secure(_pin, locked: false);
            }
          } on Exception {/* Is handled by StreamBuilder */}
        },
        enabled: enabled,
      );

  List<Widget> _buildUnlock(UserBloc bloc) => [
        Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: _buildFullName(bloc.user),
        ),
        Text(
          'Lås opp med pinkode',
          style: _toStyle(context, 22, FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        _buildPinInput(bloc),
      ];

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

//  Widget _buildFullName(User user) => Padding(
//        padding: const EdgeInsets.only(bottom: 16.0),
//        child: Text(
//          user.fullName,
//          style: _toStyle(context, 16, FontWeight.bold),
//          textAlign: TextAlign.center,
//        ),
//      );

  Widget _buildPinInput(UserBloc bloc, {StateSetter setState}) => Container(
        constraints: BoxConstraints(minWidth: 215, maxWidth: 215),
        padding: const EdgeInsets.only(top: 24.0),
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
    if (!_confirmPin) {
      _pin = value;
    }
    _pinComplete = true;
    _pinController.clear();
    _wrongPin = _pin != value;
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

  Widget _buildAuthenticate(UserBloc bloc) => FutureBuilder<Organization>(
      future: FleetMapService().fetchOrganization(
        bloc.service.configBloc.config.organization,
      ),
      builder: (context, snapshot) {
        final org = snapshot.data;
        return snapshot.hasData
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Logg på med ${newUser ? 'ny' : 'din'} organisasjonskonto',
                    style: _toStyle(context, 18, FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (bloc.isPersonal || org.idpHints.contains('rodekors'))
                          _buildAction(
                            'MED RØDE KORS',
                            () => _authenticate(
                              bloc,
                              idpHint: 'rodekors',
                            ),
                            color: Colors.red[900],
                            icon: _toIcon(
                              SarSysIcons.rkh,
                              Colors.red[900],
                            ),
                            validate: false,
                          ),
                        if (bloc.isPersonal)
                          _buildAction(
                            'MED GOOGLE',
                            () => _authenticate(
                              bloc,
                              idpHint: 'google',
                            ),
                            icon: Padding(
                              padding: const EdgeInsets.only(right: 18.0),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                color: Colors.white,
                                child: Image.asset(
                                  'assets/images/google.png',
                                ),
                              ),
                            ),
                            type: OutlineButton,
                            validate: false,
                          ),
                        _buildDivider(),
                      ],
                    ),
                  ),
                  _buildUserInput(bloc),
                  Flexible(
                    child: _buildAuthenticateAction(bloc),
                  ),
                ],
              )
            : Container();
      });

  Padding _toIcon(IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(left: 8.0, right: 24.0),
        child: Container(
          padding: EdgeInsets.all(8).copyWith(left: 9),
          color: Colors.white,
          child: Icon(
            icon,
            size: 8.0,
            color: color,
          ),
        ),
      );

  Widget _buildUserInput(UserBloc bloc) =>
      bloc.securityMode == SecurityMode.shared ? _buildSharedUseInput(bloc) : _buildPrivateUseInput(bloc);

  Widget _buildPrivateUseInput(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: _buildEmailTextField(),
      );

  Widget _buildSharedUseInput(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: FutureBuilder<ServiceResponse<List<User>>>(
            future: bloc.service.loadAll(),
            builder: (context, snapshot) {
              return snapshot.data?.is200 == true
                  ? _newUser || snapshot.data.body.isEmpty
                      ? _buildEmailTextField()
                      : buildDropDownField<String>(
                          attribute: 'email',
                          isDense: false,
                          initialValue: _setUser(
                            bloc,
                            snapshot.data.body.first,
                          ),
                          items: _buildUserItems(
                            snapshot.data.body,
                          ),
                          onChanged: (value) {
                            final user = snapshot.data.body.firstWhere(
                              (user) => user.userId == value,
                              orElse: () => null,
                            );
                            _setUser(bloc, user);
                          },
                          validators: [],
                        )
                  : _buildEmailTextField();
            }),
      );

  String _setUser(UserBloc bloc, User user) {
    _user = user ?? bloc.user;
    _username = _user.uname;
    return _user.userId;
  }

  List<DropdownMenuItem<String>> _buildUserItems(List<User> users) {
    final items = users
        .map(
          (user) => DropdownMenuItem(
            value: user.userId,
            child: _buildFullName(user),
          ),
        )
        .toList();
    return items
      ..add(DropdownMenuItem(
        child: Stack(
          children: [
            OutlineButton(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.person_add),
                  Padding(
                    padding: EdgeInsets.only(left: SizeConfig.safeBlockHorizontal * 4),
                    child: Text('LEGG TIL NY BRUKER'),
                  ),
                ],
              ),
              onPressed: () {
                setState(() => _newUser = true);
              },
            ),
          ],
        ),
      ));
  }

  TextFormField _buildEmailTextField() => TextFormField(
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
      );

  Widget _buildAuthenticateAction(UserBloc bloc) => _buildAction(
        'FORTSETT',
        () async {
          await _authenticate(bloc);
        },
      );

  Future _authenticate(UserBloc bloc, {String idpHint}) async {
    try {
      _popWhenReady = true;
      await bloc.authenticate(
        username: _username,
        userId: _user?.userId,
        idpHint: idpHint,
      );
      if (bloc.isUnlocked) {
        await bloc.lock();
      }
    } on Exception {
      _newUser = false;
    }
  }

  Widget _buildAction(
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

  bool _isPopped = false;

  void _popTo(BuildContext context) {
    if (!_isPopped) {
      _isPopped = true;
      Navigator.pushReplacementNamed(
        context,
        widget.returnTo ?? 'incident/list',
      );
    }
  }

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
