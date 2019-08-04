import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/models/Device.dart';
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
  DeviceBloc bloc;
  List<DeviceType> _filter = DeviceType.values.toList();

  @override
  void initState() {
    super.initState();
    bloc = BlocProvider.of<DeviceBloc>(context);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return RefreshIndicator(
          onRefresh: () async {
            await bloc.fetch();
            setState(() {});
          },
          child: Container(
            color: Color.fromRGBO(168, 168, 168, 0.6),
            child: StreamBuilder(
              stream: bloc.state,
              builder: (context, snapshot) {
                var devices = bloc.devices.values.where((device) => _filter.contains(device.type)).toList();
                return AnimatedCrossFade(
                  duration: Duration(milliseconds: 300),
                  crossFadeState: bloc.devices.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
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
                            return _buildDevice(devices, index);
                          },
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevice(List<Device> devices, int index) {
    if (index == devices.length) {
      return SizedBox(
        height: 88,
        child: Center(
          child: Text("Antall terminaler: $index"),
        ),
      );
    }
    return Slidable(
      actionPane: SlidableScrollActionPane(),
      actionExtentRatio: 0.2,
      child: Container(
        color: Colors.white,
        child: ListTile(
          dense: true,
          key: ObjectKey(devices[index].id),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(FontAwesomeIcons.mobileAlt),
            foregroundColor: Colors.white,
          ),
          title: Text("ISSI: ${devices[index].number}"),
          subtitle: Text(translateDeviceType(devices[index].type)),
          trailing: RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        IconSlideAction(
          caption: 'KNYTT',
          color: Theme.of(context).buttonColor,
          icon: Icons.people,
          onTap: () => {},
        ),
      ],
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'VIS',
          color: Theme.of(context).buttonColor,
          icon: Icons.gps_fixed,
          onTap: () => {},
        ),
        IconSlideAction(
          caption: 'SPOR',
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.play_arrow,
          onTap: () => {},
        ),
      ],
    );
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
