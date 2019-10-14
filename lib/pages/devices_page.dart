import 'dart:convert';

import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/core/defaults.dart';
import 'package:SarSys/usecase/device.dart';
import 'package:SarSys/usecase/unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class DevicesPage extends StatefulWidget {
  final String query;
  final bool withActions;

  DevicesPage({Key key, this.query, this.withActions = true}) : super(key: key);

  @override
  DevicesPageState createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  List<DeviceType> _filter = DeviceType.values.toList();

  UserBloc _userBloc;
  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Map<String, String> _functions;
  Map<String, Division> _divisions;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userBloc = BlocProvider.of<UserBloc>(context);
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    if (_group != null) _group.close();
    _group = StreamGroup.broadcast()
      ..add(_userBloc.state)
      ..add(_unitBloc.state)
      ..add(_deviceBloc.state)
      ..add(_trackingBloc.state);
  }

  void _init() async {
    _divisions = await AssetsService().fetchDivisions(Defaults.orgId);
    _functions = await AssetsService().fetchFunctions(Defaults.orgId);
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
          _deviceBloc.fetch();
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData == false) return Container();
                var units = _trackingBloc.getUnitsByDeviceId();
                var tracked = _trackingBloc.getTrackingByDeviceId();
                var devices = _deviceBloc.devices.values
                    .where((device) =>
                        _filter.contains(device.type) &&
                        (widget.query == null || _prepare(device).contains(widget.query.toLowerCase())))
                    .toList();
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
                          return _buildDevice(devices, index, units, tracked);
                        },
                      );
              }),
        ),
      );
    });
  }

  String _prepare(Device device) => "${device.searchable} "
          "${_toDistrict(device.number)} "
          "${_toFunction(device.number)}"
      .toLowerCase();

  Widget _buildDevice(
    List<Device> devices,
    int index,
    Map<String, Unit> units,
    Map<String, Set<Tracking>> tracked,
  ) {
    if (index == devices.length) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text("Antall apparater: $index"),
        ),
      );
    }
    final device = devices[index];
    final status = _toTrackingStatus(tracked, device);
    return widget.withActions && _userBloc?.user?.isCommander == true
        ? Slidable(
            actionPane: SlidableScrollActionPane(),
            actionExtentRatio: 0.2,
            child: _buildDeviceTile(device, status, units),
            secondaryActions: <Widget>[
              _buildEditAction(device),
              if (status != TrackingStatus.None)
                _buildRemoveAction(device, units)
              else ...[
                _buildCreateAction(device),
                _buildAttachAction(device),
              ]
            ],
          )
        : _buildDeviceTile(device, status, units);
  }

  IconSlideAction _buildAttachAction(Device device) {
    return IconSlideAction(
      caption: 'KNYTT',
      color: Theme.of(context).buttonColor,
      icon: Icons.people,
      onTap: () async => await addToUnit(context, [device]),
    );
  }

  IconSlideAction _buildCreateAction(Device device) {
    return IconSlideAction(
      caption: 'OPPRETT',
      color: Theme.of(context).buttonColor,
      icon: Icons.group_add,
      onTap: () async => await createUnit(context, devices: [device]),
    );
  }

  IconSlideAction _buildEditAction(Device device) {
    return IconSlideAction(
      caption: 'ENDRE',
      color: Theme.of(context).buttonColor,
      icon: Icons.more_horiz,
      onTap: () async => await editDevice(context, device),
    );
  }

  IconSlideAction _buildRemoveAction(Device device, Map<String, Unit> units) {
    return IconSlideAction(
      caption: 'FJERN',
      color: Colors.red,
      icon: Icons.people,
      onTap: () async => await removeFromUnit(context, units[device.id], devices: [device]),
    );
  }

  Widget _buildDeviceTile(Device device, TrackingStatus status, Map<String, Unit> units) {
    return Container(
      key: ObjectKey(device.id),
      color: Colors.white,
      constraints: BoxConstraints.expand(),
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: GestureDetector(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: toPointStatusColor(device.point),
              child: Icon(MdiIcons.cellphoneBasic),
              foregroundColor: Colors.white,
            ),
            SizedBox(width: 16.0),
            Chip(
              label: Text("${device.number}"),
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
              child: Text(translateDeviceType(device.type), overflow: TextOverflow.ellipsis),
            ),
            SizedBox(width: 4.0),
            Chip(
              label: Text("${units[device.id]?.name ?? ""} "
                  "${formatSince(device?.point?.timestamp, defaultValue: "ingen")}"),
              labelPadding: EdgeInsets.only(right: 4.0),
              backgroundColor: Colors.grey[100],
              avatar: Icon(
                Icons.my_location,
                size: 16.0,
                color: toPointStatusColor(device?.point),
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
        onTap: () => Navigator.pushNamed(context, 'device', arguments: device),
      ),
    );
  }

  TrackingStatus _toTrackingStatus(Map<String, Set<Tracking>> tracked, Device device) {
    return tracked[device.id]?.firstWhere((tracking) => tracking.status != TrackingStatus.None)?.status ??
        TrackingStatus.None;
  }

  String _toDistrict(String number) {
    String id = number?.substring(2, 5);
    return _divisions?.entries?.firstWhere((entry) => entry.key == id, orElse: () => null)?.value?.name;
  }

  String _toFunction(String number) {
    return _functions?.entries?.firstWhere((entry) => RegExp(entry.key).hasMatch(number), orElse: () => null)?.value;
  }

  void showFilterSheet(context) {
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
                    ...DeviceType.values
                        .map((status) => ListTile(
                            dense: landscape,
                            title: Text(translateDeviceType(status), style: style),
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

  void _onFilterChanged(DeviceType status, bool value, StateSetter update) {
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

class DeviceSearch extends SearchDelegate<Device> {
  static final _storage = new FlutterSecureStorage();
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
    return DevicesPage(query: query);
  }

  void _delete(BuildContext context, List<String> suggestions, int index) async {
    final recent = suggestions.toList()..remove(suggestions[index]);
    await _storage.write(key: RECENT_KEY, value: json.encode(recent));
    _recent.value = recent.toSet() ?? [];
    buildSuggestions(context);
  }
}
