import 'dart:convert';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/personnel_screen.dart';
import 'package:SarSys/usecase/personnel.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/affilliation.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class UserHistoryPage extends StatefulWidget {
  final bool withActions;
  final String query;
  final bool Function(Personnel personnel) where;
  final void Function(Personnel personnel) onSelection;

  const UserHistoryPage({
    Key key,
    this.query,
    this.withActions = true,
    this.onSelection,
    this.where,
  }) : super(key: key);

  @override
  UserHistoryPageState createState() => UserHistoryPageState();
}

class UserHistoryPageState extends State<UserHistoryPage> {
  static const FILTER = "personnel_filter";
  UserBloc _userBloc;
  PersonnelBloc _personnelBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Set<PersonnelStatus> _filter;

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(
      context,
      FILTER,
      defaultValue: PersonnelStatus.values.toSet()..remove(PersonnelStatus.Retired),
      onRead: _onRead,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _personnelBloc = BlocProvider.of<PersonnelBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()..add(_personnelBloc.state)..add(_trackingBloc.state)..add(_userBloc.state);
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
            _personnelBloc.fetch();
          },
          child: Container(
            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var personnel = _filteredPersonnel();
                return personnel.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        viewportConstraints,
                        message: snapshot.hasError
                            ? snapshot.error
                            : widget.query == null ? "Min historikk" : "Ingen bruker",
                      )
                    : _buildList(personnel);
              },
            ),
          ),
        );
      },
    );
  }

  List<Personnel> _filteredPersonnel() {
    return _personnelBloc.personnel.values
        .where((personnel) => _filter.contains(personnel.status))
        .where((personnel) => widget.where == null || widget.where(personnel))
        .where((personnel) => widget.query == null || _prepare(personnel).contains(widget.query.toLowerCase()))
        .toList()
          ..sort((p1, p2) => p1.name.toLowerCase().compareTo(p2.name.toLowerCase()));
  }

  String _prepare(Personnel personnel) => "${personnel.searchable}".toLowerCase();

  ListView _buildList(List personnel) {
    return ListView.builder(
      itemCount: personnel.length + 1,
      itemExtent: 72.0,
      itemBuilder: (context, index) {
        return _buildPersonnel(personnel, index);
      },
    );
  }

  Widget _buildPersonnel(List<Personnel> items, int index) {
    if (index == items.length) {
      return Center(
        child: Text("Antall mannskaper: $index"),
      );
    }
    var personnel = items[index];
    var unit = _toUnit(personnel);
    var tracking = _trackingBloc.tracking[personnel.tracking];
    var status = tracking?.status ?? TrackingStatus.None;
    return widget.withActions && _userBloc?.user?.isCommander == true
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildPersonnelTile(unit, personnel, status, tracking),
            secondaryActions: <Widget>[
              _buildEditAction(context, personnel),
              _buildTransitionAction(context, personnel),
              if (unit == null) ...[
                _buildCreateUnitAction(personnel),
                _buildAddToUnitAction(personnel),
              ] else
                _buildRemoveFromUnitAction(unit, personnel)
            ],
          )
        : _buildPersonnelTile(unit, personnel, status, tracking);
  }

  Widget _buildPersonnelTile(Unit unit, Personnel personnel, TrackingStatus status, Tracking tracking) {
    return Container(
      key: ObjectKey(personnel.id),
      color: Colors.white,
      constraints: BoxConstraints.expand(),
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: GestureDetector(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            PersonnelAvatar(personnel: personnel, tracking: tracking),
            SizedBox(width: 16.0),
            Chip(
              label: Text("${personnel.name}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: new AffiliationAvatar(
                size: 6.0,
                maxRadius: 10.0,
                affiliation: personnel?.affiliation,
              ),
            ),
            Spacer(),
            Chip(
              label: Text(
                _toUsage(unit, personnel, tracking),
                textAlign: TextAlign.end,
              ),
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
        onTap: () => _onTap(personnel),
      ),
    );
  }

  String _toUsage(
    Unit unit,
    Personnel personnel,
    Tracking tracking,
  ) =>
      [
        unit?.name ?? '',
        formatSince(tracking?.point?.timestamp, defaultValue: "Ingen"),
      ].where((value) => emptyAsNull(value) != null).join(' ');

  _onTap(Personnel personnel) {
    if (widget.onSelection == null) {
      Navigator.pushNamed(context, PersonnelScreen.ROUTE, arguments: personnel);
    } else {
      widget.onSelection(personnel);
    }
  }

  IconSlideAction _buildEditAction(BuildContext context, Personnel personnel) => IconSlideAction(
        caption: 'ENDRE',
        color: Theme.of(context).buttonColor,
        icon: Icons.more_horiz,
        onTap: () async => await editPersonnel(context, personnel),
      );

  Widget _buildAddToUnitAction(Personnel personnel) => Tooltip(
        message: "Knytt til enhet",
        child: IconSlideAction(
          caption: 'KNYTT',
          color: Theme.of(context).buttonColor,
          icon: Icons.people,
          onTap: () async => await addToUnit(context, personnel: [personnel]),
        ),
      );

  Widget _buildRemoveFromUnitAction(Unit unit, Personnel personnel) => Tooltip(
        message: "Fjern fra enhet",
        child: IconSlideAction(
          caption: 'FJERN',
          color: Colors.red,
          icon: Icons.people,
          onTap: () async {
            if (unit != null) {
              await removeFromUnit(context, unit, personnel: [personnel]);
            }
          },
        ),
      );

  Unit _toUnit(Personnel personnel) => _trackingBloc.unitBloc.units.values.firstWhere(
        (unit) => unit.personnel?.contains(personnel) == true,
        orElse: () => null,
      );

  Widget _buildCreateUnitAction(Personnel personnel) => Tooltip(
        message: "Opprett enhet med mannskap",
        child: IconSlideAction(
          caption: 'OPPRETT',
          color: Theme.of(context).buttonColor,
          icon: Icons.group_add,
          onTap: () async => await createUnit(context, personnel: [personnel]),
        ),
      );

  IconSlideAction _buildTransitionAction(BuildContext context, Personnel personnel) {
    switch (personnel.status) {
      case PersonnelStatus.Retired:
        return IconSlideAction(
          caption: 'MOBILISERT',
          color: toPersonnelStatusColor(PersonnelStatus.Mobilized),
          icon: Icons.check_circle,
          onTap: () async => await checkInPersonnel(context, personnel),
        );
      case PersonnelStatus.Mobilized:
        return IconSlideAction(
          caption: 'ANKOMMET',
          color: toPersonnelStatusColor(PersonnelStatus.OnScene),
          icon: Icons.check_circle,
          onTap: () async => await checkInPersonnel(context, personnel),
        );
      case PersonnelStatus.OnScene:
      default:
        return IconSlideAction(
          caption: 'DIMMITERT',
          color: toPersonnelStatusColor(PersonnelStatus.Retired),
          icon: Icons.archive,
          onTap: () async => await retirePersonnel(context, personnel),
        );
    }
  }

  void showFilterSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext bc) => FilterSheet<PersonnelStatus>(
          initial: _filter,
          identifier: FILTER,
          bucket: PageStorage.of(context),
          onRead: (value) => _onRead(value),
          onWrite: (value) => enumName(value),
          onBuild: () => PersonnelStatus.values.map(
            (status) => FilterData(
              key: status,
              title: translatePersonnelStatus(status),
            ),
          ),
          onChanged: (Set<PersonnelStatus> selected) => setState(() => _filter = selected),
        ),
      );

  PersonnelStatus _onRead(value) => PersonnelStatus.values.firstWhere((e) => value == enumName(e));
}

