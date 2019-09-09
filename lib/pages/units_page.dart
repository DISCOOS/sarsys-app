import 'dart:convert';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

typedef SelectionCallback = void Function(Unit unit);

class UnitsPage extends StatefulWidget {
  final bool withActions;
  final String query;
  final SelectionCallback onSelection;

  const UnitsPage({Key key, this.query, this.withActions = true, this.onSelection}) : super(key: key);

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
    _group = StreamGroup.broadcast()..add(_unitBloc.state)..add(_trackingBloc.state);
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
                    : _unitBloc.units.values
                        .where((unit) =>
                            _filter.contains(unit.status) &&
                            (widget.query == null || _prepare(unit).contains(widget.query.toLowerCase())))
                        .toList();

                return AnimatedCrossFade(
                  duration: Duration(milliseconds: 300),
                  crossFadeState: _unitBloc.units.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Center(
                    child: CircularProgressIndicator(),
                  ),
                  secondChild: units.isEmpty || snapshot.hasError
                      ? Center(
                          child: Text(
                          snapshot.hasError
                              ? snapshot.error
                              : widget.query == null ? "Legg til en enhet" : "Ingen enheter funnet",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ))
                      : _buildList(units),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _prepare(Unit unit) => "${unit.searchable}".toLowerCase();

  ListView _buildList(List units) {
    return ListView.builder(
      itemCount: units.length + 1,
      itemBuilder: (context, index) {
        return _buildUnit(units, index);
      },
    );
  }

  Widget _buildUnit(List<Unit> units, int index) {
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
    var status = tracking?.status ?? TrackingStatus.None;
    return widget.withActions
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildListTile(unit, status, tracking),
            secondaryActions: <Widget>[
              if (tracking?.location != null) _buildTrackingAction(context, status, tracking),
              _buildEditAction(context, unit),
              _buildCloseAction(context, unit),
            ],
          )
        : _buildListTile(unit, status, tracking);
  }

  Container _buildListTile(Unit unit, TrackingStatus status, Tracking tracking) {
    final caption = Theme.of(context).textTheme.caption.copyWith(fontSize: 11);
    return Container(
      color: Colors.white,
      child: ListTile(
        key: ObjectKey(unit.id),
        leading: CircleAvatar(
          backgroundColor: toTrackingStatusColor(context, status),
          child: Icon(Icons.people),
          foregroundColor: Colors.white,
        ),
        title: Text(unit.callsign),
        subtitle: Text(
          "${translateUnitType(unit.type)} "
          "${translateUnitStatus(unit.status).toLowerCase()}, "
          "${toUTM(tracking?.location, empty: "Ingen posisjon")}",
          style: caption,
        ),
        dense: true,
        trailing: widget.withActions
            ? RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey.withOpacity(0.2),
                ),
              )
            : null,
        onTap: () => _onTap(unit, tracking),
      ),
    );
  }

  _onTap(Unit unit, Tracking tracking) {
    if (widget.onSelection == null) {
      jumpToPoint(context, center: tracking?.location);
    } else {
      widget.onSelection(unit);
    }
  }

  IconSlideAction _buildTrackingAction(BuildContext context, TrackingStatus status, Tracking tracking) {
    return IconSlideAction(
      caption: 'SPORING',
      color: toTrackingStatusColor(context, status),
      icon: toTrackingIconData(context, status),
      onTap: () => _trackingBloc.transition(tracking),
    );
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

  void showFilterSheet(BuildContext context) {
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
                    ...UnitStatus.values
                        .map((status) => ListTile(
                            dense: landscape,
                            title: Text(translateUnitStatus(status), style: style),
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

  void _onFilterChanged(UnitStatus status, bool value, StateSetter update) {
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

class UnitSearch extends SearchDelegate<Unit> {
  static final _storage = new FlutterSecureStorage();
  static const RECENT_KEY = "search/unit/recent";

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  UnitSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final List recent = stored != null
        ? json.decode(stored)
        : [
            translateUnitType(UnitType.Team),
            translateUnitType(UnitType.Vehicle),
            translateUnitStatus(UnitStatus.Mobilized)
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
          suggestions.where((suggestion) => suggestion.toLowerCase().startsWith(query.toLowerCase())).toList(),
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
    _recent.value = recent.toSet();
    return UnitsPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet();
    buildSuggestions(context);
  }
}
