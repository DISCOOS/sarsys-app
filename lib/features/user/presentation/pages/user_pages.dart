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
              if (state.isUpdated() && state.data.uuid == _personnel?.uuid) {
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
    return StreamBuilder<ActivityProfile>(
        stream: context.bloc<ActivityBloc>().onChanged,
        initialData: context.bloc<ActivityBloc>().profile,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return CircularProgressIndicator();
          }
          var status;
          final service = LocationService();
          switch (snapshot.data) {
            case ActivityProfile.PRIVATE:
              status = _buildStatus(context,
                  child: CoordinateWidget(
                    isDense: false,
                    withIcons: false,
                    withNavigation: false,
                    onMessage: widget.onMessage,
                    accuracy: service.current.acc,
                    point: service.current.geometry,
                    onGoto: (point) => jumpToPoint(context, center: point),
                  ),
                  buttons: [
                    _buildMapAction(context, service),
                    _buildJoinAction(context),
                  ]);
              break;
            case ActivityProfile.ALERTED:
              status = _buildStatus(context,
                  child: CoordinateWidget(
                    isDense: false,
                    withIcons: false,
                    withNavigation: false,
                    onMessage: widget.onMessage,
                    accuracy: service.current?.acc,
                    point: service.current?.geometry,
                    onGoto: (point) => jumpToPoint(context, center: point),
                  ),
                  buttons: [
                    _buildMapAction(context, service),
                    _buildEnrouteAction(context),
                  ]);
              break;
            case ActivityProfile.ENROUTE:
              status = _buildStatus(context,
                  child: CoordinateWidget(
                    isDense: false,
                    withIcons: false,
                    withNavigation: false,
                    onMessage: widget.onMessage,
                    accuracy: service.current.acc,
                    point: service.current?.geometry,
                    onGoto: (point) => jumpToPoint(context, center: point),
                  ),
                  buttons: [
                    _buildMapAction(context, service),
                    _buildCheckInAction(context),
                  ]);
              break;
            case ActivityProfile.ONSCENE:
              status = _buildStatus(context,
                  child: CoordinateWidget(
                    isDense: false,
                    withIcons: false,
                    withNavigation: false,
                    onMessage: widget.onMessage,
                    accuracy: service.current.acc,
                    point: service.current.geometry,
                    onGoto: (point) => jumpToPoint(context, center: point),
                  ),
                  buttons: [
                    _buildMapAction(context, service),
                    _buildCheckOutAction(context),
                  ]);
              break;
            case ActivityProfile.LEAVING:
              status = _buildStatus(context,
                  child: CoordinateWidget(
                    isDense: false,
                    withIcons: false,
                    withNavigation: false,
                    onMessage: widget.onMessage,
                    accuracy: service.current.acc,
                    point: service.current.geometry,
                    onGoto: (point) => jumpToPoint(context, center: point),
                  ),
                  buttons: [
                    _buildMapAction(context, service),
                    _buildRetireAction(context),
                  ]);
              break;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: status ?? Text('profile: ${context.bloc<ActivityBloc>().profile}'),
              ),
              if (context.bloc<ActivityBloc>().isTrackable) _buildLocationBuffer(),
            ],
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
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildActivityStatus(context),
                    _buildStandbyStatus(context),
                  ],
                ),
                SizedBox(height: 8.0),
                Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints.tightFor(width: 200.0),
                      child: child,
                    ),
                    Spacer(flex: 1),
                    ConstrainedBox(
                      constraints: BoxConstraints.tightFor(width: 130.0),
                      child: ButtonBarTheme(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: buttons,
                        ),
                        data: ButtonBarThemeData(
                          buttonMinWidth: 100,
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

  RaisedButton _buildJoinAction(BuildContext context) => RaisedButton.icon(
        icon: Icon(Icons.list),
        label: Text('Velg aksjon'),
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
                title: Text("Velg aksjon", textAlign: TextAlign.start),
              ),
              body: OperationsPage(
                filter: OperationsPage.DEFAULT_FILTER,
              ),
            );
          },
        ),
      );

  RaisedButton _buildMapAction(BuildContext context, LocationService service) => RaisedButton.icon(
        icon: Icon(Icons.map),
        label: Text('Vis i kart'),
        onPressed: () => jumpToPoint(context, center: service.current.geometry),
      );

  RaisedButton _buildEnrouteAction(BuildContext context) {
    final personnel = context.bloc<PersonnelBloc>().findUser().firstOrNull;
    return RaisedButton.icon(
      icon: Icon(Icons.directions_run),
      label: Text('På vei'),
      onPressed: personnel != null ? () => ingressPersonnel(personnel) : null,
    );
  }

  RaisedButton _buildCheckInAction(BuildContext context) {
    final personnel = context.bloc<PersonnelBloc>().findUser().firstOrNull;
    return RaisedButton.icon(
      icon: Icon(Icons.playlist_add_check),
      label: Text('Sjekk inn'),
      onPressed: personnel != null ? () => checkInPersonnel(personnel) : null,
    );
  }

  RaisedButton _buildCheckOutAction(BuildContext context) {
    final personnel = context.bloc<PersonnelBloc>().findUser().firstOrNull;
    return RaisedButton.icon(
      icon: Icon(Icons.directions_walk),
      label: Text('Sjekk ut'),
      onPressed: personnel != null ? () => checkOutPersonnel(personnel) : null,
    );
  }

  RaisedButton _buildRetireAction(BuildContext context) {
    final personnel = context.bloc<PersonnelBloc>().findUser().firstOrNull;
    return RaisedButton.icon(
      icon: Icon(Icons.home),
      label: Text('Hjemme'),
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

  Text _buildStandbyStatus(BuildContext context) {
    final operation = context.bloc<OperationBloc>().selected;
    final personnel = context.bloc<PersonnelBloc>().findUser();
    final affiliation = context.bloc<AffiliationBloc>().findUserAffiliation();
    final status = personnel.isNotEmpty == true
        ? translatePersonnelStatus(personnel.first.status)
        : translateAffiliationStandbyStatus(affiliation?.status ?? AffiliationStandbyStatus.unavailable);
    return Text.rich(
      TextSpan(
        text: '${operation == null ? 'Ingen aksjon' : '${translateOperationType(operation.type)}'}',
        style: Theme.of(context).textTheme.subtitle2,
        children: [
          TextSpan(
            text: '${operation?.name == null ? '' : ' ${operation.name}'}, er ${status.toLowerCase()}',
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