class PersonnelAvatar extends StatelessWidget {
  final Personnel personnel;
  final Tracking tracking;
  const PersonnelAvatar({
    Key key,
    this.personnel,
    this.tracking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: toPersonnelStatusColor(personnel.status),
      child: Stack(
        children: <Widget>[
          Center(child: Icon(toPersonnelIconData(personnel))),
          if (tracking != null)
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

class PersonnelSearch extends SearchDelegate<Personnel> {
  static final _storage = new FlutterSecureStorage();
  static const RECENT_KEY = "search/personnel/recent";

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  PersonnelSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final List recent = stored != null
        ? json.decode(stored)
        : [
            translatePersonnelStatus(PersonnelStatus.Mobilized),
            translatePersonnelStatus(PersonnelStatus.OnScene),
            translatePersonnelStatus(PersonnelStatus.Retired)
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
    return UserHistoryPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}

Future<Personnel> selectPersonnel(
  BuildContext context, {
  bool where(Personnel personnel),
  String query,
}) async {
  return await showDialog<Personnel>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("Velg mannskap", textAlign: TextAlign.start),
        ),
        body: UserHistoryPage(
          where: where,
          query: query,
          withActions: false,
          onSelection: (personnel) => Navigator.pop(context, personnel),
        ),
      );
    },
  );
}
