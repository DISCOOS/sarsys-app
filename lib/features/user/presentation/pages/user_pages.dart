import 'package:SarSys/core/callbacks.dart';
import 'package:SarSys/core/presentation/widgets/stream_widget.dart';
import 'package:SarSys/core/size_config.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/features/mapping/domain/entities/Position.dart';
import 'package:SarSys/features/tracking/presentation/widgets/coordinate_widget.dart';
import 'package:SarSys/features/activity/domain/activity_profile.dart';
import 'package:SarSys/features/activity/presentation/blocs/activity_bloc.dart';
import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/operation/presentation/screens/operations_screen.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
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
import 'package:flutter/cupertino.dart';
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

  TextStyle get labelTextStyle => TextStyle(fontSize: SizeConfig.labelFontSize);

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return RefreshIndicator(
      onRefresh: () async {
        if (_personnel == null) {
          context.read<ActivityBloc>().apply();
        } else {
          context.read<PersonnelBloc>().load();
        }
      },
      child: StreamBuilder<PersonnelState>(
          stream: context.read<PersonnelBloc>().stream,
          initialData: context.read<PersonnelBloc>().state,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              if (state.data is Personnel && state.data.uuid == _personnel?.uuid) {
                _personnel = state.data;
              }
              return SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    _buildProfile(context),
                    _buildDivider(),
                    _personnel == null ? _buildUserWidget(context) : _buildPersonnelWidget(context),
                  ],
                ),
              );
            }
            return Container();
          }),
    );
  }

  Padding _buildDivider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0.0),
      child: Divider(),
    );
  }

  Widget _buildLocationBuffer() => Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LocationBufferWidget(
            onMessage: widget.onMessage,
          ),
        ),
      );

  Widget _buildProfile(BuildContext context) {
    final service = LocationService();
    return StreamBuilderWidget<ActivityProfile>(
      stream: context.read<ActivityBloc>().onChanged,
      initialData: context.read<ActivityBloc>().profile,
      builder: (context, profile) {
        var status;
        switch (profile) {
          case ActivityProfile.PRIVATE:
            status = _buildStatus(context, child: _buildCoordinateWidget(service, context), buttons: [
              _buildMapAction(context, service),
              _buildJoinAction(context),
            ]);
            break;
          case ActivityProfile.ALERTED:
            status = _buildStatus(context, child: _buildCoordinateWidget(service, context), buttons: [
              _buildMapAction(context, service),
              _buildEnrouteAction(context),
            ]);
            break;
          case ActivityProfile.ENROUTE:
            status = _buildStatus(context, child: _buildCoordinateWidget(service, context), buttons: [
              _buildMapAction(context, service),
              _buildCheckInAction(context),
            ]);
            break;
          case ActivityProfile.ONSCENE:
            status = _buildStatus(context, child: _buildCoordinateWidget(service, context), buttons: [
              _buildMapAction(context, service),
              _buildCheckOutAction(context),
            ]);
            break;
          case ActivityProfile.LEAVING:
            status = _buildStatus(context, child: _buildCoordinateWidget(service, context), buttons: [
              _buildMapAction(context, service),
              _buildRetireAction(context),
            ]);
            break;
          default:
            status = Text(
              'profile: ${context.read<ActivityBloc>().profile}',
            );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: status ?? Text('profile: ${context.read<ActivityBloc>().profile}'),
            ),
            if (context.read<ActivityBloc>().isTrackable) _buildLocationBuffer(),
          ],
        );
      },
    );
  }

  Widget _buildCoordinateWidget(LocationService service, BuildContext context) {
    return StreamBuilder<Position>(
        stream: service.stream,
        initialData: service.current,
        builder: (context, snapshot) {
          final position = snapshot.hasData ? snapshot.data : null;
          return CoordinateWidget(
            isDense: false,
            withIcons: false,
            withNavigation: false,
            accuracy: position?.acc,
            point: position?.geometry,
            onMessage: widget.onMessage,
            timestamp: position?.timestamp,
            onGoto: (point) => jumpToPoint(context, center: point),
          );
        });
  }

  Widget _buildStatus(
    BuildContext context, {
    @required Widget child,
    @required List<Widget> buttons,
  }) {
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStandbyStatus(context),
                Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: child,
                      ),
                    ),
                    Container(
                      width: 135,
                      margin: const EdgeInsets.only(left: 5.0),
                      child: ButtonBarTheme(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: buttons,
                        ),
                        data: ButtonBarThemeData(
                          alignment: MainAxisAlignment.end,
                          layoutBehavior: ButtonBarLayoutBehavior.constrained,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ElevatedButton _buildJoinAction(BuildContext context) => ElevatedButton.icon(
        icon: Icon(Icons.list),
        label: Text('VELG'),
        onPressed: () => showDialog<Personnel>(
          context: context,
          builder: (BuildContext context) {
            // return object of type Dialog
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text("VELG AKSJON", textAlign: TextAlign.start),
              ),
              body: OperationsPage(
                filter: OperationsPage.DEFAULT_FILTER,
              ),
            );
          },
        ),
      );

  ElevatedButton _buildMapAction(BuildContext context, LocationService service) => ElevatedButton.icon(
        icon: Icon(Icons.map),
        label: Text('VIS'),
        onPressed: () => jumpToPoint(context, center: service.current?.geometry),
      );

  ElevatedButton _buildEnrouteAction(BuildContext context) {
    final personnel = context.read<PersonnelBloc>().findUser().firstOrNull;
    return ElevatedButton.icon(
      icon: Icon(Icons.directions_run),
      label: Text('PÅ VEI'),
      onPressed: personnel != null ? () => ingressPersonnel(personnel) : null,
    );
  }

  ElevatedButton _buildCheckInAction(BuildContext context) {
    final personnel = context.read<PersonnelBloc>().findUser().firstOrNull;
    return ElevatedButton.icon(
      icon: Icon(Icons.assignment_turned_in),
      label: Text('SJEKK INN'),
      onPressed: personnel != null ? () => checkInPersonnel(personnel) : null,
    );
  }

  ElevatedButton _buildCheckOutAction(BuildContext context) {
    final personnel = context.read<PersonnelBloc>().findUser().firstOrNull;
    return ElevatedButton.icon(
      icon: Icon(Icons.directions_walk),
      label: Text('SJEKK UT'),
      onPressed: personnel != null ? () => checkOutPersonnel(personnel) : null,
    );
  }

  ElevatedButton _buildRetireAction(BuildContext context) {
    final personnel = context.read<PersonnelBloc>().findUser().firstOrNull;
    return ElevatedButton.icon(
      icon: Icon(Icons.home),
      label: Text('HJEMME'),
      onPressed: personnel != null ? () => retirePersonnel(personnel) : null,
    );
  }

  Text _buildActivityStatus(BuildContext context) {
    final service = LocationService();
    return Text.rich(
      TextSpan(
        text: '${translateActivityType(service.activity.type)}',
        style: Theme.of(context).textTheme.subtitle2,
        children: [
          TextSpan(
            text: ' (${service.activity.confidence}% sikkert)',
            style: Theme.of(context).textTheme.caption,
          )
        ],
      ),
    );
  }

  Widget _buildStandbyStatus(BuildContext context) {
    final operation = context.read<OperationBloc>().selected;
    final personnel = context.read<PersonnelBloc>().findUser();
    final affiliation = context.read<AffiliationBloc>().findUserAffiliation();
    final status = personnel.isNotEmpty == true
        ? translatePersonnelStatus(personnel.first.status)
        : translateAffiliationStandbyStatus(affiliation?.status ?? AffiliationStandbyStatus.unavailable);
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildOperationName(operation, context),
        ),
        Padding(
          padding: EdgeInsets.all(5.0),
          child: _buildActivityStatus(context),
        ),
        Chip(
          elevation: 2,
          avatar: Icon(
            toPersonnelStatusIcon(
              personnel.firstOrNull?.status,
            ),
            size: 16.0,
          ),
          label: Text('$status'),
          labelPadding: EdgeInsets.only(right: 4.0),
          labelStyle: Theme.of(context).textTheme.caption,
        ),
      ],
    );
  }

  Text _buildOperationName(Operation operation, BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '${operation == null ? 'Ingen aksjon' : '${translateOperationType(operation.type)}'}',
        style: Theme.of(context).textTheme.subtitle2,
        children: [
          if (operation?.name != null)
            TextSpan(
              text: ' ${operation.name}',
              style: Theme.of(context).textTheme.caption,
            )
        ],
      ),
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
    final tracking = context.read<TrackingBloc>().trackings[tuuid];
    return PersonnelWidget(
      withName: true,
      withHeader: false,
      withActions: false,
      withLocation: false,
      tracking: tracking,
      personnel: _personnel,
      onMessage: widget.onMessage,
      devices: context.read<TrackingBloc>().devices(tuuid),
      onGoto: (point) => jumpToPoint(context, center: point),
      unit: context.read<UnitBloc>().repo.findPersonnel(_personnel.uuid).firstOrNull,
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
      ..add(context.read<UserBloc>().stream)
      ..add(context.read<PersonnelBloc>().stream)
      ..add(context.read<UnitBloc>().onChanged(_unit?.uuid))
      ..add(context.read<TrackingBloc>().onChanged(_unit?.tracking?.uuid));
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
        context.read<UnitBloc>().load();
        context.read<PersonnelBloc>().load();
      },
      child: StreamBuilder(
          stream: _group.stream,
          initialData: context.read<UserBloc>().state,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final state = snapshot.data;
              if (state is UnitUpdated && state.data.uuid == widget.unit.uuid) {
                _unit = state.data;
              }
              return _unit == null
                  ? Center(child: Text('Ikke tilordnet lag'))
                  : SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _build(context),
                        ],
                      ),
                    );
            }
            return Container();
          }),
    );
  }

  Widget _build(BuildContext context) {
    final tracking = context.read<TrackingBloc>().trackings[_unit.tracking.uuid];
    return UnitWidget(
      unit: _unit,
      withMap: true,
      withHeader: false,
      withActions: false,
      tracking: tracking,
      onMessage: widget.onMessage,
      onGoto: (point) => jumpToPoint(context, center: point),
      devices: context.read<TrackingBloc>().devices(_unit.tracking.uuid),
    );
  }
}
