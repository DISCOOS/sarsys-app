import 'dart:async';
import 'dart:convert';

import 'package:SarSys/features/affiliation/domain/entities/Affiliation.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/affiliation/presentation/widgets/affiliation.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class AffiliationsPage extends StatefulWidget {
  final String query;
  final bool withStatus;
  final bool withActions;
  final bool withMultiSelect;
  final bool Function(Affiliation affiliation) where;
  final void Function(Affiliation affiliation) onSelection;

  const AffiliationsPage({
    Key key,
    this.query,
    this.where,
    this.onSelection,
    this.withStatus = true,
    this.withActions = true,
    this.withMultiSelect = false,
  }) : super(key: key);

  @override
  AffiliationsPageState createState() => AffiliationsPageState();
}

class AffiliationsPageState extends State<AffiliationsPage> {
  static const FILTER = "affiliation_filter";
  StreamGroup<dynamic> _group;

  Set<AffiliationStandbyStatus> _filter;

  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(
      context,
      FILTER,
      onRead: _onRead,
      defaultValue: AffiliationStandbyStatus.values.toSet(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<AffiliationBloc>())
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
            context.bloc<AffiliationBloc>().load();
          },
          child: Container(
            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var affiliations = _filteredAffiliation(context.bloc<AffiliationBloc>());
                return affiliations.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        viewportConstraints,
//                        child: ListTile(
//                          title: Text("Søk opp"),
//                        ),
                        message: snapshot.hasError
                            ? snapshot.error
                            : widget.query == null ? "Søk eller legg til mannskap" : "Ingen mannskap funnet",
                      )
                    : _buildList(context.bloc<AffiliationBloc>(), affiliations);
              },
            ),
          ),
        );
      },
    );
  }

  List<Affiliation> _filteredAffiliation(AffiliationBloc bloc) {
    return context
        .bloc<AffiliationBloc>()
        .repo
        .values
        .where((affiliation) => _filter.contains(affiliation.status))
        .where((affiliation) => widget.where == null || widget.where(affiliation))
        .where((affiliation) => _matches(bloc, affiliation))
        .toList()
          ..sort(
            (p1, p2) => _prepare(bloc, p1).compareTo(_prepare(bloc, p2)),
          );
  }

  bool _matches(AffiliationBloc bloc, Affiliation affiliation) =>
      widget.query == null || _prepare(bloc, affiliation).contains(widget.query.toLowerCase());

  String _prepare(AffiliationBloc bloc, Affiliation affiliation) =>
      "${bloc.toSearchable(affiliation.uuid)}".toLowerCase();

  ListView _buildList(AffiliationBloc bloc, List affiliations) {
    return ListView.builder(
      itemCount: affiliations.length + 1,
      itemExtent: 72.0,
      itemBuilder: (context, index) {
        return _buildAffiliation(bloc, affiliations, index);
      },
    );
  }

  Widget _buildAffiliation(AffiliationBloc bloc, List<Affiliation> items, int index) {
    if (index == items.length) {
      return Center(
        child: Text("Antall personer: $index"),
      );
    }
    final affiliation = items[index];
    final person = bloc.persons[affiliation.person?.uuid];
    return widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildAffiliationTile(person, affiliation),
            secondaryActions: <Widget>[
              _buildTransitionAction(context, affiliation),
            ],
          )
        : _buildAffiliationTile(person, affiliation);
  }

  Widget _buildAffiliationTile(Person person, Affiliation affiliation) {
    return Container(
      key: ObjectKey(affiliation.uuid),
      color: Colors.white,
      constraints: BoxConstraints.expand(),
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: GestureDetector(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Chip(
              label: Text("${person.name}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: new AffiliationAvatar(
                size: 6.0,
                maxRadius: 10.0,
                affiliation: affiliation,
              ),
            ),
            Spacer(),
            if (widget.withStatus)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text(
                    translateAffiliationStandbyStatus(affiliation.status),
                    textAlign: TextAlign.end,
                  ),
                  backgroundColor: Colors.grey[100],
                ),
              ),
            if (widget.withMultiSelect)
              Padding(
                padding: EdgeInsets.only(left: 16.0, right: (widget.withActions ? 0.0 : 16.0)),
                child: Icon(_selected.contains(affiliation.uuid) ? Icons.check_box : Icons.check_box_outline_blank),
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
        onTap: () => _onTap(affiliation),
      ),
    );
  }

  _onTap(Affiliation affiliation) {
    if (widget.withMultiSelect) {
    } else if (widget.onSelection == null) {
      Navigator.pop(context, affiliation);
    } else {
      widget.onSelection(affiliation);
    }
  }

  IconSlideAction _buildTransitionAction(BuildContext context, Affiliation affiliation) {
    switch (affiliation.status) {
      case AffiliationStandbyStatus.unavailable:
        return IconSlideAction(
          caption: translateAffiliationStandbyStatus(AffiliationStandbyStatus.unavailable),
          color: toAffiliationStandbyStatusColor(AffiliationStandbyStatus.available),
          icon: Icons.check_circle,
          onTap: () async => await context.bloc<AffiliationBloc>().update(affiliation.copyWith(
                status: AffiliationStandbyStatus.available,
              )),
        );
      case AffiliationStandbyStatus.available:
        return IconSlideAction(
          caption: translateAffiliationStandbyStatus(AffiliationStandbyStatus.available),
          color: toAffiliationStandbyStatusColor(AffiliationStandbyStatus.short_notice),
          icon: Icons.check_circle,
          onTap: () async => await context.bloc<AffiliationBloc>().update(affiliation.copyWith(
                status: AffiliationStandbyStatus.short_notice,
              )),
        );
      case AffiliationStandbyStatus.short_notice:
      default:
        return IconSlideAction(
          caption: translateAffiliationStandbyStatus(AffiliationStandbyStatus.short_notice),
          color: toAffiliationStandbyStatusColor(AffiliationStandbyStatus.unavailable),
          icon: Icons.archive,
          onTap: () async => await context.bloc<AffiliationBloc>().update(affiliation.copyWith(
                status: AffiliationStandbyStatus.unavailable,
              )),
        );
    }
  }

  void showFilterSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext bc) => FilterSheet<AffiliationStandbyStatus>(
          initial: _filter,
          identifier: FILTER,
          bucket: PageStorage.of(context),
          onRead: (value) => _onRead(value),
          onWrite: (value) => enumName(value),
          onBuild: () => AffiliationStandbyStatus.values.map(
            (status) => FilterData(
              key: status,
              title: translateAffiliationStandbyStatus(status),
            ),
          ),
          onChanged: (Set<AffiliationStandbyStatus> selected) => setState(() => _filter = selected),
        ),
      );

  AffiliationStandbyStatus _onRead(value) => AffiliationStandbyStatus.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => AffiliationStandbyStatus.unavailable,
      );
}

