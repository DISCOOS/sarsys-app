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
import 'package:SarSys/icons.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:debounce_throttle/debounce_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:grouped_list/grouped_list.dart';

class AffiliationsPage extends StatefulWidget {
  final String query;
  final bool withStatus;
  final bool withActions;
  final bool withGrouped;
  final bool withMultiSelect;
  final Completer<List<Affiliation>> request;
  final bool Function(Affiliation affiliation) where;
  final void Function(Affiliation affiliation) onSelection;

  const AffiliationsPage({
    Key key,
    this.query,
    this.where,
    this.request,
    this.onSelection,
    this.withStatus = true,
    this.withActions = true,
    this.withGrouped = true,
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
      builder: (BuildContext context, BoxConstraints constraints) {
        return RefreshIndicator(
          onRefresh: () async {
            context.bloc<AffiliationBloc>().load();
          },
          child: Container(
//            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var affiliations = _filteredAffiliation(context.bloc<AffiliationBloc>());
                return affiliations.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        constraints,
                        message: _toEmptyListMessage(snapshot),
                      )
                    : _buildList(context.bloc<AffiliationBloc>(), affiliations);
              },
            ),
          ),
        );
      },
    );
  }

  Object _toEmptyListMessage(AsyncSnapshot snapshot) => snapshot.hasError
      ? snapshot.error
      : widget.query == null
          ? "Last ned eller opprett mannskap"
          : widget.request?.isCompleted == false ? "Søker..." : "Ingen nye mannskap lastet ned";

  List<Affiliation> _filteredAffiliation(AffiliationBloc bloc) {
    final affiliations = context
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

    if (!widget.withGrouped) {
      affiliations.sort(
        (p1, p2) => _prepare(bloc, p1).compareTo(_prepare(bloc, p2)),
      );
    }
    return affiliations;
  }

  bool _matches(AffiliationBloc bloc, Affiliation affiliation) =>
      widget.query == null || _prepare(bloc, affiliation).contains(widget.query.toLowerCase());

  String _prepare(AffiliationBloc bloc, Affiliation affiliation) =>
      "${bloc.toSearchable(affiliation.uuid)}".toLowerCase();

  AffiliationBloc get affiliationBloc => context.bloc<AffiliationBloc>();

  Widget _buildList(AffiliationBloc bloc, List affiliations) {
    return widget.withGrouped
        ? GroupedListView<Affiliation, AffiliationGroupEntry>(
            sort: true,
            floatingHeader: true,
            elements: affiliations,
            useStickyGroupSeparators: true,
            physics: AlwaysScrollableScrollPhysics(),
            order: GroupedListOrder.DESC,
            itemBuilder: (context, affiliation) {
              return _buildAffiliation(bloc, affiliation);
            },
            groupBy: (affiliation) {
              final org = affiliationBloc.orgs[affiliation.org?.uuid];
              return AffiliationGroupEntry(
                prefix: org.prefix ?? '0',
                name: affiliationBloc.toName(
                  affiliation,
                  empty: 'Uorganisert',
                  short: true,
                ),
              );
            },
            groupSeparatorBuilder: (affiliation) => AffiliationGroupDelimiter(
              affiliation,
            ),
          )
        : ListView.builder(
            itemCount: affiliations.length + 1,
            itemExtent: 72.0,
            physics: AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return _buildAffiliation(bloc, affiliations[index]);
            },
          );
  }

  Widget _buildAffiliation(AffiliationBloc bloc, Affiliation affiliation) {
    final person = bloc.persons[affiliation.person?.uuid];
    return GestureDetector(
      child: widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true
          ? Slidable(
              actionPane: SlidableScrollActionPane(),
              actionExtentRatio: 0.2,
              child: _buildAffiliationTile(person, affiliation),
              secondaryActions: <Widget>[
                _buildTransitionAction(context, affiliation),
              ],
            )
          : _buildAffiliationTile(person, affiliation),
      onTap: () => _onTap(affiliation),
    );
  }

  Widget _buildAffiliationTile(Person person, Affiliation affiliation) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightForFinite(height: 72.0),
      child: Container(
        key: ObjectKey(affiliation.uuid),
        color: Colors.white,
        constraints: BoxConstraints.expand(),
        padding: const EdgeInsets.only(left: 16.0, right: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Chip(
              label: Text("${person?.name ?? 'Mannskap'}"),
              backgroundColor: Colors.grey[100],
            ),
            SizedBox(width: 8.0),
            Chip(
              label: Text("${person?.phone ?? 'Ingen telefon'}"),
              backgroundColor: Colors.grey[100],
              labelPadding: EdgeInsets.only(right: 4.0),
              avatar: Icon(
                Icons.phone,
                size: 16.0,
                color: Colors.black38,
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

class AffiliationGroupEntry implements Comparable {
  AffiliationGroupEntry({this.name, this.prefix});
  final String name;
  final String prefix;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AffiliationGroupEntry &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          prefix == other.prefix;

  @override
  int get hashCode => name.hashCode ^ prefix.hashCode;

  @override
  int compareTo(other) {
    if (other is AffiliationGroupEntry) {
      return other.name.compareTo(name);
    }
    return double.maxFinite.toInt();
  }
}

class AffiliationGroupDelimiter extends StatelessWidget {
  const AffiliationGroupDelimiter(
    this.affiliation, {
    Key key,
  }) : super(key: key);
  final AffiliationGroupEntry affiliation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              child: SarSysIcons.of(
                affiliation.prefix,
                size: 8,
              ),
              maxRadius: 10,
              backgroundColor: Colors.white,
            ),
            SizedBox(width: 8.0),
            Text(
              affiliation.name,
              style: Theme.of(context).textTheme.subtitle2,
            ),
          ],
        ),
      ),
    );
  }
}

