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
  Personnel _personnel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _personnel = widget.personnel;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PersonnelState>(
        stream: context.bloc<PersonnelBloc>(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final state = snapshot.data;
            if (state.isUpdated() && state.data.uuid == _personnel.uuid) {
              _personnel = state.data;
            }
            return _personnel == null ? Center(child: Text('Deltar ikke på aksjon')) : _buildInfoPanel(context);
          }
          return Container();
        });
  }

  PersonnelWidget _buildInfoPanel(BuildContext context) {
    final tracking = context.bloc<TrackingBloc>().trackings[_personnel.tracking.uuid];
    return PersonnelWidget(
      personnel: _personnel,
      tracking: tracking,
      devices: context.bloc<TrackingBloc>().devices(_personnel.tracking.uuid),
      withName: true,
      withHeader: false,
      withActions: false,
      onMessage: widget.onMessage,
      organization: FleetMapService().fetchOrganization(Defaults.orgId),
      onGoto: (point) => jumpToPoint(context, center: point),
    );
  }
}
