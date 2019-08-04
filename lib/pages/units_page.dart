import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/utils/map_utils.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({Key key}) : super(key: key);

  @override
  UnitsPageState createState() => UnitsPageState();
}

class UnitsPageState extends State<UnitsPage> {
  UnitBloc _unitBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;
  List<UnitStatus> _filter = UnitStatus.values.toList()..remove(UnitStatus.Retired);

  @override
  void initState() {
    super.initState();
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _group = StreamGroup.broadcast();
    _group.add(_unitBloc.state);
    _group.add(_trackingBloc.state);
  }

  @override
  void dispose() {
    super.dispose();
    _group.close();
    _group = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return RefreshIndicator(
          onRefresh: () async {
            _unitBloc.fetch();
            _trackingBloc.fetch();
          },
          child: Container(
            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                var units = _unitBloc.units.isEmpty || snapshot.hasError
                    ? []
                    : _unitBloc.units.values.where((unit) => _filter.contains(unit.status)).toList();

                return AnimatedCrossFade(
                  duration: Duration(milliseconds: 300),
                  crossFadeState: _unitBloc.units.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Center(
                    child: CircularProgressIndicator(),
                  ),
                  secondChild: _unitBloc.units.isEmpty || snapshot.hasError
                      ? Center(
                          child: Text(
                          snapshot.hasError ? snapshot.error : "Legg til en enhet",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ))
                      : ListView.builder(
                          itemCount: units.length + 1,
                          itemBuilder: (context, index) {
                            return _buildUnit(context, units, index);
                          },
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnit(BuildContext context, List<Unit> units, int index) {
    if (index == units.length) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text("Antall enheter: $index"),
        ),
      );
    }
    var unit = units[index];
    var tracking = unit.tracking == null ? null : _trackingBloc.tracks[unit.tracking];
    var status = tracking.status ?? TrackingStatus.None;
    return Slidable(
      actionPane: SlidableScrollActionPane(),
      actionExtentRatio: 0.2,
      child: Container(
        color: Colors.white,
        child: ListTile(
          key: ObjectKey(unit.id),
          leading: CircleAvatar(
            backgroundColor: _toTrackingStatusColor(context, status),
            child: Icon(Icons.people),
            foregroundColor: Colors.white,
          ),
          title: Text(unit.name),
          subtitle: Text(toUTM(tracking?.location, empty: "Ingen posisjon")),
          dense: true,
          trailing: RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
          onTap: () => jumpToPoint(context, tracking?.location),
        ),
      ),
      secondaryActions: <Widget>[
        if (tracking?.location != null) _buildTrackingAction(context, status, tracking),
        _buildEditAction(context, unit),
        _buildCloseAction(context, unit),
      ],
    );
  }

  IconSlideAction _buildTrackingAction(BuildContext context, TrackingStatus status, Tracking tracking) {
    return IconSlideAction(
      caption: 'SPORING',
      color: _toTrackingStatusColor(context, status),
      icon: _toTrackingIconData(context, status),
      onTap: () => _transition(context, tracking),
    );
  }

  IconData _toTrackingIconData(BuildContext context, TrackingStatus status) {
    switch (status) {
      case TrackingStatus.Created:
      case TrackingStatus.Paused:
      case TrackingStatus.Closed:
        return Icons.play_arrow;
      case TrackingStatus.Tracking:
      default:
        return Icons.pause;
    }
  }

  Color _toTrackingStatusColor(BuildContext context, TrackingStatus status) {
    switch (status) {
      case TrackingStatus.None:
        return Colors.grey;
      case TrackingStatus.Created:
        return Theme.of(context).colorScheme.primary;
      case TrackingStatus.Tracking:
        return Colors.green;
      case TrackingStatus.Paused:
        return Colors.orange;
      case TrackingStatus.Closed:
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  _transition(BuildContext context, Tracking tracking) {
    switch (tracking.status) {
      case TrackingStatus.Created:
      case TrackingStatus.Paused:
      case TrackingStatus.Closed:
        _trackingBloc.update(tracking, status: TrackingStatus.Tracking);
        break;
      case TrackingStatus.Tracking:
        _trackingBloc.update(tracking, status: TrackingStatus.Paused);
        break;
      default:
        break;
    }
  }

  IconSlideAction _buildEditAction(BuildContext context, Unit unit) {
    return IconSlideAction(
      caption: 'ENDRE',
      color: Theme.of(context).buttonColor,
      icon: Icons.more_horiz,
      onTap: () => showDialog(
        context: context,
        builder: (context) => UnitEditor(unit: unit),
      ),
    );
  }

  IconSlideAction _buildCloseAction(BuildContext context, Unit unit) {
    return IconSlideAction(
      caption: 'OPPLØS',
      color: Colors.red,
      icon: Icons.delete,
      onTap: () async {
        var response = await prompt(
          context,
          "Oppløs ${unit.name}",
          "Dette vil stoppe sporing og oppløse enheten. Vil du fortsette?",
        );
        if (response) {
          _unitBloc.update(unit.cloneWith(status: UnitStatus.Retired));
        }
      },
    );
  }

  void showFilterSheet(context) {
    final style = Theme.of(context).textTheme.title;
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return StatefulBuilder(builder: (context, state) {
            return Container(
              padding: EdgeInsets.only(bottom: 56.0),
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.only(left: 16.0, right: 0),
                    title: Text("Vis", style: style),
                    trailing: FlatButton(
                      child: Text('BRUK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
                      onPressed: () => setState(
                        () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                  Divider(),
                  ...UnitStatus.values
                      .map((status) => ListTile(
                          title: Text(translateUnitStatus(status), style: style),
                          trailing: Switch(
                            value: _filter.contains(status),
                            onChanged: (value) => _onFilterChanged(status, value, state),
                          )))
                      .toList(),
                ],
              ),
            );
          });
        });
  }

  void _onFilterChanged(UnitStatus status, bool value, StateSetter update) {
    update(() {
      if (value) {
        _filter.add(status);
      } else {
        _filter.remove(status);
      }
    });
  }
}
