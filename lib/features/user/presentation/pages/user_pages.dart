import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/user/presentation/widget/user_widgets.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/features/personnel/presentation/widgets/personnel_widgets.dart';
import 'package:SarSys/features/unit/presentation/widgets/unit_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:async/async.dart';

class UserStatusPage extends StatefulWidget {
  UserStatusPage({
    Key key,
    @required this.onMessage,
    @required this.user,
    this.personnel,
    this.onChanged,
  }) : super(key: key) {
    assert(user != null, "User is required");
  }

  final User user;
  final Personnel personnel;
  final ActionCallback onMessage;
  final ValueChanged<Personnel> onChanged;

  @override
  UserStatusPageState createState() => UserStatusPageState();
}

class UserStatusPageState extends State<UserStatusPage> {
  Personnel _personnel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _personnel = widget.personnel;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.bloc<PersonnelBloc>().load();
      },
      child: StreamBuilder<PersonnelState>(
          stream: context.bloc<PersonnelBloc>(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              if (state.isUpdated() && state.data.uuid == _personnel.uuid) {
                _personnel = state.data;
              }
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    UserLocationWidget(
                      onMessage: widget.onMessage,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Divider(),
                    ),
                    _personnel == null ? _buildUserWidget(context) : _buildPersonnelWidget(context),
                  ],
                ),
              );
            }
            return Container();
          }),
    );
  }

  UserWidget _buildUserWidget(BuildContext context) {
    return UserWidget(
      user: widget.user,
      withName: true,
      withHeader: false,
      withActions: false,
      onMessage: widget.onMessage,
      onGoto: (point) => jumpToPoint(context, center: point),
    );
  }

  PersonnelWidget _buildPersonnelWidget(BuildContext context) {
    final tuuid = _personnel.tracking.uuid;
    final tracking = context.bloc<TrackingBloc>().trackings[tuuid];
    return PersonnelWidget(
      withName: true,
      withHeader: false,
      withActions: false,
      withLocation: false,
      tracking: tracking,
      personnel: _personnel,
      onMessage: widget.onMessage,
      onGoto: (point) => jumpToPoint(context, center: point),
      unit: context.bloc<UnitBloc>().repo.findPersonnel(_personnel.uuid).firstOrNull,
      devices: context.bloc<TrackingBloc>().devices(tuuid),
    );
  }
}

class UserUnitPage extends StatefulWidget {
  const UserUnitPage({
    Key key,
    @required this.onMessage,
    this.unit,
    this.onChanged,
  }) : super(key: key);

  final Unit unit;
  final ActionCallback onMessage;
  final ValueChanged<Unit> onChanged;

  @override
  UserUnitPageState createState() => UserUnitPageState();
}

class UserUnitPageState extends State<UserUnitPage> {
  StreamGroup<dynamic> _group;
  Unit _unit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group?.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UserBloc>())
      ..add(context.bloc<PersonnelBloc>())
      ..add(context.bloc<UnitBloc>().onChanged(_unit?.uuid))
      ..add(context.bloc<TrackingBloc>().onChanged(_unit?.tracking?.uuid));
    _unit = widget.unit;
  }

  @override
  void dispose() {
    _group.close();
    _group = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.bloc<PersonnelBloc>().load();
      },
      child: StreamBuilder(
          stream: _group.stream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              if (state is UnitUpdated && state.data.uuid == widget.unit.uuid) {
                _unit = state.data;
              }
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: _unit == null ? Center(child: Text('Ikke tilordnet lag')) : _build(context),
              );
            }
            return Container();
          }),
    );
  }

  Widget _build(BuildContext context) {
    final tracking = context.bloc<TrackingBloc>().find(_unit).firstOrNull;
    return UnitWidget(
      unit: _unit,
      withMap: true,
      withHeader: false,
      withActions: false,
      tracking: tracking,
      onMessage: widget.onMessage,
      onGoto: (point) => jumpToPoint(context, center: point),
      devices: context.bloc<TrackingBloc>().devices(_unit.tracking.uuid),
    );
  }
}
