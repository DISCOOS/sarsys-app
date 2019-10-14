import 'dart:convert';

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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IncidentsScreen extends Screen<IncidentsScreenState> {
  @override
  IncidentsScreenState createState() => IncidentsScreenState();
}

class IncidentsScreenState extends ScreenState {
  UserBloc _userBloc;

  final Set<IncidentStatus> _filter = Set.of([
    IncidentStatus.Registered,
    IncidentStatus.Handling,
    IncidentStatus.Other,
  ]);

  IncidentsScreenState()
      : super(
          title: "Velg hendelse",
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
  }

  @override
  Widget buildBody(BuildContext context, BoxConstraints constraints) {
    return Container(
      height: constraints.maxHeight,
      color: Color.fromRGBO(168, 168, 168, 0.6),
      child: IncidentsPage(filter: _filter),
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

  @override
  List<Widget> buildAppBarActions() => <Widget>[
        IconButton(
          icon: Icon(Icons.search),
          color: Colors.white,
          onPressed: () => showSearch(context: context, delegate: IncidentSearch(_filter)),
        ),
        IconButton(
          icon: Icon(Icons.filter_list),
          color: Colors.white,
          onPressed: () => _showFilterSheet(),
        ),
      ];

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

class IncidentsPage extends StatefulWidget {
  final String query;
  final Set<IncidentStatus> filter;

  const IncidentsPage({
    Key key,
    @required this.filter,
    this.query,
  }) : super(key: key);

  @override
  _IncidentsPageState createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  UserBloc _userBloc;
  IncidentBloc _incidentBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _incidentBloc = BlocProvider.of<IncidentBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await _incidentBloc.fetch();
          setState(() {});
        },
        child: StreamBuilder(
          stream: _incidentBloc.state,
          builder: (context, snapshot) {
            if (snapshot.hasData == false) return Container();
            var cards = snapshot.connectionState == ConnectionState.active && snapshot.hasData
                ? _incidentBloc.incidents
                    .where((incident) => widget.filter.contains(incident.status))
                    .where(
                        (incident) => widget.query == null || _prepare(incident).contains(widget.query.toLowerCase()))
                    .map((incident) => _buildCard(incident))
                    .toList()
                : [];
            return cards.isEmpty
                ? toRefreshable(
                    viewportConstraints,
                    message: "0 av ${_incidentBloc.incidents.length} hendelser vises",
                  )
                : toRefreshable(
                    viewportConstraints,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 96.0),
                      child: Column(
                        children: cards,
                      ),
                    ),
                  );
          },
        ),
      );
    });
  }

  String _prepare(Incident incident) => "${incident.searchable}".toLowerCase();

  Future _create(BuildContext context) async {
    var result = await createIncident(context);
    result.fold((_) => null, (incident) => jumpToIncident(context, incident));
  }

  Widget _buildCard(Incident incident) {
    final userBloc = BlocProvider.of<UserBloc>(context);

    return StreamBuilder(
        stream: userBloc.state,
        builder: (context, snapshot) {
          if (snapshot.hasData == false) return Container();
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
    final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
    final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
    final fitBounds = (ipp == null || meetup == null) == false ? LatLngBounds(ipp, meetup) : null;
    return GestureDetector(
      child: Container(
        height: 240.0,
        child: IncidentMap(
          center: meetup ?? ipp,
          fitBounds: fitBounds,
          fitBoundOptions: FitBoundsOptions(
            zoom: Defaults.zoom,
            maxZoom: Defaults.zoom,
            padding: EdgeInsets.all(48.0),
          ),
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
}

class IncidentSearch extends SearchDelegate<Incident> {
  static final _storage = new FlutterSecureStorage();
  static const RECENT_KEY = "search/incident/recent";

  final Set<IncidentStatus> filter;

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  IncidentSearch(this.filter) {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final List recent = stored != null
        ? json.decode(stored)
        : [
            translateIncidentType(IncidentType.Lost),
            translateIncidentType(IncidentType.Distress),
            translateIncidentStatus(IncidentStatus.Other)
          ];
    _recent.value = recent.map((suggestion) => suggestion as String).toSet();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _recent,
      builder: (BuildContext context, Set<String> suggestions, Widget child) {
        return _buildSuggestionList(
          context,
          suggestions?.where((suggestion) => suggestion.toLowerCase().startsWith(query.toLowerCase()))?.toList() ?? [],
        );
      },
    );
  }

  ListView _buildSuggestionList(BuildContext context, List<String> suggestions) {
    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      itemBuilder: (context, index) => ListTile(
        leading: Icon(Icons.group),
        title: RichText(
          text: TextSpan(
            text: suggestions[index].substring(0, query.length),
            style: theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(
                text: suggestions[index].substring(query.length),
                style: theme.textTheme.subhead,
              ),
            ],
          ),
        ),
        trailing: index > 2
            ? IconButton(
                icon: Icon(Icons.delete),
                onPressed: () => _delete(context, suggestions, index),
              )
            : null,
        onTap: () {
          query = suggestions[index];
          showResults(context);
        },
      ),
      itemCount: suggestions.length,
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final recent = _recent.value.toSet()..add(query);
    _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
    _recent.value = recent.toSet() ?? [];
    return IncidentsPage(query: query, filter: filter);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}
