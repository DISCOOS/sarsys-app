import 'dart:convert';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/unit_screen.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UnitsPage extends StatefulWidget {
  final bool withActions;
  final String query;
  final bool Function(Unit unit) where;
  final void Function(Unit unit) onSelection;
  final Comparator<Unit> compareTo;

  const UnitsPage({
    Key key,
    this.withActions = true,
    this.onSelection,
    this.query,
    this.where,
    this.compareTo,
  }) : super(key: key);

  @override
  UnitsPageState createState() => UnitsPageState();
}

class UnitsPageState extends State<UnitsPage> {
  static const STATE = "units_filter";
  UserBloc _userBloc;
  UnitBloc _unitBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Set<UnitStatus> _filter;

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(
      context,
      STATE,
      defaultValue: UnitStatus.values.toSet()..remove(UnitStatus.Retired),
      onRead: _onRead,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()..add(_unitBloc.state)..add(_trackingBloc.state)..add(_userBloc.state);
  }

  @override
  void dispose() {
    _group.close();
    _group = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return RefreshIndicator(
          onRefresh: () async {
            _unitBloc.fetch();
          },
          child: Container(
            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var units = _filteredUnits();
                return units.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        viewportConstraints,
                        message: snapshot.hasError
                            ? snapshot.error
                            : widget.query == null ? "Legg til enhet" : "Ingen enheter funnet",
                      )
                    : _buildList(units);
              },
            ),
          ),
        );
      },
    );
  }

  List<Unit> _filteredUnits() {
    return _unitBloc.units.values
        .where((unit) => _filter.contains(unit.status))
        .where((unit) => widget.where == null || widget.where(unit))
        .where((unit) => widget.query == null || _prepare(unit).contains(widget.query.toLowerCase()))
        .toList()
          ..sort(
            (u1, u2) => widget.compareTo == null
                ? u1.callsign.toLowerCase().compareTo(u2.callsign.toLowerCase())
                : widget.compareTo(u1, u2),
          );
  }

  String _prepare(Unit unit) => "${unit.searchable}".toLowerCase();

  ListView _buildList(List units) {
    return ListView.builder(
      itemCount: units.length + 1,
      itemExtent: 72.0,
      itemBuilder: (context, index) {
        return _buildUnit(units, index);
      },
    );
  }

  Widget _buildUnit(List<Unit> units, int index) {
    if (index == units.length) {
      return Center(
        child: Text("Antall enheter: $index"),
      );
    }
    var unit = units[index];
    var tracking = unit.tracking == null ? null : _trackingBloc.tracking[unit.tracking];
    var status = tracking?.status ?? TrackingStatus.None;
    return widget.withActions && _userBloc?.user?.isCommander == true
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildUnitTile(unit, status, tracking),
            secondaryActions: <Widget>[
              _buildEditAction(context, unit),
              _buildTransitionAction(context, unit),
            ],
          )
        : _buildUnitTile(unit, status, tracking);
  }

  Widget _buildUnitTile(Unit unit, TrackingStatus status, Tracking tracking) {
    return Container(
      key: ObjectKey(unit.id),
      color: Colors.white,
      constraints: BoxConstraints.expand(),
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: GestureDetector(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            UnitAvatar(unit: unit, tracking: tracking),
            SizedBox(width: 16.0),
            Chip(
              label: Text("${unit.callsign}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                Icons.headset_mic,
                size: 16.0,
                color: Colors.black38,
              ),
            ),
            SizedBox(width: 16.0),
            Expanded(
              child: Text(unit.name, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 4.0),
            Chip(
              label: Text("${formatSince(tracking?.point?.timestamp, defaultValue: "Ingen")}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                Icons.my_location,
                size: 16.0,
                color: toPointStatusColor(tracking?.point),
              ),
            ),
            if (widget.withActions && _userBloc?.user?.isCommander == true)
              RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
          ],
        ),
        onTap: () => _onTap(unit),
      ),
    );
  }

  _onTap(Unit unit) {
    if (widget.onSelection == null) {
      Navigator.pushNamed(context, UnitScreen.ROUTE, arguments: unit);
    } else {
      widget.onSelection(unit);
    }
  }

  IconSlideAction _buildEditAction(BuildContext context, Unit unit) {
    return IconSlideAction(
      caption: 'ENDRE',
      color: Theme.of(context).buttonColor,
      icon: Icons.more_horiz,
      onTap: () async => await editUnit(context, unit),
    );
  }

  IconSlideAction _buildTransitionAction(BuildContext context, Unit unit) {
    switch (unit.status) {
      case UnitStatus.Retired:
        return IconSlideAction(
          caption: 'MOBILISERT',
          color: toUnitStatusColor(UnitStatus.Mobilized),
          icon: Icons.send,
          onTap: () async => await mobilizeUnit(context, unit),
        );
      case UnitStatus.Mobilized:
        return IconSlideAction(
          caption: 'DEPLOYERT',
          color: Colors.green,
          icon: Icons.send,
          onTap: () async => await deployUnit(context, unit),
        );
      case UnitStatus.Deployed:
      default:
        return IconSlideAction(
          caption: 'OPPLØST',
          color: toUnitStatusColor(UnitStatus.Retired),
          icon: Icons.delete,
          onTap: () async => await retireUnit(context, unit),
        );
    }
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) => FilterSheet<UnitStatus>(
        initial: _filter,
        identifier: STATE,
        bucket: PageStorage.of(context),
        onRead: (value) => _onRead(value),
        onWrite: (value) => enumName(value),
        onBuild: () => UnitStatus.values.map(
          (status) => FilterData(
            key: status,
            title: translateUnitStatus(status),
          ),
        ),
        onChanged: (Set<UnitStatus> selected) => setState(() => _filter = selected),
      ),
    );
  }

  UnitStatus _onRead(value) => UnitStatus.values.firstWhere((e) => value == enumName(e));
}

class UnitAvatar extends StatelessWidget {
  final Unit unit;
  final Tracking tracking;
  const UnitAvatar({
    Key key,
    this.unit,
    this.tracking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: toUnitStatusColor(unit.status),
      child: Stack(
        children: <Widget>[
          Center(child: Icon(toUnitIconData(unit.type))),
          Positioned(
            left: 20,
            top: 20,
            child: Container(
              padding: EdgeInsets.all(0.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Icon(
                toTrackingIconData(tracking?.status),
                size: 20,
                color: toTrackingStatusColor(tracking?.status),
              ),
            ),
          ),
        ],
      ),
      foregroundColor: Colors.white,
    );
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
    return UnitsPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}

Future<Unit> selectUnit(
  BuildContext context, {
  String query,
  bool where(Unit unit),
  Comparator<Unit> compareTo,
}) async {
  return await showDialog<Unit>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Velg enhet", textAlign: TextAlign.start),
        ),
        body: UnitsPage(
          where: where,
          query: query,
          compareTo: compareTo,
          withActions: false,
          onSelection: (unit) => Navigator.pop(context, unit),
        ),
      );
    },
  );
}
