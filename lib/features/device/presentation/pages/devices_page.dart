

import 'dart:convert';

import 'package:async/async.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:SarSys/features/device/presentation/widgets/device_widgets.dart';
import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:SarSys/features/affiliation/presentation/blocs/affiliation_bloc.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:SarSys/features/personnel/presentation/blocs/personnel_bloc.dart';
import 'package:SarSys/features/tracking/presentation/blocs/tracking_bloc.dart';
import 'package:SarSys/features/unit/presentation/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/features/device/domain/entities/Device.dart';
import 'package:SarSys/features/personnel/domain/entities/Personnel.dart';
import 'package:SarSys/features/tracking/domain/entities/Tracking.dart';
import 'package:SarSys/features/unit/domain/entities/Unit.dart';
import 'package:SarSys/features/device/presentation/screens/device_screen.dart';
import 'package:SarSys/features/device/domain/usecases/device_use_cases.dart';
import 'package:SarSys/features/personnel/domain/usecases/personnel_use_cases.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/widgets/filter_sheet.dart';

class DevicesPage extends StatefulWidget {
  final String? query;
  final bool withActions;

  DevicesPage({Key? key, this.query, this.withActions = true}) : super(key: key);

  @override
  DevicesPageState createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  static const STATE = "devices_filter";
  Set<DeviceType?>? _filter;

