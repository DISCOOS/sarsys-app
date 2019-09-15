import 'dart:async';

import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class SecureScreen<S extends SecureScreenState> extends StatefulWidget {
  const SecureScreen({Key key}) : super(key: key);
  @override
  S createState();
}

abstract class SecureScreenState extends State<SecureScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String get title;
  Widget buildBody(BoxConstraints constraints);

  bool get centerTitle => false;
  Widget get floatingActionButton => null;
  FloatingActionButtonLocation get floatingActionButtonLocation => null;
  BottomAppBar get bottomAppBar => null;

  UserBloc _bloc;
  UserBloc get userBloc => _bloc;

  StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _set();
  }

  @override
  void didUpdateWidget(SecureScreen old) {
    super.didUpdateWidget(old);
    final bloc = BlocProvider.of<UserBloc>(context);
    if (bloc != _bloc) {
      _unset();
      _set();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _unset();
  }

  void _set() {
    _bloc = BlocProvider.of<UserBloc>(context);
    _subscription = _bloc.state.listen((state) {
      if (!state.isAuthenticated()) {
        final onboarding = BlocProvider.of<AppConfigBloc>(context)?.config?.onboarding;
        Navigator.pushReplacementNamed(context, onboarding == true ? 'onboarding' : 'login');
      }
    });
  }

  void _unset() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            title: Text(title),
            centerTitle: centerTitle,
          ),
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: buildBody(constraints),
          floatingActionButtonLocation: floatingActionButtonLocation,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomAppBar,
        );
      },
    );
  }
}
