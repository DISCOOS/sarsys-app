import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/personnel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserStatusPage extends StatefulWidget {
  const UserStatusPage({
    Key key,
    @required this.onMessage,
    this.personnel,
    this.onChanged,
  }) : super(key: key);

  final Personnel personnel;
  final ActionCallback onMessage;
  final ValueChanged<Personnel> onChanged;

  @override
  UserStatusPageState createState() => UserStatusPageState();
}

class UserStatusPageState extends State<UserStatusPage> {
  PersonnelBloc _personnelBloc;
  TrackingBloc _trackingBloc;

  Personnel _personnel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _personnel = widget.personnel;
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PersonnelState>(
        stream: _personnelBloc.state,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final state = snapshot.data;
            if (state.isUpdated() && state.data.id == _personnel.id) {
              _personnel = state.data;
            }
            return _personnel == null ? Text('Deltar ikke på aksjon') : _buildInfoPanel(context);
          }
          return Container();
        });
  }

  PersonnelWidget _buildInfoPanel(BuildContext context) {
    final tracking = _trackingBloc.tracking[_personnel.tracking];
    return PersonnelWidget(
      personnel: _personnel,
      tracking: tracking,
      devices: _trackingBloc.devices(_personnel.tracking),
      withName: true,
      withHeader: false,
      withActions: false,
      onMessage: widget.onMessage,
      organization: FleetMapService().fetchOrganization(Defaults.orgId),
      onGoto: (point) => jumpToPoint(context, center: point),
    );
  }
}
