import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
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
    unitBloc = BlocProvider.of<UnitBloc>(context);
    trackingBloc = BlocProvider.of<TrackingBloc>(context);
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
            secondChild: StreamBuilder(
              stream: group.stream,
              builder: _buildList,
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
            itemCount: unitBloc.units.length + 1,
            itemBuilder: (context, index) {
              return _buildUnit(context, index);
            },
          );
  }

  Widget _buildUnit(BuildContext context, int index) {
    if (index == unitBloc.units.length) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text("Antall enheter: $index"),
        ),
      );
    }
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
              child: Icon(Icons.people),
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
        secondaryActions: <Widget>[
          IconSlideAction(
            caption: 'VIS',
            color: Theme.of(context).buttonColor,
            icon: Icons.gps_fixed,
            onTap: () => _jumpTo(context, tracking),
          ),
          if (tracking?.location != null)
            IconSlideAction(
              caption: 'SPOR',
              color: Theme.of(context).buttonColor,
              icon: Icons.play_arrow,
              onTap: () => {},
            ),
          IconSlideAction(
            caption: 'ENDRE',
            color: Theme.of(context).buttonColor,
            icon: Icons.more_horiz,
            onTap: () async {
              _showEditor(context, unit);
            },
          ),
          IconSlideAction(
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
                unitBloc.delete(unit);
              }
            },
          ),
        ],
      ),
    );
  }

  Future _showEditor(BuildContext context, Unit unit) async {
    var response = await showDialog<Unit>(
      context: context,
      builder: (context) => UnitEditor(unit: unit),
    );
    if (response != null) {
      BlocProvider.of<UnitBloc>(context).update(response);
    }
  }

  void _jumpTo(BuildContext context, Tracking tracking) {
    if (tracking?.location != null) {
      Navigator.pushReplacementNamed(context, "map", arguments: toLatLng(tracking.location));
    }
  }
}