class AffiliationSearch extends SearchDelegate<Affiliation> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/affiliation/recent";

  final bool Function(Affiliation affiliation) where;
  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  AffiliationBloc _bloc;
  Debouncer<String> _debouncer;
  Completer<List<Affiliation>> _request;

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

    // Limit the amount of searches made against the backend
    _debouncer = Debouncer<String>(
      const Duration(milliseconds: 250),
      onChanged: (query) {
        if (_bloc != null) {
          if (_request?.isCompleted != false) {
            _request = Completer();
          }
          _request.complete(_bloc?.search(query));
        }
      },
    );
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
    _bloc ??= context.bloc<AffiliationBloc>();
    if (translateAffiliationStandbyStatus(AffiliationStandbyStatus.available) == query) {
      _debouncer.value = enumName(AffiliationStandbyStatus.available);
    } else if (translateAffiliationStandbyStatus(AffiliationStandbyStatus.unavailable) == query) {
      _debouncer.value = enumName(AffiliationStandbyStatus.unavailable);
    } else if (translateAffiliationStandbyStatus(AffiliationStandbyStatus.short_notice) == query) {
      _debouncer.value = enumName(AffiliationStandbyStatus.short_notice);
    } else {
      _debouncer.value = query;
    }
    // This will invoke a search which
    // AffiliationsPage will pick up when
    // the result is stored to repository

    return AffiliationsPage(
      query: query,
      where: where,
      request: _request,
      withStatus: true,
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
              tooltip: "Søk etter mannskap og last dem ned lokalt",
              icon: Icon(Icons.file_download),
              onPressed: () async {
                final affiliation = await showSearch<Affiliation>(
                    context: context,
                    delegate: AffiliationSearch(
                      where: where,
                    ));
                Navigator.pop(context, affiliation);
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
        floatingActionButton: FloatingActionButton.extended(
          icon: Icon(Icons.add),
          label: Text("Manuell"),
          isExtended: true,
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
