

import 'dart:async';

import 'package:SarSys/features/user/domain/entities/User.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/features/operation/domain/usecases/operation_use_cases.dart';
import 'package:SarSys/features/operation/presentation/blocs/operation_bloc.dart';
import 'package:SarSys/features/mapping/presentation/widgets/map_widget.dart';
import 'package:SarSys/features/unit/domain/usecases/unit_use_cases.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/utils/ui.dart';
import 'package:SarSys/core/presentation/screens/screen.dart';

import 'package:SarSys/core/presentation/widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  static const ROUTE = 'map';

  final LatLng? center;
  final Operation? operation;
  final LatLngBounds? fitBounds;
  final FitBoundsOptions? fitBoundOptions;

  const MapScreen({
    Key? key,
    this.center,
    this.fitBounds,
    this.fitBoundOptions,
    this.operation,
  }) : super(key: key);

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends RouteWriter<MapScreen, String> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _mapController = MapWidgetController();

  bool _showFAB = true;

  bool _unloaded = false;
  StreamSubscription<OperationState?>? _subscription;
  Operation? get operation => _unloaded ? null : widget.operation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenForIncidentStates();
  }

  /// Initialize blocs and restart app after blocs are rebuilt
  void _listenForIncidentStates() {
    _subscription?.cancel();
    _subscription = context.read<OperationBloc>().stream.listen((state) {
      setState(() {
        _unloaded = state.shouldUnload(widget.operation?.uuid);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(),
      extendBody: true,
      floatingActionButton: _showFAB && context.read<OperationBloc>().isAuthorizedAs(UserRole.commander)
          ? FloatingActionButton(
              onPressed: () {
                _showCreateItemSheet(context);
              },
              child: Icon(Icons.add),
              elevation: 2.0,
            )
          : Container(),
      body: _buildMap(),
    );
  }

  Widget _buildMap() => MapWidget(
        operation: operation,
        center: widget.center,
        fitBounds: widget.fitBounds,
        fitBoundOptions: widget.fitBoundOptions,
        mapController: _mapController,
        readZoom: true,
        readCenter: widget.center == null,
        readLayers: true,
        withRead: true,
        withWrite: true,
        withSearch: true,
        withControls: true,
        withControlsZoom: true,
        withControlsTool: true,
        withControlsLayer: true,
        withControlsBaseMap: true,
        withControlsLocateMe: true,
        withScaleBar: true,
        withCoordsPanel: true,
        onMessage: _showMessage,
        onToolChange: (tool) => setState(() {
          _showFAB = !tool.active();
        }),
        onOpenDrawer: () => _scaffoldKey.currentState!.openDrawer(),
      );

  void _showCreateItemSheet(BuildContext context) {
    final style = Theme.of(context).textTheme.headline6;
    final isSelected = context.read<OperationBloc>().isSelected;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bc) {
        return StatefulBuilder(builder: (_, state) {
          final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
          return DraggableScrollableSheet(
              expand: false,
              builder: (_, controller) {
                return ListView(
                  padding: EdgeInsets.only(bottom: 56.0),
                  children: <Widget>[
                    ListTile(title: Text("Opprett", style: style)),
                    Divider(),
                    if (isSelected)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.group_add),
                        title: Text('Enhet', style: style),
                        onTap: () async {
                          await createUnit(
                            position: toPosition(_mapController.center),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    if (!isSelected)
                      ListTile(
                        dense: landscape,
                        leading: Icon(Icons.warning),
                        title: Text('Aksjon', style: style),
                        onTap: () async {
                          final result = await createOperation(
                            ipp: toPoint(_mapController.center),
                          )!;
                          result.fold((_) => null, (incident) => jumpToOperation(context, incident));
                          Navigator.pop(context);
                        },
                      ),
                  ],
                );
              });
        });
      },
    );
  }

  void _showMessage(
    String message, {
    String action = "OK",
    VoidCallback? onPressed,
    dynamic data,
  }) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: _buildAction(action, () {
        if (onPressed != null) onPressed();
        ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
      }) as SnackBarAction?,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }

  Widget _buildAction(String label, VoidCallback onPressed) {
    return SnackBarAction(
      label: label,
      onPressed: onPressed,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
