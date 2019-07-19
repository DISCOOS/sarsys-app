import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/editors/incident_editor.dart';
import 'package:SarSys/popups/passcode_popup.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IncidentsScreen extends StatefulWidget {
  @override
  IncidentsScreenState createState() => IncidentsScreenState();
}

class IncidentsScreenState extends State<IncidentsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  IncidentBloc bloc;
  Set<IncidentStatus> filters;

  @override
  void initState() {
    super.initState();
    filters = Set.of([IncidentStatus.Registered, IncidentStatus.Handling, IncidentStatus.Other]);
    bloc = BlocProvider.of<IncidentBloc>(context).init(setState);
  }

  @override //new
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(context, bloc.isUnset),
          body: _buildBody(bloc, context, viewportConstraints),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              var incident = await showDialog(
                context: context,
                builder: (context) => IncidentEditor(),
              );
              if (incident != null) {
                print("Incident $incident");
                bloc.create(incident);
              }
            },
            tooltip: 'Ny hendelse',
            child: Icon(Icons.add),
            elevation: 2.0,
          ),
          bottomNavigationBar: _buildBottomAppBar(),
          extendBody: true,
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isUnset) {
    final userBloc = BlocProvider.of<UserBloc>(context);
    return AppBar(
      title: Text("Velg hendelse"),
      centerTitle: false,
      actions: <Widget>[
        if (isUnset)
          FlatButton(
            child: Text('LOGG UT', style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () async {
              userBloc
                  .logout()
                  .state
                  .where((state) => state is UserUnset)
                  .listen((_) => {Navigator.pushReplacementNamed(context, 'login')});
            },
          ),
      ],
    );
  }

  Widget _buildBody(IncidentBloc bloc, BuildContext context, BoxConstraints viewportConstraints) {
    return RefreshIndicator(
      onRefresh: () async {
        await bloc.fetch();
        setState(() {});
      },
      child: Container(
        color: Color.fromRGBO(168, 168, 168, 0.6),
        child: AnimatedCrossFade(
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
                padding: EdgeInsets.all(8.0),
                child: StreamBuilder(
                  stream: bloc.state,
                  builder: (context, snapshot) {
                    var cards = bloc.incidents
                        .where((incident) => filters.contains(incident.status))
                        .map((incident) => _buildCard(context, bloc, incident))
                        .toList();

                    return cards.isNotEmpty
                        ? Column(
                            children: cards,
                          )
                        : Center(
                            child: Text(
                              "0 av ${bloc.incidents.length} hendelser vises",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                  },
                ),
              ),
            ),
          ),
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
                if (isAuthorized) _buildMapTile(incident),
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
                                bloc.select(incident.id);
                                Navigator.pushReplacementNamed(context, 'incident');
                              } else {
                                Navigator.push(context, PasscodeRoute(incident));
                              }
                            },
                          ),
                          FlatButton(
                            child: Text('ENDRE', style: TextStyle(fontSize: 14.0)),
                            padding: EdgeInsets.only(left: 16.0, right: 16.0),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onPressed: isAuthorized
                                ? () async {
                                    var response = await showDialog(
                                      context: context,
                                      builder: (context) => IncidentEditor(incident: incident),
                                    );
                                    if (response != null) {
                                      bloc.update(response);
                                    }
                                  }
                                : null,
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

  static const BASEMAP = "https://opencache.statkart.no/gatekeeper/gk/gk.open_gmaps?layers=topo4&zoom={z}&x={x}&y={y}";

  Widget _buildMapTile(Incident incident) {
    final point = incident.ipp != null ? toLatLng(incident.ipp) : Defaults.origo;
    return Container(
        height: 240.0,
        child: IncidentMap(
          center: point,
          incident: incident,
          interactive: false,
        ));
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
                  ...IncidentStatus.values
                      .map((status) => ListTile(
                          title: Text(translateIncidentStatus(status), style: style),
                          trailing: Switch(
                            value: filters.contains(status),
                            onChanged: (value) => _onFilterChanged(status, value, state),
                          )))
                      .toList(),
                ],
              ),
            );
          });
        });
  }

  void _onFilterChanged(IncidentStatus status, bool value, StateSetter update) {
    update(() {
      if (value) {
        filters.add(status);
      } else {
        filters.remove(status);
      }
    });
  }
}