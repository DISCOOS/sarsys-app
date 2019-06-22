import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UnitsPage extends StatefulWidget {
  @override
  _UnitsPageState createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  UnitBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = BlocProvider.of<UnitBloc>(context).init(setState);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await bloc.fetch();
          setState(() {});
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: bloc.units.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Center(
              child: CircularProgressIndicator(),
            ),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              child: StreamBuilder(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var units = bloc.units;
                  return units.isNotEmpty
                      ? _buildList(units)
                      : Center(
                          child: Text(
                            "Legg til en enhet",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                },
              ),
            ),
          ),
        ),
      );
    });
  }

  ListView _buildList(List<Unit> units) {
    return ListView.builder(
      itemCount: units.length,
      itemBuilder: (context, index) {
        return Slidable(
          actionPane: SlidableScrollActionPane(),
          actionExtentRatio: 0.2,
          child: Container(
            color: Colors.white,
            child: ListTile(
              key: ObjectKey(units[index].id),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text('${index + 1}'),
                foregroundColor: Colors.white,
              ),
              title: Text(units[index].name),
              subtitle: Text("Ingen posisjon"),
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
              onTap: () => {},
            ),
            IconSlideAction(
              caption: 'SPOR',
              color: Theme.of(context).colorScheme.primary,
              icon: Icons.play_arrow,
              onTap: () => {},
            ),
          ],
        );
      },
    );
  }
}
