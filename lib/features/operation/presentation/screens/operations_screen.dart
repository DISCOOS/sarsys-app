

import 'dart:convert';

import 'package:SarSys/core/presentation/blocs/core.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:async/async.dart';

import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/filter_sheet.dart';

class OperationsScreen extends Screen<OperationsScreenState> {
  static const ROUTE = 'operation/list';
  @override
  OperationsScreenState createState() => OperationsScreenState();
}

class OperationsScreenState extends ScreenState<OperationsScreen, void> {
  static const FILTER = "operations_filter";

  Set<OperationStatus>? _filter;

  OperationsScreenState()
      : super(
          title: "Aksjoner",
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(context, FILTER, defaultValue: OperationsPage.DEFAULT_FILTER, onRead: _onRead);
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
      child: OperationsPage(filter: _filter),
    );
  }

  @override
  FloatingActionButton? buildFAB(BuildContext context) {
    return context.read<OperationBloc>().isAuthorizedAs(UserRole.commander)
        ? FloatingActionButton(
            onPressed: () => _create(context),
            tooltip: 'Ny aksjon',
            child: Icon(Icons.add),
            elevation: 2.0,
          )
        : null;
  }

  Future _create(BuildContext context) async {
    var result = await createOperation()!;
    result.fold((_) => null, (operation) => jumpToOperation(context, operation));
  }

  @override
  List<Widget> buildAppBarActions() => <Widget>[
        IconButton(
          icon: Icon(Icons.search),
          color: Colors.white,
          onPressed: () => showSearch(context: context, delegate: OperationSearch(_filter)),
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
      builder: (BuildContext bc) => FilterSheet<OperationStatus>(
        initial: _filter,
        identifier: FILTER,
        bucket: PageStorage.of(context),
        onRead: (value) => _onRead(value),
        onWrite: (value) => enumName(value),
        onBuild: () => OperationStatus.values.map((status) => FilterData(
              key: status,
              title: translateOperationStatus(status),
            )),
        onChanged: (Set<OperationStatus> selected) => setState(() => _filter = selected),
      ),
    );
  }

  OperationStatus _onRead(value) => OperationStatus.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => OperationStatus.planned,
      );
}

class OperationsPage extends StatefulWidget {
  static const DEFAULT_FILTER = const {
    OperationStatus.planned,
    OperationStatus.enroute,
    OperationStatus.onscene,
  };

  final String? query;
  final Set<OperationStatus>? filter;

  const OperationsPage({
    Key? key,
    required this.filter,
    this.query,
  }) : super(key: key);

