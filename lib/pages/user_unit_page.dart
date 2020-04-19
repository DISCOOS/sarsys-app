import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserUnitPage extends StatefulWidget {
  const UserUnitPage({
    Key key,
  }) : super(key: key);

  @override
  UserUnitPageState createState() => UserUnitPageState();
}

class UserUnitPageState extends State<UserUnitPage> {
  StreamGroup<dynamic> _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group?.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UnitBloc>())
      ..add(context.bloc<TrackingBloc>())
      ..add(context.bloc<UserBloc>());
  }

  @override
  void dispose() {
    _group.close();
    _group = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Min enhet'),
    );
  }
}
