import 'dart:convert';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/personnel_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/features/user/presentation/blocs/user_bloc.dart';
import 'package:SarSys/core/storage.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Personnel.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/screens/device_screen.dart';
import 'package:SarSys/services/fleet_map_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/usecase/device_use_cases.dart';
import 'package:SarSys/usecase/personnel_use_cases.dart';
import 'package:SarSys/usecase/unit_use_cases.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:SarSys/widgets/filter_sheet.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class DevicesPage extends StatefulWidget {
  final String query;
  final bool withActions;

  DevicesPage({Key key, this.query, this.withActions = true}) : super(key: key);

  @override
  DevicesPageState createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  static const STATE = "devices_filter";
  Set<DeviceType> _filter;

  StreamGroup<dynamic> _group;

  Map<String, String> _functions;
  Map<String, Division> _divisions;

  @override
  void initState() {
    super.initState();
    _filter = FilterSheet.read(context, STATE, defaultValue: DeviceType.values.toSet(), onRead: _onRead);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(context.bloc<UserBloc>())
      ..add(context.bloc<UnitBloc>())
      ..add(context.bloc<PersonnelBloc>())
      ..add(context.bloc<DeviceBloc>())
      ..add(context.bloc<TrackingBloc>());
  }

  void _init() async {
    _divisions = await FleetMapService().fetchDivisions(Defaults.orgId);
    _functions = await FleetMapService().fetchFunctions(Defaults.orgId);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _group.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          context.bloc<DeviceBloc>().load();
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var units = context.bloc<TrackingBloc>().units.devices();
                var personnel = context.bloc<TrackingBloc>().personnels.devices();
                var tracked = context.bloc<TrackingBloc>().asDeviceIds();
                var devices = _filteredDevices();
                return devices.isEmpty || snapshot.hasError
                    ? toRefreshable(
                        viewportConstraints,
                        message: snapshot.hasError
                            ? snapshot.error
                            : "Ingen apparater innen rekkevidde\n\n Legg til et apparat manuelt",
                      )
                    : ListView.builder(
                        itemCount: devices.length + 1,
                        itemExtent: 72.0,
                        itemBuilder: (context, index) {
                          return _buildDevice(devices, index, units, personnel, tracked);
                        },
                      );
              }),
        ),
      );
    });
  }

  List<Device> _filteredDevices() => context
      .bloc<DeviceBloc>()
      .devices
      .values
      .where((device) =>
          _filter.contains(device.type) &&
          (widget.query == null || _prepare(device).contains(widget.query.toLowerCase())))
      .toList()
        ..sort(
          (d1, d2) => d1.number.toLowerCase().compareTo(d2.number.toLowerCase()),
        );

  String _prepare(Device device) => "${device.searchable} "
          "${_toDistrict(device.number)} "
          "${_toFunction(device.number)}"
      .toLowerCase();

  Widget _buildDevice(
    List<Device> devices,
    int index,
    Map<String, Unit> units,
    Map<String, Personnel> personnel,
    Map<String, Set<Tracking>> tracked,
  ) {
    if (index == devices.length) {
      return Center(
        child: Text("Antall apparater: $index"),
      );
    }
    final device = devices[index];
    final status = _toTrackingStatus(tracked, device);
    return widget.withActions && context.bloc<UserBloc>()?.user?.isCommander == true
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildDeviceTile(device, status, units, personnel),
            secondaryActions: <Widget>[
              _buildEditAction(device),
              if (status != TrackingStatus.none)
                _buildRemoveAction(device, units, personnel)
              else ...[
                _buildAddToUnitAction(device),
                _buildAddToPersonnelAction(device),
              ]
            ],
          )
        : _buildDeviceTile(device, status, units, personnel);
  }

  Widget _buildAddToUnitAction(Device device) => Tooltip(
        message: "Knytt til enhet",
        child: IconSlideAction(
          caption: 'KNYTT',
          color: Theme.of(context).buttonColor,
          icon: Icons.people,
          onTap: () async => await addToUnit(devices: [device]),
        ),
      );

  Widget _buildAddToPersonnelAction(Device device) => Tooltip(
        message: "Knytt til mannskap",
        child: IconSlideAction(
          caption: 'KNYTT',
          color: Theme.of(context).buttonColor,
          icon: Icons.person,
          onTap: () async => await addToPersonnel([device]),
        ),
      );

  IconSlideAction _buildEditAction(Device device) => IconSlideAction(
        caption: 'ENDRE',
        color: Theme.of(context).buttonColor,
        icon: Icons.more_horiz,
        onTap: () async => await editDevice(device),
      );

  IconSlideAction _buildRemoveAction(
    Device device,
    Map<String, Unit> units,
    Map<String, Personnel> personnel,
  ) =>
      IconSlideAction(
        caption: 'FJERN',
        color: Colors.red,
        icon: Icons.people,
        onTap: () async {
          final unit = units[device.uuid];
          if (unit != null) {
            final result = await removeFromUnit(unit, devices: [device]);
            if (result.isLeft()) return;
          }
          final p = personnel[device.uuid];
          if (p != null) await removeFromPersonnel(p, devices: [device]);
        },
      );

  Widget _buildDeviceTile(
    Device device,
    TrackingStatus status,
    Map<String, Unit> units,
    Map<String, Personnel> personnel,
  ) {
    return Container(
      key: ObjectKey(device.uuid),
      color: Colors.white,
      constraints: BoxConstraints.expand(),
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: GestureDetector(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: toPositionStatusColor(device.position),
              child: Icon(toDeviceIconData(device.type)),
              foregroundColor: Colors.white,
            ),
            SizedBox(width: 16.0),
            Chip(
              label: Text(
                [device.number, device.alias].where((value) => emptyAsNull(value) != null).join(' '),
              ),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                toDialerIconData(device.type),
                size: 16.0,
                color: Colors.black38,
              ),
            ),
            Spacer(),
            Chip(
              label: Text(_toUsage(units, personnel, device)),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                Icons.my_location,
                size: 16.0,
                color: toPositionStatusColor(device?.position),
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
        onTap: () => Navigator.pushNamed(context, DeviceScreen.ROUTE, arguments: device),
      ),
    );
  }

  String _toUsage(
    Map<String, Unit> units,
    Map<String, Personnel> personnel,
    Device device,
  ) {
    final name = units[device.uuid]?.name ?? personnel[device.uuid]?.formal ?? '';
    return "$name ${formatSince(device?.position?.timestamp, defaultValue: "ingen")}";
  }

  TrackingStatus _toTrackingStatus(Map<String, Set<Tracking>> tracked, Device device) {
    return tracked[device.uuid]
            ?.firstWhere(
              (tracking) => tracking.status != TrackingStatus.none,
              orElse: () => null,
            )
            ?.status ??
        TrackingStatus.none;
  }

  String _toDistrict(String number) {
    String id = number?.substring(2, 5);
    return _divisions?.entries
        ?.firstWhere(
          (entry) => entry.key == id,
          orElse: () => null,
        )
        ?.value
        ?.name;
  }

  String _toFunction(String number) {
    return _functions?.entries
        ?.firstWhere(
          (entry) => RegExp(entry.key).hasMatch(number),
          orElse: () => null,
        )
        ?.value;
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) => FilterSheet<DeviceType>(
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
        onChanged: (Set<DeviceType> selected) => setState(() => _filter = selected),
      ),
    );
  }

  DeviceType _onRead(value) => DeviceType.values.firstWhere(
        (e) => value == enumName(e),
        orElse: () => null,
      );
}

class DeviceSearch extends SearchDelegate<Device> {
  static final _storage = Storage.secure;
  static const RECENT_KEY = "search/device/recent";

  ValueNotifier<Set<String>> _recent = ValueNotifier(null);

  DeviceSearch() {
    _init();
  }

  void _init() async {
    final stored = await _storage.read(key: RECENT_KEY);
    final List recent = stored != null
        ? json.decode(stored)
        : [
            "Vaktleder",
            "Ledelse",
            "Lag",
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
        leading: Icon(index > 2 ? Icons.access_time : Icons.group),
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
    return DevicesPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}
