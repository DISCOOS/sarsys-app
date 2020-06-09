import 'dart:convert';

import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/unit/presentation/screens/unit_screen.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class MissionsPage extends StatefulWidget {
  final bool withActions;
  final String query;
  final bool Function(Unit unit) where;
  final void Function(Unit unit) onSelection;
  final Comparator<Unit> compareTo;

  const MissionsPage({
    Key key,
    this.withActions = true,
    this.onSelection,
    this.query,
    this.where,
    this.compareTo,
  }) : super(key: key);

  @override
  MissionsPageState createState() => MissionsPageState();
}

class MissionsPageState extends State<MissionsPage> {
  static const STATE = "missions_filter";
  StreamGroup<dynamic> _group;

  Set<UnitStatus> _filter;

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(
      context,
      STATE,
      defaultValue: UnitStatus.values.toSet()..remove(UnitStatus.retired),
      onRead: _onRead,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UnitBloc>())
      ..add(context.bloc<TrackingBloc>())
      ..add(context.bloc<UserBloc>());
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
            context.bloc<UnitBloc>().load();
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
                            : widget.query == null ? "Legg til oppdrag" : "Ingen oppdrag funnet",
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
    return context
        .bloc<UnitBloc>()
        .units
        .values
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
        child: Text("Antall oppdrag: $index"),
      );
    }
    var unit = units[index];
    var tracking = unit.tracking == null ? null : context.bloc<TrackingBloc>().trackings[unit.tracking.uuid];
    var status = tracking?.status ?? TrackingStatus.none;
    return widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true
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
      key: ObjectKey(unit.uuid),
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
              label: Text("${formatSince(tracking?.position?.timestamp, defaultValue: "Ingen")}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                Icons.my_location,
                size: 16.0,
                color: toPositionStatusColor(tracking?.position),
              ),
            ),
            if (widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true)
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
      onTap: () async => await editUnit(unit),
    );
  }

  IconSlideAction _buildTransitionAction(BuildContext context, Unit unit) {
    switch (unit.status) {
      case UnitStatus.retired:
        return IconSlideAction(
          caption: 'MOBILISERT',
          color: toUnitStatusColor(UnitStatus.mobilized),
          icon: Icons.send,
          onTap: () async => await mobilizeUnit(unit),
        );
      case UnitStatus.mobilized:
        return IconSlideAction(
          caption: 'DEPLOYERT',
          color: Colors.green,
          icon: Icons.send,
          onTap: () async => await deployUnit(unit),
        );
      case UnitStatus.deployed:
      default:
        return IconSlideAction(
          caption: 'OPPLØST',
          color: toUnitStatusColor(UnitStatus.retired),
          icon: Icons.delete,
          onTap: () async => await retireUnit(unit),
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

  UnitStatus _onRead(value) => UnitStatus.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => UnitStatus.mobilized,
      );
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

class MissionSearch extends SearchDelegate<Unit> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/unit/recent";

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  MissionSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final List recent = stored != null
        ? json.decode(stored)
        : [
            translateUnitType(UnitType.team),
            translateUnitType(UnitType.vehicle),
            translateUnitStatus(UnitStatus.mobilized)
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
    return MissionsPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}

Future<Unit> selectMission(
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
        body: MissionsPage(
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
