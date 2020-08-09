import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:grouped_list/grouped_list.dart';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/presentation/pages/affiliations_page.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/personnel/presentation/screens/personnel_screen.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/descriptions.dart';
import 'package:SarSys/core/presentation/widgets/filter_sheet.dart';

class PersonnelsPage extends StatefulWidget {
  final String query;
  final bool withAvatar;
  final bool withStatus;
  final bool withActions;
  final bool withGrouped;
  final bool withMultiSelect;
  final bool Function(Personnel personnel) where;
  final void Function(Personnel personnel) onSelection;

  const PersonnelsPage({
    Key key,
    this.query,
    this.where,
    this.onSelection,
    this.withStatus = true,
    this.withAvatar = true,
    this.withActions = true,
    this.withGrouped = true,
    this.withMultiSelect = false,
  }) : super(key: key);

  @override
  PersonnelsPageState createState() => PersonnelsPageState();
}

class PersonnelsPageState extends State<PersonnelsPage> {
  static const FILTER = "personnel_filter";
  StreamGroup<dynamic> _group;

  Set<PersonnelStatus> _filter;

  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(
      context,
      FILTER,
      defaultValue: PersonnelStatus.values.toSet()..remove(PersonnelStatus.retired),
      onRead: _onRead,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<PersonnelBloc>())
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
            context.bloc<PersonnelBloc>().load();
          },
          child: StreamBuilder(
            stream: _group.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData == false) return Container();
              var personnels = _filteredPersonnel();
              return personnels.isEmpty || snapshot.hasError
                  ? toRefreshable(
                      viewportConstraints,
                      message: snapshot.hasError
                          ? snapshot.error
                          : widget.query == null ? "Legg til mannskap" : "Ingen mannskap funnet",
                    )
                  : _buildList(personnels);
            },
          ),
        );
      },
    );
  }

  List<Personnel> _filteredPersonnel() {
    final personnels = context
        .bloc<PersonnelBloc>()
        .repo
        .values
        .where((personnel) => _filter.contains(personnel.status))
        .where((personnel) => widget.where == null || widget.where(personnel))
        .where((personnel) => widget.query == null || _prepare(personnel).contains(widget.query.toLowerCase()))
        .toList();
    if (!widget.withGrouped) {
      personnels.sort((p1, p2) => p1.name.toLowerCase().compareTo(p2.name.toLowerCase()));
    }
    return personnels;
  }

  String _prepare(Personnel personnel) => "${personnel.searchable}".toLowerCase();

  Widget _buildList(List personnels) {
    return widget.withGrouped
        ? GroupedListView<Personnel, AffiliationGroupEntry>(
            physics: AlwaysScrollableScrollPhysics(),
            sort: true,
            elements: personnels,
            order: GroupedListOrder.ASC,
            useStickyGroupSeparators: false,
            itemBuilder: (context, personnel) {
              return _buildPersonnel(personnel);
            },
            groupBy: (personnel) {
              final affiliation = _toAffiliation(personnel);
              final org = affiliationBloc.orgs[affiliation.org?.uuid];
              return AffiliationGroupEntry(
                prefix: org?.prefix ?? '0',
                name: affiliationBloc
                    .toName(
                      affiliation,
                      empty: 'Uorganisert',
                      short: true,
                    )
                    .trim(),
              );
            },
            groupSeparatorBuilder: (group) => AffiliationGroupDelimiter(group),
          )
        : ListView.builder(
            itemCount: personnels.length,
            itemExtent: 72.0,
            itemBuilder: (context, index) {
              return _buildPersonnel(personnels[index]);
            },
          );
  }

  Widget _buildPersonnel(Personnel personnel) {
    final unit = _toUnit(personnel);
    final tracking = context.bloc<TrackingBloc>().trackings[personnel.tracking.uuid];
    var status = tracking?.status ?? TrackingStatus.none;
    return GestureDetector(
      child: widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true
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
          : _buildPersonnelTile(unit, personnel, status, tracking),
      onTap: () => _onTap(personnel),
    );
  }

  Widget _buildPersonnelTile(Unit unit, Personnel personnel, TrackingStatus status, Tracking tracking) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightForFinite(height: 72.0),
      child: Container(
        key: ObjectKey(personnel.uuid),
        color: Colors.white,
        constraints: BoxConstraints.expand(),
        padding: const EdgeInsets.only(left: 16.0, right: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (widget.withAvatar)
              PersonnelAvatar(
                personnel: personnel,
                tracking: tracking,
              ),
            SizedBox(width: widget.withAvatar ? 16.0 : 8.0),
            Chip(
              label: Text("${personnel.name}"),
              backgroundColor: Colors.grey[100],
//              avatar: AffiliationAvatar(
//                size: 6.0,
//                maxRadius: 10.0,
//                affiliation: _toAffiliation(personnel),
//              ),
            ),
            if (isTemporary(personnel))
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: GestureDetector(
                    child: Chip(
                      label: Text(
                        'M',
                        textAlign: TextAlign.end,
                      ),
                      labelPadding: EdgeInsets.only(right: 4.0),
                      backgroundColor: Colors.grey[100],
                      avatar: Icon(
                        Icons.warning,
                        size: 16.0,
                        color: Colors.orange,
                      ),
                    ),
                    onTap: () => alert(
                          context,
                          title: "Mannskap opprettet manuelt",
                          content: TemporaryPersonnelDescription(),
                        )),
              ),
            Spacer(),
            if (widget.withStatus)
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
                  color: toPositionStatusColor(tracking?.position),
                ),
              ),
            if (widget.withMultiSelect)
              Padding(
                padding: EdgeInsets.only(left: 16.0, right: (widget.withActions ? 0.0 : 16.0)),
                child: Icon(_selected.contains(personnel.uuid) ? Icons.check_box : Icons.check_box_outline_blank),
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
      ),
    );
  }

  Affiliation _toAffiliation(Personnel personnel) => affiliationBloc.repo[personnel?.affiliation?.uuid];

  AffiliationBloc get affiliationBloc => context.bloc<AffiliationBloc>();

  bool isTemporary(Personnel personnel) => affiliationBloc.isTemporary(
        personnel.affiliation.uuid,
      );

  String _toUsage(
    Unit unit,
    Personnel personnel,
    Tracking tracking,
  ) =>
      [
        unit?.name ?? '',
        formatSince(tracking?.position?.timestamp, defaultValue: "Ingen"),
      ].where((value) => emptyAsNull(value) != null).join(' ');

  void _onTap(Personnel personnel) {
    if (widget.withMultiSelect) {
    } else if (widget.onSelection == null) {
      Navigator.pushNamed(context, PersonnelScreen.ROUTE, arguments: personnel);
    } else {
      widget.onSelection(personnel);
    }
  }

  IconSlideAction _buildEditAction(BuildContext context, Personnel personnel) => IconSlideAction(
        caption: 'ENDRE',
        color: Theme.of(context).buttonColor,
        icon: Icons.more_horiz,
        onTap: () async {
          await editPersonnel(personnel);
        },
      );

  Widget _buildAddToUnitAction(Personnel personnel) => Tooltip(
        message: "Knytt til enhet",
        child: IconSlideAction(
          caption: 'KNYTT',
          color: Theme.of(context).buttonColor,
          icon: Icons.people,
          onTap: () async => await addToUnit(personnels: [personnel.uuid]),
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
              await removeFromUnit(unit, personnels: [personnel.uuid]);
            }
          },
        ),
      );

  Unit _toUnit(Personnel personnel) => context.bloc<TrackingBloc>().unitBloc.units.values.firstWhere(
        (unit) => unit.personnels?.contains(personnel) == true,
        orElse: () => null,
      );

  Widget _buildCreateUnitAction(Personnel personnel) => Tooltip(
        message: "Opprett enhet med mannskap",
        child: IconSlideAction(
          caption: 'OPPRETT',
          color: Theme.of(context).buttonColor,
          icon: Icons.group_add,
          onTap: () async => await createUnit(personnels: [personnel.uuid]),
        ),
      );

  IconSlideAction _buildTransitionAction(BuildContext context, Personnel personnel) {
    switch (personnel.status) {
      case PersonnelStatus.retired:
        return IconSlideAction(
          caption: 'MOBILISERT',
          color: toPersonnelStatusColor(PersonnelStatus.alerted),
          icon: Icons.check_circle,
          onTap: () async => await checkInPersonnel(personnel),
        );
      case PersonnelStatus.alerted:
        return IconSlideAction(
          caption: 'ANKOMMET',
          color: toPersonnelStatusColor(PersonnelStatus.onscene),
          icon: Icons.check_circle,
          onTap: () async => await checkInPersonnel(personnel),
        );
      case PersonnelStatus.onscene:
      default:
        return IconSlideAction(
          caption: 'DIMMITERT',
          color: toPersonnelStatusColor(PersonnelStatus.retired),
          icon: Icons.archive,
          onTap: () async => await retirePersonnel(personnel),
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

  PersonnelStatus _onRead(value) => PersonnelStatus.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => PersonnelStatus.alerted,
      );
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
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/personnel/recent";

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  PersonnelSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final always = [
      translatePersonnelStatus(PersonnelStatus.alerted),
      translatePersonnelStatus(PersonnelStatus.onscene),
      translatePersonnelStatus(PersonnelStatus.leaving),
      translatePersonnelStatus(PersonnelStatus.retired)
    ];
    final recent = stored != null ? (Set.from(always)..addAll(json.decode(stored))) : always.toSet();
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
    return query.isEmpty
        ? ValueListenableBuilder<Set<String>>(
            valueListenable: _recent,
            builder: (BuildContext context, Set<String> suggestions, Widget child) {
              return _buildSuggestionList(
                context,
                suggestions?.where(_matches)?.toList() ?? [],
              );
            },
          )
        : _buildResults(context, store: false);
  }

  bool _matches(String suggestion) => suggestion.toLowerCase().startsWith(query.toLowerCase());

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
        trailing: index > 3
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
    return _buildResults(context, store: true);
  }

  PersonnelsPage _buildResults(BuildContext context, {bool store = false}) {
    if (store) {
      final recent = _recent.value.toSet()..add(query);
      _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
      _recent.value = recent.toSet() ?? [];
    }
    return PersonnelsPage(
      query: query,
      withActions: false,
      withAvatar: false,
      withStatus: false,
    );
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
        body: PersonnelsPage(
          where: where,
          query: query,
          withActions: false,
          onSelection: (personnel) => Navigator.pop(context, personnel),
        ),
      );
    },
  );
}
