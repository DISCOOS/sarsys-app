import 'dart:convert';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/affilliation.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UserHistoryPage extends StatefulWidget {
  const UserHistoryPage({
    Key key,
  }) : super(key: key);

  @override
  UserHistoryPageState createState() => UserHistoryPageState();
}

class UserHistoryPageState extends State<UserHistoryPage> {
  UserBloc _userBloc;
  PersonnelBloc _personnelBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Set<PersonnelStatus> _filter;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _group?.close();
    _group = StreamGroup.broadcast()..add(_personnelBloc.state)..add(_trackingBloc.state)..add(_userBloc.state);
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