  StreamGroup<dynamic>? _group;

//  Map<String, String> _functions;
//  Map<String, Division> _divisions;

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(context, STATE, defaultValue: DeviceType.values.toSet(), onRead: _onRead);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group!.close();
    _group = StreamGroup.broadcast()
      ..add(context.read<UserBloc>().stream)
      ..add(context.read<UnitBloc>().stream)
      ..add(context.read<PersonnelBloc>().stream)
      ..add(context.read<DeviceBloc>().stream)
      ..add(context.read<TrackingBloc>().stream);
//    _divisions = context.read<AffiliationBloc>().repo[Defaults.orgId];
//    _functions = await FleetMapService().fetchFunctions(Defaults.orgId);
  }

  @override
  void dispose() {
    _group!.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<DeviceBloc>().load();
        },
        child: Container(
          child: StreamBuilder(
              stream: _group!.stream,
              initialData: context.read<DeviceBloc>().state,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var units = context.read<TrackingBloc>().units.devices();
                var personnel = context.read<TrackingBloc>().personnels.devices();
                var tracked = context.read<TrackingBloc>().asDeviceIds();
                var devices = _filteredDevices();
                return devices.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        viewportConstraints,
                        message: snapshot.hasError ? snapshot.error as String? : "Ingen apparater innen rekkevidde",
                      )
                    : ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          return Container(
                            height: 56.0,
                            child: _buildDevice(devices, index, units, personnel, tracked),
                          );
                        },
                        padding: EdgeInsets.only(top: 8.0, bottom: 36.0),
                      );
              }),
        ),
      );
    });
  }

  List<Device> _filteredDevices() => context
      .read<DeviceBloc>()
      .values
      .where((device) =>
          _filter!.contains(device.type) &&
          (widget.query == null || _prepare(device).contains(widget.query!.toLowerCase())))
      .toList()
        ..sort(
          _compare,
        );

  String _prepare(Device device) => "${device.searchable} "
          "${_toDivision(device.number)} "
          "${_toFunction(device.number)}"
      .toLowerCase();

  int _compare(Device d1, Device d2) {
    return '${d1.number}'.toLowerCase().compareTo('${d2.number}'.toLowerCase());
  }

  Widget _buildDevice(
    List<Device> devices,
    int index,
    Map<String?, Unit?> units,
    Map<String?, Personnel?> personnel,
    Map<String?, Set<Tracking?>> tracked,
  ) {
    final device = devices[index];
    final status = _toTrackingStatus(tracked, device);
    final isThisApp = context.read<DeviceBloc>().isThisApp(device);
    return GestureDetector(
      child: widget.withActions && (isCommander || isThisApp)
          ? Slidable(
              actionPane: SlidableScrollActionPane(),
              actionExtentRatio: 0.2,
              child: DeviceTile(
                units: units,
                device: device,
                status: status,
                personnel: personnel,
              ),
              secondaryActions: <Widget>[
                _buildEditAction(device),
                if (isSelected && status != TrackingStatus.none)
                  _buildRemoveAction(device, units, personnel)
                else if (isSelected) ...[
                  _buildAddToUnitAction(device),
                  _buildAddToPersonnelAction(device),
                ]
              ],
            )
          : DeviceTile(
              units: units,
              device: device,
              status: status,
              personnel: personnel,
            ),
      onTap: () => Navigator.pushNamed(
        context,
        DeviceScreen.ROUTE,
        arguments: device,
      ),
    );
  }

  Widget _buildAddToUnitAction(Device device) => Tooltip(
        message: "Knytt til enhet",
        child: IconSlideAction(
          caption: 'KNYTT',
          icon: Icons.people,
          color: Theme.of(context).buttonColor,
          onTap: () async => await addToUnit(devices: [device]),
        ),
      );

  Widget _buildAddToPersonnelAction(Device device) => Tooltip(
        message: "Knytt til mannskap",
        child: IconSlideAction(
          caption: 'KNYTT',
          icon: Icons.person,
          color: Theme.of(context).buttonColor,
          onTap: () async => await addToPersonnel([device]),
        ),
      );

  IconSlideAction _buildEditAction(Device device) => IconSlideAction(
        caption: 'ENDRE',
        icon: Icons.more_horiz,
        color: Theme.of(context).buttonColor,
        onTap: () async => await editDevice(device),
      );

  IconSlideAction _buildRemoveAction(
    Device device,
    Map<String?, Unit?> units,
    Map<String?, Personnel?> personnel,
  ) =>
      IconSlideAction(
        caption: 'FJERN',
        color: Colors.red,
        icon: Icons.people,
        onTap: () async {
          final unit = units[device.uuid];
          if (unit != null) {
            final result = await removeFromUnit(unit, devices: [device])!;
            if (result.isLeft()) return;
          }
          final p = personnel[device.uuid];
          if (p != null) await removeFromPersonnel(p, devices: [device]);
        },
      );

  bool get isSelected => context.read<OperationBloc>().isSelected;
  bool get isCommander => context.read<OperationBloc>().isAuthorizedAs(UserRole.commander);

  TrackingStatus _toTrackingStatus(Map<String?, Set<Tracking?>> tracked, Device device) {
    return tracked[device.uuid]
            ?.firstWhere(
              (tracking) => tracking!.status != TrackingStatus.none,
              orElse: () => null,
            )
            ?.status ??
        TrackingStatus.none;
  }

  String? _toDivision(String? number) => context.read<AffiliationBloc>().findDivision(number)?.name;
  String? _toFunction(String? number) => context.read<AffiliationBloc>().findFunction(number)?.name;

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) => FilterSheet<DeviceType?>(
        initial: _filter,
        identifier: STATE,
        bucket: PageStorage.of(context),
        onRead: (value) => _onRead(value),
        onWrite: (value) => enumName(value),
        onBuild: () => DeviceType.values.map(
          (type) => FilterData(
            key: type,
            title: translateDeviceType(type),
          ),
        ),
        onChanged: (Set<DeviceType?> selected) => setState(() => _filter = selected),
      ),
    );
  }

  DeviceType? _onRead(value) => DeviceType.values.firstWhereOrNull(
        (e) => value == enumName(e),
      );
}

class DeviceSearch extends SearchDelegate<Device?> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/device/recent";

  ValueNotifier<Set<String>?> _recent = ValueNotifier(null);

  DeviceSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final always = const ["Vaktleder", "Ledelse", "Lag"];
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
                suggestions?.where(_matches).toList() ?? [],
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
        leading: Icon(index > 2 ? Icons.access_time : Icons.group),
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

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() as Set<String>?;
    buildSuggestions(context);
  }

  Widget _buildResults(BuildContext context, {bool store = false}) {
    if (store) {
      final recent = _recent.value!.toSet()..add(query);
      _storage.write(key: RECENT_KEY, value: json.encode(recent.toList()));
      _recent.value = recent.toSet() as Set<String>?;
    }
    return DevicesPage(
      query: query,
      withActions: false,
    );
  }
}
