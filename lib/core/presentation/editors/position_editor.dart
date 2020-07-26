import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:SarSys/features/device/presentation/blocs/device_bloc.dart';
import 'package:latlong/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:SarSys/features/settings/presentation/blocs/app_config_bloc.dart';
import 'package:SarSys/features/operation/domain/entities/Operation.dart';
import 'package:SarSys/core/presentation/map/map_widget.dart';
import 'package:SarSys/core/presentation/map/painters.dart';
import 'package:SarSys/core/presentation/map/map_search.dart';
import 'package:SarSys/core/domain/models/Position.dart';
import 'package:SarSys/core/data/services/location/location_service.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/core/presentation/widgets/coordinate_input.dart';

class PositionEditor extends StatefulWidget {
  final Position position;
  final String title;
  final Operation operation;
  const PositionEditor(
    this.position, {
    Key key,
    this.operation,
    @required this.title,
  }) : super(key: key);

  @override
  _PositionEditorState createState() => _PositionEditorState();
}

class _PositionEditorState extends State<PositionEditor> with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFieldKey = GlobalKey<MapSearchFieldState>();

  Position _current;
  MapSearchField _searchField;
  MapWidgetController _mapController;

  StreamController<LatLng> _changes;

  @override
  void initState() {
    super.initState();
    _mapController = MapWidgetController();
    _changes = StreamController<LatLng>();
    _searchField = MapSearchField(
      key: _searchFieldKey,
      offset: 106.0,
      withBorder: false,
      onError: _onError,
      mapController: _mapController,
      onMatch: (point) => setState(() => _setFromLatLng(point)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _current ??= _ensurePosition();
  }

  Position _setFromLatLng(LatLng point) => _current = Position.now(
        lat: point.latitude,
        lon: point.longitude,
        source: PositionSource.manual,
      );

  Position _ensurePosition() => widget.position?.isNotEmpty != true
      ? Position.fromPoint(
            LocationService(
              configBloc: context.bloc<AppConfigBloc>(),
              duuid: context.bloc<DeviceBloc>().findThisApp()?.uuid,
            ).current.geometry,
            source: PositionSource.manual,
          ) ??
          Position.now(
            lat: 59.5,
            lon: 10.09,
            source: PositionSource.manual,
          )
      : widget.position;

  @override
  void dispose() {
    _changes?.close();
    _mapController?.cancel();
    _changes = null;
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        leading: GestureDetector(
          child: Icon(Icons.close),
          onTap: () {
            _searchFieldKey.currentState.clear();
            Navigator.pop(context);
          },
        ),
        actions: <Widget>[
          FlatButton(
            child: Text('FERDIG', style: TextStyle(fontSize: 14.0, color: Colors.white)),
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            onPressed: () {
              Navigator.pop(context, _current);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildCenterMark(),
          _buildInputFields(),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    final size = MediaQuery.of(context).size;
    final maxWidth = min(min(size.width, size.height), 480.0);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSearchField(),
                _buildUTMField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0, top: 4.0),
      child: _searchField,
    );
  }

  Widget _buildUTMField() {
    return StreamBuilder<LatLng>(
        initialData: toLatLng(_current?.geometry),
        stream: _changes.stream,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Container(
                  margin: EdgeInsets.only(left: 8.0, right: 8.0, bottom: 0.0),
                  child: CoordinateInput(
                    point: snapshot.data,
                    onChanged: (point) {
                      _mapController.animatedMove(point, _mapController.zoom, this);
                      _setFromLatLng(point);
                    },
                  ),
                )
              : Container();
        });
  }

  Widget _buildMap() {
    return MapWidget(
      operation: widget.operation,
      center: _mapController.ready ? _mapController.center : LatLng(_current.lat, _current.lon),
      mapController: _mapController,
      withRead: true,
      readLayers: true,
      withPOIs: true,
      withUnits: false,
      withScaleBar: true,
      withControls: true,
      withControlsZoom: true,
      withControlsBaseMap: true,
      withControlsLocateMe: true,
      withControlsOffset: 180,
      onPositionChanged: _onPositionChanged,
      onTap: (_) => _searchFieldKey.currentState.clear(),
    );
  }

  Center _buildCenterMark() {
    return Center(
      child: SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: CrossPainter(color: Colors.red.withOpacity(0.6)),
          )),
    );
  }

  void _onError(String message) {
    final snackbar = SnackBar(
      duration: Duration(seconds: 2),
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(message),
      ),
      action: SnackBarAction(
        label: "OK",
        onPressed: () {
          _scaffoldKey.currentState.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
        },
      ),
    );
    _scaffoldKey.currentState.showSnackBar(snackbar);
  }

  void _onPositionChanged(MapPosition position, bool hasGesture) {
    if (hasGesture) {
      _setFromLatLng(position.center);
      _changes.add(position.center);
    }
  }
}
