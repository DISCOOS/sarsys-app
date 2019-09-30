import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/incident_map.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/popups/passcode_popup.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/usecase/incident.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

class IncidentsScreen extends Screen<IncidentsScreenState> {
  @override
  IncidentsScreenState createState() => IncidentsScreenState();
}

class IncidentsScreenState extends ScreenState {
  UserBloc _userBloc;
  IncidentBloc _incidentBloc;
  Set<IncidentStatus> _filter;

  IncidentsScreenState()
      : super(
          title: "Velg hendelse",
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );

  @override
  void initState() {
    super.initState();
    _filter = Set.of([IncidentStatus.Registered, IncidentStatus.Handling, IncidentStatus.Other]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return RefreshIndicator(
      onRefresh: () async {
        await _incidentBloc.fetch();
        setState(() {});
      },
      child: Container(
        color: Color.fromRGBO(168, 168, 168, 0.6),
        child: StreamBuilder(
          stream: _incidentBloc.state,
          builder: (context, snapshot) {
            var cards = _incidentBloc.incidents
                .where((incident) => _filter.contains(incident.status))
                .map((incident) => _buildCard(incident))
                .toList();
            return AnimatedCrossFade(
              duration: Duration(milliseconds: 300),
              crossFadeState: _incidentBloc.incidents.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Center(
                child: CircularProgressIndicator(),
              ),
              secondChild: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 96.0),
                    child: cards.isNotEmpty
                        ? Column(
                            children: cards,
                          )
                        : Center(
                            child: Text(
                              "0 av ${_incidentBloc.incidents.length} hendelser vises",
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

  @override
  FloatingActionButton buildFAB(BuildContext context) {
    return _userBloc?.user?.isCommander == true
        ? FloatingActionButton(
            onPressed: () => _create(context),
            tooltip: 'Ny hendelse',
            child: Icon(Icons.add),
            elevation: 2.0,
          )
        : null;
  }

  Future _create(BuildContext context) async {
    var result = await createIncident(context);
    result.fold((_) => null, (incident) => jumpToIncident(context, incident));
  }

  Widget _buildCard(Incident incident) {
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
                  selected: _incidentBloc.current == incident,
                  leading: CircleAvatar(
                    child: Text(
                      "${formatSince(incident.occurred, withUnits: false)}",
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
                    ButtonBarTheme(
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
                                _selectAndReroute(incident);
                              } else {
                                Navigator.push(context, PasscodeRoute(incident));
                              }
                            },
                          ),
                        ],
                      ),
                      data: ButtonBarThemeData(
                        layoutBehavior: ButtonBarLayoutBehavior.constrained,
                        buttonPadding: EdgeInsets.only(right: 0.0),
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

  Widget _buildMapTile(Incident incident) {
    final ipp = incident.ipp != null ? toLatLng(incident.ipp) : null;
    final meetup = incident.meetup != null ? toLatLng(incident.meetup) : null;
    final fitBounds = (ipp == null || meetup == null) == false ? LatLngBounds(ipp, meetup) : null;
    return GestureDetector(
      child: Container(
        height: 240.0,
        child: IncidentMap(
          center: meetup ?? ipp,
          fitBounds: fitBounds.isValid ? fitBounds : null,
          fitBoundOptions: FitBoundsOptions(zoom: Defaults.zoom, maxZoom: Defaults.zoom, padding: EdgeInsets.all(48.0)),
          incident: incident,
          interactive: false,
        ),
      ),
      onTap: () => _selectAndReroute(incident),
    );
  }

  void _selectAndReroute(Incident incident) {
    _incidentBloc.select(incident.id);
    jumpToIncident(context, incident);
  }

  @override
  BottomAppBar bottomNavigationBar(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.filter_list),
            color: Colors.white,
            onPressed: () => _showFilterSheet(),
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

  void _showFilterSheet() {
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
                        child: Text('LUKK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
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
      setState(() {});
    });
  }
}
