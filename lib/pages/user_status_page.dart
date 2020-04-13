import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserStatusPage extends StatefulWidget {
  const UserStatusPage({Key key, @required this.onMessage}) : super(key: key);

  final MessageCallback onMessage;

  @override
  UserStatusPageState createState() => UserStatusPageState();
}

class UserStatusPageState extends State<UserStatusPage> {
  UserBloc _userBloc;
  PersonnelBloc _personnelBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Personnel _personnel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _group?.close();
    _group = StreamGroup.broadcast()..add(_personnelBloc.state)..add(_trackingBloc.state)..add(_userBloc.state);
  }

  Personnel _findPersonnel() {
    final userId = _userBloc.user?.userId;
    return _personnelBloc.personnel.values.firstWhere(
      (personnel) => personnel.userId == userId,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _group?.close();
    _group = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: _group.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _personnel = _findPersonnel();
            return _personnel == null ? Text('Deltar ikke på aksjon') : _buildInfoPanel(context);
          }
          return Container();
        });
  }

  PersonnelInfoPanel _buildInfoPanel(BuildContext context) {
    final tracking = _trackingBloc.tracking[_personnel.tracking];
    return PersonnelInfoPanel(
      personnel: _personnel,
      tracking: tracking,
      devices: tracking?.devices
              ?.map((id) => _trackingBloc.deviceBloc.devices[id])
              ?.where((personnel) => personnel != null) ??
          {},
      withHeader: false,
      withActions: _userBloc.user.isCommander,
      onMessage: widget.onMessage,
      organization: FleetMapService().fetchOrganization(Defaults.organizationId),
      onChanged: (personnel) => setState(() => _personnel = personnel),
      onDelete: () => Navigator.pop(context),
      onGoto: (point) => jumpToPoint(context, center: point),
    );
  }
}
