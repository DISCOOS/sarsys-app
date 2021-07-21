// @dart=2.11

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserHistoryPage extends StatefulWidget {
  const UserHistoryPage({
    Key key,
  }) : super(key: key);

  @override
  UserHistoryPageState createState() => UserHistoryPageState();
}

class UserHistoryPageState extends State<UserHistoryPage> {
  StreamGroup<dynamic> _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group?.close();
    _group = StreamGroup.broadcast()
      ..add(context.read<PersonnelBloc>().stream)
      ..add(context.read<TrackingBloc>().stream)
      ..add(context.read<UserBloc>().stream);
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
      child: Text('Ingen historikk'),
    );
  }
}
