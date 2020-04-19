import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
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
      ..add(context.bloc<PersonnelBloc>())
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
      child: Text('Min historikk'),
    );
  }
}