  @override
  _OperationsPageState createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  StreamGroup<dynamic>? _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group?.close();
    _group = StreamGroup<BlocState?>.broadcast()
      ..add(context.read<UserBloc>().stream)
      ..add(context.read<UnitBloc>().stream)
      ..add(context.read<OperationBloc>().stream)
      ..add(context.read<PersonnelBloc>().stream);
  }

  @override
  void dispose() {
    _group?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await context.read<OperationBloc>().load();
          setState(() {});
        },
        child: StreamBuilder(
          stream: _group!.stream,
          initialData: context.read<OperationBloc>().state,
          builder: (context, snapshot) {
            if (snapshot.hasData == false) return Container();
            var cards = _toCards(snapshot);
            return cards.isEmpty
                ? toRefreshable(
                    viewportConstraints,
                    message: "0 av ${context.read<OperationBloc>().operations.length} hendelser vises",
                  )
                : toRefreshable(
                    viewportConstraints,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 96.0),
                      child: Column(
                        children: cards as List<Widget>,
                      ),
                    ),
                  );
          },
        ),
      );
    });
  }

  List _toCards(AsyncSnapshot snapshot) {
    return snapshot.hasData ? _filteredOperations().map((operation) => _buildCard(operation)).toList() : [];
  }

  List<Operation?> _filteredOperations() {
    final incidents = context.read<OperationBloc>().incidents;
    final operations = context.read<OperationBloc>().operations;
    final found = operations
        .where((operation) => widget.filter!.contains(operation?.status))
        .where((operation) => widget.query == null || _prepare(operation!).contains(widget.query!.toLowerCase()))
        .toList();
    return found
      ..sort(
        (Operation? o1, Operation? o2) =>
            incidents[o2!.incident!.uuid!]?.occurred?.compareTo(incidents[o1!.incident!.uuid!]!.occurred!) ?? 0,
      );
  }

  String _prepare(Operation operation) => "${operation.searchable}".toLowerCase();

  Widget _buildCard(Operation? operation) {
    final title = Theme.of(context).textTheme.headline6;
    final caption = Theme.of(context).textTheme.caption;

    return StreamBuilder(
        stream: context.read<UserBloc>().stream,
        initialData: context.read<UserBloc>().state,
        builder: (context, snapshot) {
          if (snapshot.hasData == false) return Container();
          final isCurrent = context.read<OperationBloc>().selected == operation;
          final incident = context.read<OperationBloc>().incidents[operation!.incident!.uuid!];
          final isUserMobilized = context.read<PersonnelBloc>().isUserMobilized;
          final isMobilized = isCurrent && isUserMobilized;
          final isAuthorized = isMobilized || context.read<UserBloc>().isAuthorized(operation);
          return Card(
            elevation: 4.0,
            child: Column(
              key: ObjectKey(operation.uuid),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                incident?.exercise == true
                    ? Banner(
                        message: "Øvelse",
                        location: BannerLocation.topEnd,
                        child: _buildCardHeader(context, operation, title, caption),
                      )
                    : _buildCardHeader(context, operation, title, caption),
                if (isAuthorized) _buildMapTile(operation),
                if (isAuthorized)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: Text(
                      _toDescription(operation),
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
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.only(left: isAuthorized ? 16.0 : 16.0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(isAuthorized
                                  ? isMobilized
                                      ? toPersonnelStatusIcon(PersonnelStatus.leaving)
                                      : isAuthorized
                                          ? toPersonnelStatusIcon(PersonnelStatus.enroute)
                                          : Icons.lock_open
                                  : Icons.lock_open),
                              label: Text(
                                isAuthorized
                                    ? (isMobilized ? 'SJEKK UT' : 'DELTA')
                                    : hasRoles
                                        ? isMobilized
                                            ? 'LÅS OPP'
                                            : 'LÅS OPP'
                                        : 'INGEN TILGANG',
                                style: TextStyle(fontSize: 14.0),
                              ),
                              onPressed: isAuthorized || hasRoles
                                  ? () async {
                                      if (isMobilized) {
                                        await leaveOperation();
                                      } else {
                                        await joinOperation(operation);
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
                          if (context.read<UserBloc>().isAuthor(operation) || !context.read<UserBloc>().hasRoles)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                context.read<UserBloc>().isAuthor(operation) || context.read<UserBloc>().hasRoles
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

  ListTile _buildCardHeader(BuildContext context, Operation operation, TextStyle? title, TextStyle? caption) {
    return ListTile(
      selected: context.read<OperationBloc>().selected == operation,
      title: Text(
        operation.name!,
        style: title,
      ),
      subtitle: Text(
        operation.reference ?? 'Ingen referanse',
        style: TextStyle(
          fontSize: 14.0,
          color: Colors.black.withOpacity(0.5),
        ),
      ),
      trailing: _buildCardStatus(operation, caption),
    );
  }

  Padding _buildCardStatus(Operation operation, TextStyle? caption) {
    final incident = context.read<OperationBloc>().incidents[operation.incident!.uuid!];
    return Padding(
      padding: EdgeInsets.only(top: 8.0, right: (incident?.exercise == true ? 24.0 : 0.0)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            translateOperationStatus(operation.status),
            style: caption,
          ),
          Text(
            "${formatSince(incident?.occurred)}",
            style: caption,
          ),
        ],
      ),
    );
  }

  bool get hasRoles => context.read<UserBloc>()?.hasRoles == true;

  String _toDescription(Operation operation) {
    String? meetup = operation.meetup!.description;
    return "${_replaceLast(operation.justification!)}.\n"
        "Oppmøte ${toUTM(operation.meetup!.point)}"
        "${meetup == null ? "." : ", $meetup."}";
  }

  String _replaceLast(String text) => text.replaceFirst(r'.', "", text.length - 1);

  Widget _buildMapTile(Operation operation) {
    final ipp = operation.ipp != null ? toLatLng(operation.ipp!.point) : null;
    final meetup = operation.meetup != null ? toLatLng(operation.meetup!.point) : null;
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
            operation: operation,
            interactive: false,
            withRead: true,
          ),
        ),
        onTap: () => joinOperation(operation),
      ),
    );
  }
}

class OperationSearch extends SearchDelegate<Operation?> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/operation/recent";

  final Set<OperationStatus>? filter;

  ValueNotifier<Set<String>?> _recent = ValueNotifier(null);

  OperationSearch(this.filter) {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final always = [
      translateOperationType(OperationType.search),
      translateOperationType(OperationType.rescue),
      translateOperationStatus(OperationStatus.planned),
      translateOperationStatus(OperationStatus.onscene),
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
        ? ValueListenableBuilder<Set<String>?>(
            valueListenable: _recent,
            builder: (BuildContext context, Set<String>? suggestions, Widget? child) {
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
            style: theme.textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold),
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
    return _buildResults(context, store: true);
  }

  OperationsPage _buildResults(BuildContext context, {bool store = false}) {
    if (store) {
      final recent = _recent.value!.toSet()..add(query);
      _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
      _recent.value = (recent.toSet() ?? []) as Set<String>?;
    }
    return OperationsPage(
      query: query,
      filter: filter,
    );
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = (recent.toSet() ?? []) as Set<String>?;
    buildSuggestions(context);
  }
}
