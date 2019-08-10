import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/blocs/unit_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Device.dart';
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/services/assets_service.dart';
import 'package:SarSys/utils/defaults.dart';
import 'package:SarSys/utils/ui_utils.dart';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DevicesPage extends StatefulWidget {
  DevicesPage({Key key}) : super(key: key);

  @override
  DevicesPageState createState() => DevicesPageState();
}

class DevicesPageState extends State<DevicesPage> {
  List<DeviceType> _filter = DeviceType.values.toList();

  UnitBloc _unitBloc;
  DeviceBloc _deviceBloc;
  TrackingBloc _trackingBloc;
  StreamGroup<dynamic> _group;

  Map<String, String> _functions;
  Map<String, Division> _divisions;

  @override
  void initState() {
    super.initState();
    _unitBloc = BlocProvider.of<UnitBloc>(context);
    _deviceBloc = BlocProvider.of<DeviceBloc>(context);
    _trackingBloc = BlocProvider.of<TrackingBloc>(context);
    _group = StreamGroup.broadcast()..add(_unitBloc.state)..add(_deviceBloc.state)..add(_trackingBloc.state);
    _init();
  }

  void _init() async {
    _divisions = await AssetsService().fetchDivisions(Defaults.orgId);
    _functions = await AssetsService().fetchFunctions(Defaults.orgId);
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    _group.close();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await _unitBloc.fetch();
          await _deviceBloc.fetch();
          await _trackingBloc.fetch();
          setState(() {});
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: StreamBuilder(
              stream: _group.stream,
              builder: (context, snapshot) {
                var units = _trackingBloc.getUnitsByDeviceId();
                var tracked = _trackingBloc.getTrackingByDeviceId();
                var devices = _deviceBloc.devices.values.where((device) => _filter.contains(device.type)).toList();
                return AnimatedCrossFade(
                  duration: Duration(milliseconds: 300),
                  crossFadeState: _deviceBloc.devices.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Center(
                    child: CircularProgressIndicator(),
                  ),
                  secondChild: devices.isEmpty || snapshot.hasError
                      ? Center(
                          child: Text(
                          snapshot.hasError ? snapshot.error : "Ingen terminaler innen rekkevidde",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ))
                      : ListView.builder(
                          itemCount: devices.length + 1,
                          itemBuilder: (context, index) {
                            return _buildDevice(devices, index, units, tracked);
                          },
                        ),
                );
              }),
        ),
      );
    });
  }

  Widget _buildDevice(
    List<Device> devices,
    int index,
    Map<String, Set<Unit>> units,
    Map<String, Set<Tracking>> tracked,
  ) {
    if (index == devices.length) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text("Antall terminaler: $index"),
        ),
      );
    }
    final device = devices[index];
    tracked = _trackingBloc.getTrackingByDeviceId();
    final status = tracked[device.id]?.firstWhere((tracking) => tracking.status != TrackingStatus.None)?.status ??
        TrackingStatus.None;
    return Slidable(
      actionPane: SlidableScrollActionPane(),
      actionExtentRatio: 0.2,
      child: Container(
        color: Colors.white,
        child: ListTile(
          dense: true,
          key: ObjectKey(device.id),
          leading: CircleAvatar(
            backgroundColor: toTrackingStatusColor(context, status),
            child: Icon(FontAwesomeIcons.mobileAlt),
            foregroundColor: Colors.white,
          ),
          title: Text("ISSI: ${device.number}"),
          subtitle: Text(
            "${_toDistrict(device.number)}, "
            "${_toFunction(device.number)}, "
            "${_toStatusText(device, status, units[device.id]).toLowerCase()}",
          ),
          trailing: RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ),
      ),
      secondaryActions: <Widget>[
        if (status != TrackingStatus.None)
          IconSlideAction(
            caption: 'FJERN',
            color: Colors.red,
            icon: Icons.people,
            onTap: () => _removeFromUnits(device, units[device.id]),
          )
        else ...[
          IconSlideAction(
            caption: 'OPPRETT',
            color: Theme.of(context).buttonColor,
            icon: Icons.group_add,
            onTap: () => _createUnit(device),
          ),
          IconSlideAction(
            caption: 'KNYTT',
            color: Theme.of(context).buttonColor,
            icon: Icons.people,
            onTap: () async => _addToUnit(device),
          ),
        ]
      ],
    );
  }

  void _createUnit(Device device) async {
    showDialog<UnitEditorResult>(
      context: context,
      builder: (context) => UnitEditor(devices: [device]),
    );
  }

  void _addToUnit(Device device) async {
    var unit = await selectUnit(context);
    if (unit.tracking == null) {
      _trackingBloc.create(unit, [device]);
    } else if (_trackingBloc.tracks.containsKey(unit.tracking)) {
      var tracking = _trackingBloc.tracks[unit.tracking];
      var devices = _trackingBloc.getDevicesFromTrackingId(unit.tracking)..add(device);
      _trackingBloc.update(tracking, devices: devices);
    }
  }

  _removeFromUnits(Device device, Iterable<Unit> units) async {
    var proceed = await prompt(
      context,
      "Bekreft fjerning",
      "Dette vil fjerne ${device.name} fra ${units.length > 1 ? 'enheter' : 'enheten'} "
          "${units.map((unit) => unit.name).join(', ')}.",
    );
    if (proceed) {
      final bloc = BlocProvider.of<TrackingBloc>(context);
      units.forEach(
        (unit) => bloc.update(
          bloc.tracks[unit.tracking].cloneWith(
            devices: bloc.tracks[unit.tracking].devices.where((test) => test != device.id).toList(),
          ),
        ),
      );
    }
  }

  String _toStatusText(Device device, TrackingStatus status, Set<Unit> units) {
    switch (status) {
      case TrackingStatus.None:
        return "Ikke knyttet til enhet";
      case TrackingStatus.Created:
        return "Tilknyttet ${units.map((unit) => unit.name).join(",")}";
      case TrackingStatus.Tracking:
        return "Tilknyttet ${units.map((unit) => unit.name).join(",")}, sporer";
      case TrackingStatus.Paused:
        return "Tilknyttet ${units.map((unit) => unit.name).join(",")}, sporing pauset";
      case TrackingStatus.Closed:
        return "Tilknyttet ${units.map((unit) => unit.name).join(",")}, sporing fjernet";
    }
    throw "Status $status not recognized";
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
                        child: Text('BRUK', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.0)),
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
    });
  }
}