class AffiliationSearch extends SearchDelegate<Affiliation> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/affiliation/recent";

  final bool Function(Affiliation affiliation) where;
  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  AffiliationSearch({this.where}) {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final always = [
      translateAffiliationStandbyStatus(AffiliationStandbyStatus.available),
      translateAffiliationStandbyStatus(AffiliationStandbyStatus.unavailable),
      translateAffiliationStandbyStatus(AffiliationStandbyStatus.short_notice),
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

  AffiliationsPage _buildResults(BuildContext context, {bool store = false}) {
    if (store) {
      final recent = _recent.value.toSet()..add(query);
      _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
      _recent.value = recent.toSet() ?? [];
    }
    return AffiliationsPage(
      query: query,
      where: where,
      withStatus: false,
      withActions: false,
    );
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}

Future<Affiliation> selectOrCreateAffiliation(
  BuildContext context, {
  String query,
  bool where(Affiliation affiliation),
}) async {
  return await showDialog<Affiliation>(
    context: context,
    builder: (BuildContext context) {
      // return object of type Dialog
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () async {
                showSearch<Affiliation>(
                    context: context,
                    delegate: AffiliationSearch(
                      where: where,
                    ));
              },
            ),
          ],
          title: Text("Mobiliser mannskap", textAlign: TextAlign.start),
        ),
        body: AffiliationsPage(
          where: where,
          query: query,
          withActions: false,
          withMultiSelect: false,
          onSelection: (affiliation) => Navigator.pop(context, affiliation),
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () async {
            final result = await createPersonnel();
            Navigator.pop(
              context,
              result.isRight()
                  ? context.bloc<AffiliationBloc>().repo[result.toIterable().first.affiliation.uuid]
                  : null,
            );
          },
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      );
    },
  );
}
