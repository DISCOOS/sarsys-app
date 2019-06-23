import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UnitsPage extends StatefulWidget {
  @override
  _UnitsPageState createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  UnitBloc unitBloc;
  TrackingBloc trackingBloc;
  StreamGroup<dynamic> group;

  @override
  void initState() {
    super.initState();
    unitBloc = BlocProvider.of<UnitBloc>(context).init(setState);
    trackingBloc = BlocProvider.of<TrackingBloc>(context).init(setState);
    group = StreamGroup.broadcast();
    group.add(unitBloc.state);
    group.add(trackingBloc.state);
  }

  @override
  void dispose() {
    super.dispose();
    group.close();
    group = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          unitBloc.fetch();
          trackingBloc.fetch();
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: unitBloc.units.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Center(
              child: CircularProgressIndicator(),
            ),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              child: StreamBuilder(
                stream: group.stream,
                builder: _buildList,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildList(BuildContext context, AsyncSnapshot<dynamic> snapshot) {
    return unitBloc.units.isEmpty || snapshot.hasError
        ? Center(
            child: Text(
            snapshot.hasError ? snapshot.error : "Legg til en enhet",
            style: TextStyle(fontWeight: FontWeight.w600),
          ))
        : ListView.builder(
            itemCount: unitBloc.units.length,
            itemBuilder: (context, index) {
              return _buildUnit(context, index);
            },
          );
  }

  Widget _buildUnit(BuildContext context, int index) {
    var unit = unitBloc.units[index];
    var tracking = unit.tracking == null ? null : trackingBloc.tracks[unit.tracking];
    return GestureDetector(
      child: Slidable(
        actionPane: SlidableScrollActionPane(),
        actionExtentRatio: 0.2,
        child: Container(
          color: Colors.white,
          child: ListTile(
            key: ObjectKey(unit.id),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text('${index + 1}'),
              foregroundColor: Colors.white,
            ),
            title: Text(unit.name),
            subtitle: Text(toUTM(tracking?.location, "Ingen posisjon")),
            trailing: RotatedBox(
              quarterTurns: 1,
              child: Icon(
                Icons.drag_handle,
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
          ),
        ),
        actions: <Widget>[
          IconSlideAction(
            caption: 'OPPLØS',
            color: Colors.red,
            icon: Icons.delete,
            onTap: () => {},
          ),
          IconSlideAction(
            caption: 'ENDRE',
            color: Theme.of(context).buttonColor,
            icon: Icons.more_horiz,
            onTap: () => {},
          ),
        ],
        secondaryActions: <Widget>[
          IconSlideAction(
            caption: 'VIS',
            color: Theme.of(context).buttonColor,
            icon: Icons.gps_fixed,
            onTap: () => _gotoUnit(context, tracking),
          ),
          IconSlideAction(
            caption: 'SPOR',
            color: Theme.of(context).colorScheme.primary,
            icon: Icons.play_arrow,
            onTap: () => {},
          ),
        ],
      ),
      onTap: () => _gotoUnit(context, tracking),
    );
  }

  void _gotoUnit(BuildContext context, Tracking tracking) {
    if (tracking?.location != null) {
      Navigator.pushReplacementNamed(context, "map", arguments: toLatLng(tracking.location));
    }
  }
}
