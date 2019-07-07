import 'package:SarSys/blocs/device_bloc.dart';
import 'package:SarSys/models/Device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class DevicesPage extends StatefulWidget {
  @override
  _DevicesPageState createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  DeviceBloc bloc;

  @override
  void initState() {
    super.initState();
    bloc = BlocProvider.of<DeviceBloc>(context).init(setState);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints viewportConstraints) {
      return RefreshIndicator(
        onRefresh: () async {
          await bloc.fetch();
          setState(() {});
        },
        child: Container(
          color: Color.fromRGBO(168, 168, 168, 0.6),
          child: AnimatedCrossFade(
            duration: Duration(milliseconds: 300),
            crossFadeState: bloc.devices.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Center(
              child: CircularProgressIndicator(),
            ),
            secondChild: StreamBuilder(
              stream: bloc.state,
              builder: (context, snapshot) {
                var devices = bloc.devices;
                return devices.isNotEmpty
                    ? _buildList(devices)
                    : Center(
                        child: Text(
                          "Ingen terminaler innen rekkevidde",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
              },
            ),
          ),
        ),
      );
    });
  }

  ListView _buildList(List<Device> devices) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        return Slidable(
          actionPane: SlidableScrollActionPane(),
          actionExtentRatio: 0.2,
          child: Container(
            color: Colors.white,
            child: ListTile(
              key: ObjectKey(devices[index].id),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text('${index + 1}'),
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
      },
    );
  }
}
