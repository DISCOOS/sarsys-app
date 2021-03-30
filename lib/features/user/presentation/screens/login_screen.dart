import 'dart:async';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:catcher/catcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/icons.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/data/services/user_service.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';

class LoginScreen extends StatefulWidget {
  static const ROUTE = 'login';

  const LoginScreen({
    Key key,
    this.returnTo,
  }) : super(key: key);
  final String returnTo;

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends RouteWriter<LoginScreen, void> with TickerProviderStateMixin {
  static const color = Color(0xFF0d2149);
  final _formKey = GlobalKey<FormState>();

  User _user;
  String _username = "";

  /// Indicates that new user was requested
  bool _newUser = false;

  /// State for async result processing from [UserState] stream
  bool _popWhenReady = false;

  UserBlocError _lastError;

  AnimationController _animController;
  StreamSubscription<UserState> _subscription;

  FocusNode _focusNode;
  ScrollController _scrollController;
  TextEditingController _pinController;

  bool get newUser => _newUser;

  TextTheme textTheme;
  TextStyle titleStyle;
  TextStyle emailStyle;

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
    super.didChangeDependencies();
    final bloc = context.bloc<UserBloc>();
    _subscription?.cancel();
    _subscription = bloc.listen((UserState state) {
      _process(state, bloc, context);
    });
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

    return StreamBuilder<UserState>(
        stream: context.bloc<UserBloc>(),
        builder: (context, snapshot) {
          return Scaffold(
            backgroundColor: Colors.grey[300],
            body: SafeArea(
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: _buildBody(context, context.bloc<UserBloc>()),
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _buildBody(BuildContext context, UserBloc bloc) {
    return _inProgress(bloc)
        ? FractionallySizedBox(
            alignment: Alignment.topCenter,
            widthFactor: 0.90,
            child: _buildProgress(context),
          )
        : FractionallySizedBox(
            alignment: Alignment.center,
            widthFactor: 0.90,
            heightFactor: 0.90,
            child: _buildForm(context, bloc),
          );
  }

  bool _inProgress(UserBloc bloc) => bloc.isAuthenticating || bloc?.state?.isPending() == true;

  Container _buildProgress(BuildContext context) {
    _animController ??= AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _animController.repeat();

    return Container(
      padding: EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.minHeight * 2,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildTitle(context),
                    // Logo
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SizedBox(
                          height: 400,
                          child: _buildRipple(
                            _buildIcon(),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Logger deg inn, vent litt',
                      style: _toStyle(context, 22, FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Container _buildForm(
    BuildContext context,
    UserBloc bloc,
  ) {
    _animController?.stop(canceled: false);
    return Container(
      padding: EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitle(context),
                      // Logo
                      Expanded(
                          child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildIcon(),
                      )),
                      ..._buildFields(bloc),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildFields(UserBloc bloc) {
    final isError = _isError(bloc);
    var fields = isError ? [_buildErrorText(bloc)] : <Widget>[];
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

  bool _isError(UserBloc bloc) => bloc.state.isError();

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
    if (bloc.state is UserUnauthorized) {
      return 'Feil brukernavn eller passord';
    } else if (bloc.state is UserForbidden) {
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

  Widget _buildRipple(Widget icon) => AnimatedBuilder(
        animation: CurvedAnimation(
          parent: _animController,
          curve: Curves.elasticOut,
          reverseCurve: Curves.elasticIn,
        ),
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              _buildCircle(180 + (36 * _animController.value)),
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

  Widget _buildAuthenticate(UserBloc bloc) => Column(
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
                if (bloc.isPersonal || context.bloc<AppConfigBloc>().config.idpHints.contains('rodekors'))
                  _buildOrgLoginAction(bloc),
                if (bloc.isPersonal) _buildGoogleLoginAction(bloc),
                _buildDivider(),
              ],
            ),
          ),
          _buildUserInput(bloc),
          Flexible(
            child: _buildAuthenticateAction(bloc),
          ),
        ],
      );

  Widget _buildGoogleLoginAction(UserBloc bloc) {
    return _buildAction(
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
      type: OutlinedButton,
      validate: false,
    );
  }

  Widget _buildOrgLoginAction(UserBloc bloc) {
    return _buildAction(
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
    );
  }

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

  Widget _buildUserInput(UserBloc bloc) => bloc.isShared ? _buildSharedUseInput(bloc) : _buildPrivateUseInput(bloc);

  Widget _buildPrivateUseInput(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: _buildEmailTextField(bloc),
      );

  Widget _buildSharedUseInput(UserBloc bloc) => Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: _newUser || bloc.users.isEmpty
            ? _buildEmailTextField(bloc)
            : buildDropDownField<String>(
                name: 'email',
                isDense: false,
                initialValue: _setUser(
                  bloc,
                  bloc.users.first,
                ),
                items: _buildUserItems(
                  bloc.users,
                ),
                onChanged: (value) {
                  final user = bloc.users.firstWhere(
                    (user) => user.userId == value,
                    orElse: () => null,
                  );
                  _setUser(bloc, user);
                },
                validator: FormBuilderValidators.minLength(context, 0),
              ),
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
            OutlinedButton(
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

  TextFormField _buildEmailTextField(UserBloc bloc) => TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.go,
        autofocus: false,
        scrollPadding: EdgeInsets.all(90),
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          hintText: 'Påloggingsadresse',
        ),
        validator: (value) {
          if (bloc.isShared) {
            final domain = UserService.toDomain(value);
            if (!bloc.trustedDomains.contains(domain)) {
              return '$value er ikke tillatt';
            }
          }
          return value.isEmpty ? 'Påloggingsadresse må fylles ut' : null;
        },
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
      await bloc.login(
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
    Type type = ElevatedButton,
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
    if (type == OutlinedButton) {
      return _buildOutlineButton(
        label,
        enabled,
        onPressed,
        icon: icon,
        validate: validate,
      );
    }
    return _buildElevatedButton(
      color,
      label,
      enabled,
      onPressed,
      icon: icon,
      validate: validate,
    );
  }

  Widget _buildElevatedButton(
    Color color,
    String label,
    bool enabled,
    onPressed(), {
    Widget icon,
    bool validate = true,
  }) =>
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: color,
          elevation: 2.0,
          padding: icon == null ? null : EdgeInsets.only(left: 16.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        ),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.5, color: Colors.white),
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
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: icon == null ? null : EdgeInsets.only(left: 16.0),
        ),
        child: Row(
          mainAxisAlignment: icon == null ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
          children: <Widget>[
            if (icon != null) icon,
            Text(
              label,
              style: TextStyle(fontSize: SizeConfig.safeBlockVertical * 2.4),
              textAlign: icon == null ? TextAlign.center : TextAlign.left,
            ),
          ],
        ),
        onPressed: enabled ? () => _onActionPressed(validate, onPressed) : null,
      );

  void _process(UserState state, UserBloc bloc, BuildContext context) {
    switch (state.runtimeType) {
      case UserAuthenticated:
        // Only close login if user is authenticated and app is secured with pin
        if (bloc.isAuthenticated && _popWhenReady) {
          _popTo(context);
        }
        break;
      case UserBlocError:
        if (_lastError == null) {
          Catcher.reportCheckedError(
            state.data,
            (state as UserBlocError).stackTrace,
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
        widget.returnTo ?? OperationsScreen.ROUTE,
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
