import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/popups/passcode_popup.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IncidentsScreen extends StatefulWidget {
  @override
  IncidentsScreenState createState() => IncidentsScreenState();
}

class IncidentsScreenState extends State<IncidentsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  IncidentBloc _bloc;
  Set<IncidentStatus> _filter;

  @override
  void initState() {
    super.initState();
    _filter = Set.of([IncidentStatus.Registered, IncidentStatus.Handling, IncidentStatus.Other]);
    _bloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override //new
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(),
          appBar: AppBar(
            title: Text("Velg hendelse"),
            centerTitle: false,
          ),
          extendBody: true,
          resizeToAvoidBottomInset: true,
          body: _buildBody(_bloc, context, viewportConstraints),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _create(context),
            tooltip: 'Ny hendelse',
            child: Icon(Icons.add),
            elevation: 2.0,
          ),
          bottomNavigationBar: _buildBottomAppBar(),
        );
      },
    );
  }

  Future _create(BuildContext context) async {
    var incident = await showDialog<Incident>(
      context: context,
      builder: (context) => IncidentEditor(),
    );
    if (incident != null) Navigator.pushReplacementNamed(context, 'incident');
  }

  Widget _buildBody(IncidentBloc bloc, BuildContext context, BoxConstraints viewportConstraints) {
    return RefreshIndicator(
      onRefresh: () async {
        await bloc.fetch();
        setState(() {});
      },
      child: Container(
        color: Color.fromRGBO(168, 168, 168, 0.6),
        child: StreamBuilder(
          stream: bloc.state,
          builder: (context, snapshot) {
            var cards = bloc.incidents
                .where((incident) => _filter.contains(incident.status))
                .map((incident) => _buildCard(context, bloc, incident))
                .toList();
            return AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              crossFadeState: bloc.incidents.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Center(
                child: CircularProgressIndicator(),
              ),
              secondChild: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 96.0),
                    child: cards.isNotEmpty
                        ? Column(
                            children: cards,
                          )
                        : Center(
                            child: Text(
                              "0 av ${bloc.incidents.length} hendelser vises",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IncidentBloc bloc, Incident incident) {
    final userBloc = BlocProvider.of<UserBloc>(context);

    return StreamBuilder(
        stream: userBloc.state,
        builder: (context, snapshot) {
          final isAuthorized = userBloc.isAuthorized(incident);
          return Card(
            child: Column(
              key: ObjectKey(incident.id),
              children: <Widget>[
                ListTile(
                  selected: bloc.current == incident,
                  leading: CircleAvatar(
                    child: Text(
                      "${formatSince(incident.occurred)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                  title: Text(
                    incident.name,
                    style: TextStyle(fontSize: 20.0),
                  ),
                  subtitle: Text(
                    incident.reference ?? 'Ingen referanse',
                    style: TextStyle(fontSize: 14.0, color: Colors.black.withOpacity(0.5)),
                  ),
                  trailing: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          translateIncidentStatus(incident.status),
                          style: Theme.of(context).textTheme.caption,
                        )
                      ],
                    ),
                  ),
                ),
                if (isAuthorized) _buildMapTile(bloc, incident),
                if (isAuthorized)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Row(
                      children: [
                        Wrap(
                          children: [
                            Text(incident.justification),
                          ],
                        )
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    ButtonTheme.bar(
                      layoutBehavior: ButtonBarLayoutBehavior.constrained,
                      padding: EdgeInsets.only(right: 0.0),
                      // make buttons use the appropriate styles for cards
                      child: ButtonBar(
                        alignment: MainAxisAlignment.start,
                        children: <Widget>[
                          FlatButton(
                            child: Text(isAuthorized ? 'VELG' : 'LÅS OPP', style: TextStyle(fontSize: 14.0)),
                            padding: EdgeInsets.only(left: 16.0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: () {
                              if (isAuthorized) {
                                _selectAndReroute(bloc, incident, context);
                              } else {
                                Navigator.push(context, PasscodeRoute(incident));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            isAuthorized ? Icons.lock_open : Icons.lock,
                            color: isAuthorized ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                            size: 24.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }

  void _selectAndReroute(IncidentBloc bloc, Incident incident, BuildContext context) {
    bloc.select(incident.id);
    Navigator.pushReplacementNamed(context, 'incident');
  }

  Widget _buildMapTile(IncidentBloc bloc, Incident incident) {
    final point = incident.ipp != null ? toLatLng(incident.ipp) : Defaults.origo;
    return GestureDetector(
      child: Container(
        height: 240.0,
        child: IncidentMap(
          center: point,
          incident: incident,
          interactive: false,
        ),
      ),
      onTap: () => _selectAndReroute(bloc, incident, context),
    );
  }

  BottomAppBar _buildBottomAppBar() {
    return BottomAppBar(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.filter_list),
            color: Colors.white,
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: Icon(Icons.search),
            color: Colors.white,
            onPressed: () {},
          )
        ],
      ),
      shape: CircularNotchedRectangle(),
      color: Colors.grey[850],
    );
  }

  void _showFilterSheet(context) {
    final style = Theme.of(context).textTheme.title;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(builder: (context, state) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return DraggableScrollableSheet(
              expand: false,
              builder: (context, controller) {
                return ListView(
                  padding: EdgeInsets.only(bottom: 56.0),
                  children: <Widget>[
                    ListTile(
                      dense: landscape,
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
                    ...IncidentStatus.values
                        .map((status) => ListTile(
                            dense: landscape,
                            title: Text(translateIncidentStatus(status), style: style),
                            trailing: Switch(
                              value: _filter.contains(status),
                              onChanged: (value) => _onFilterChanged(status, value, state),
                            )))
                        .toList(),
                  ],
                );
              });
        });
      },
    );
  }

  void _onFilterChanged(IncidentStatus status, bool value, StateSetter update) {
    update(() {
      if (value) {
        _filter.add(status);
      } else if (_filter.length > 1) {
        _filter.remove(status);
      }
    });
  }
}
