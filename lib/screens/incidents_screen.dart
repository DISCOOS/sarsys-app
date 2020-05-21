import 'dart:convert';

import 'package:SarSys/blocs/incident_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/models/Incident.dart';
import 'package:SarSys/popups/passcode_popup.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:SarSys/usecase/incident_user_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

class IncidentsScreen extends Screen<IncidentsScreenState> {
  static const ROUTE = 'incident/list';
  @override
  IncidentsScreenState createState() => IncidentsScreenState();
}

class IncidentsScreenState extends ScreenState<IncidentsScreen, void> {
  static const FILTER = "incidents_filter";

  Set<IncidentStatus> _filter;

  IncidentsScreenState()
      : super(
          title: "Aksjoner",
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(context, FILTER,
        defaultValue: Set.of([
          IncidentStatus.Registered,
          IncidentStatus.Handling,
          IncidentStatus.Other,
        ]),
        onRead: _onRead);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    writeRoute();
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
    return context.bloc<UserBloc>()?.user?.isCommander == true
        ? FloatingActionButton(
            onPressed: () => _create(context),
            tooltip: 'Ny aksjon',
            child: Icon(Icons.add),
            elevation: 2.0,
          )
        : null;
  }

  Future _create(BuildContext context) async {
    var result = await createIncident();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) => FilterSheet<IncidentStatus>(
        initial: _filter,
        identifier: FILTER,
        bucket: PageStorage.of(context),
        onRead: (value) => _onRead(value),
        onWrite: (value) => enumName(value),
        onBuild: () => IncidentStatus.values.map((status) => FilterData(
              key: status,
              title: translateIncidentStatus(status),
            )),
        onChanged: (Set<IncidentStatus> selected) => setState(() => _filter = selected),
      ),
    );
  }

  IncidentStatus _onRead(value) => IncidentStatus.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => IncidentStatus.Registered,
      );
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
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await context.bloc<IncidentBloc>().load();
          setState(() {});
        },
        child: StreamBuilder(
          stream: context.bloc<IncidentBloc>(),
          builder: (context, snapshot) {
            if (snapshot.hasData == false) return Container();
            var cards = snapshot.connectionState == ConnectionState.active && snapshot.hasData
                ? _filteredIncidents().map((incident) => _buildCard(incident)).toList()
                : [];
            return cards.isEmpty
                ? toRefreshable(
                    viewportConstraints,
                    message: "0 av ${context.bloc<IncidentBloc>().incidents.length} hendelser vises",
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

  List<Incident> _filteredIncidents() {
    return context
        .bloc<IncidentBloc>()
        .incidents
        .where((incident) => widget.filter.contains(incident.status))
        .where((incident) => widget.query == null || _prepare(incident).contains(widget.query.toLowerCase()))
        .toList()
          ..sort(
            (i1, i2) => i2.occurred.compareTo(i1.occurred),
          );
  }

  String _prepare(Incident incident) => "${incident.searchable}".toLowerCase();

  Widget _buildCard(Incident incident) {
    final title = Theme.of(context).textTheme.headline6;
    final caption = Theme.of(context).textTheme.caption;

    return StreamBuilder(
        stream: context.bloc<UserBloc>(),
        builder: (context, snapshot) {
          if (snapshot.hasData == false) return Container();
          final isCurrent = context.bloc<IncidentBloc>().selected == incident;
          final isAuthorized = context.bloc<UserBloc>().isAuthorized(incident);
          return Card(
            child: Column(
              key: ObjectKey(incident.uuid),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                incident?.exercise == true
                    ? Banner(
                        message: "Øvelse",
                        location: BannerLocation.topEnd,
                        child: _buildCardHeader(context, incident, title, caption),
                      )
                    : _buildCardHeader(context, incident, title, caption),
                if (isAuthorized) _buildMapTile(incident),
                if (isAuthorized)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Text(
                      _toDescription(incident),
                      softWrap: true,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.0),
                      child: ButtonBarTheme(
                        // make buttons use the appropriate styles for cards
                        child: ButtonBar(
                          alignment: MainAxisAlignment.start,
                          children: <Widget>[
                            FlatButton(
                              child: Text(
                                isAuthorized
                                    ? (isCurrent ? 'FORLAT' : 'DELTA')
                                    : hasRoles ? 'LÅS OPP' : 'INGEN TILGANG',
                                style: TextStyle(fontSize: 14.0),
                              ),
                              padding: EdgeInsets.only(left: isAuthorized ? 16.0 : 16.0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: isAuthorized || hasRoles
                                  ? () async {
                                      if (isCurrent) {
                                        await _leaveAndReroute();
                                      } else if (isAuthorized) {
                                        await _joinAndReroute(incident);
                                      } else {
                                        Navigator.push(context, PasscodeRoute(incident));
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                        data: ButtonBarThemeData(
                          layoutBehavior: ButtonBarLayoutBehavior.constrained,
                          buttonPadding: EdgeInsets.only(right: 0.0),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          if (context.bloc<UserBloc>().isAuthor(incident) || !context.bloc<UserBloc>().hasRoles)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                context.bloc<UserBloc>().isAuthor(incident) || context.bloc<UserBloc>().hasRoles
                                    ? 'Min aksjon'
                                    : 'Ingen roller',
                                style: Theme.of(context).textTheme.caption,
                              ),
                            ),
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

  ListTile _buildCardHeader(BuildContext context, Incident incident, TextStyle title, TextStyle caption) {
    return ListTile(
      selected: context.bloc<IncidentBloc>().selected == incident,
      title: Text(
        incident.name,
        style: title,
      ),
      subtitle: Text(
        incident.reference ?? 'Ingen referanse',
        style: TextStyle(
          fontSize: 14.0,
          color: Colors.black.withOpacity(0.5),
        ),
      ),
      trailing: _buildCardStatus(incident, caption),
    );
  }

  Padding _buildCardStatus(Incident incident, TextStyle caption) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0, right: (incident.exercise ? 24.0 : 0.0)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            translateIncidentStatus(incident.status),
            style: caption,
          ),
          Text(
            "${formatSince(incident.occurred)}",
            style: caption,
          ),
        ],
      ),
    );
  }

  bool get hasRoles => context.bloc<UserBloc>()?.hasRoles == true;

  String _toDescription(Incident incident) {
    String meetup = incident.meetup.description;
    return "${_replaceLast(incident.justification)}.\n"
        "Oppmøte ${toUTM(incident.meetup.point)}"
        "${meetup == null ? "." : ", ${meetup.toLowerCase()}."}";
  }

  String _replaceLast(String text) => text.replaceFirst(r'.', "", text.length - 1);

  Widget _buildMapTile(Incident incident) {
    final ipp = incident.ipp != null ? toLatLng(incident.ipp.point) : null;
    final meetup = incident.meetup != null ? toLatLng(incident.meetup.point) : null;
    final fitBounds = (ipp == null || meetup == null) == false ? LatLngBounds(ipp, meetup) : null;
    return ClipRect(
      child: GestureDetector(
        child: Container(
          height: 240.0,
          child: MapWidget(
            center: meetup ?? ipp,
            fitBounds: fitBounds,
            fitBoundOptions: FitBoundsOptions(
              zoom: Defaults.zoom,
              maxZoom: Defaults.zoom,
              padding: EdgeInsets.all(48.0),
            ),
            incident: incident,
            interactive: false,
            withRead: true,
          ),
        ),
        onTap: () => _joinAndReroute(incident),
      ),
    );
  }

  Future _leaveAndReroute() async {
    final result = await leaveIncident();
    if (result.isRight()) {
      jumpToMe(context);
    }
  }

  Future _joinAndReroute(Incident incident) async {
    final result = await joinIncident(incident);
    if (result.isRight()) {
      jumpToIncident(context, incident);
    }
  }
}

class IncidentSearch extends SearchDelegate<Incident> {
  static final _storage = Storage.secure;
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
            style: theme.textTheme.subtitle2.copyWith(fontWeight: FontWeight.bold),
            children: <TextSpan>[
              TextSpan(
                text: suggestions[index].substring(query.length),
                style: theme.textTheme.subtitle2,
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
