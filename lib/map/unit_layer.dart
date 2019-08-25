import 'dart:math';

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/editors/unit_editor.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/map/painters.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

typedef MessageCallback = void Function(String message);

class UnitLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  bool showTail;
  final TrackingBloc bloc;
  final MessageCallback onMessage;

  UnitLayerOptions({
    @required this.bloc,
    this.size = 24.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.showTail = true,
    this.onMessage,
    Stream<Null> rebuild,
  }) : super(rebuild: rebuild);
}

class UnitLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is UnitLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<Null> stream) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints bc) {
        final size = Size(bc.maxWidth, bc.maxHeight);
        return StreamBuilder<void>(
          stream: stream, // a Stream<int> or null
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            return _build(context, size, options as UnitLayerOptions, map);
          },
        );
      },
    );
  }

  Widget _build(BuildContext context, Size size, UnitLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final tracks = options.bloc.tracks;
    final units = sortMapValues<String, Unit, TrackingStatus>(
            options.bloc.units, (unit) => tracks[unit.tracking].status, (s1, s2) => s1.index - s2.index)
        .values
        .where((unit) => bounds.contains(toLatLng(tracks[unit.tracking].location)));
    return options.bloc.isEmpty
        ? Container()
        : Stack(
            overflow: Overflow.clip,
            children: [
              if (options.showTail)
                ...units.map((unit) => _buildTrack(context, size, options, map, unit, tracks[unit.tracking])).toList(),
              if (options.showLabels)
                ...units
                    .map((unit) => _buildLabel(context, options, map, unit, tracks[unit.tracking].location))
                    .toList(),
              ...units.map((unit) => _buildPoint(context, options, map, unit, tracks[unit.tracking])).toList(),
            ],
          );
  }

  _buildTrack(
    BuildContext context,
    Size size,
    UnitLayerOptions options,
    MapState map,
    Unit unit,
    Tracking tracking,
  ) {
    var offsets = tracking.track.reversed.take(10).map((point) {
      var pos = map.project(toLatLng(point));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();
      return Offset(pos.x.toDouble(), pos.y.toDouble());
    }).toList(growable: false);

    final color = _toTrackingStatusColor(context, tracking.status);

    return Opacity(
      opacity: options.opacity,
      child: CustomPaint(
        painter: LineStringPainter(
          offsets,
          color,
          color,
          4.0,
          false,
        ),
        size: size,
      ),
    );
  }

  Widget _buildPoint(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Tracking tracking) {
    var size = options.size;
    var pos = map.project(toLatLng(tracking.location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      width: size,
      height: size,
      left: pos.x - size / 2,
      top: pos.y - size / 2,
      child: Opacity(
        opacity: options.opacity,
        child: CustomPaint(
          painter: PointPainter(
            size: size,
            color: _toTrackingStatusColor(context, tracking.status),
          ),
        ),
      ),
    );
  }

  _buildLabel(BuildContext context, UnitLayerOptions options, MapState map, Unit unit, Point point) {
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      left: pos.x,
      top: pos.y,
      child: CustomPaint(
        painter: LabelPainter(
          unit.name,
        ),
      ),
    );
  }

  static void showUnitMenu(
    BuildContext context,
    Unit unit,
    TrackingBloc bloc,
    MessageCallback onMessage,
  ) async {
    final title = Theme.of(context).textTheme.title;
    final tracking = bloc.tracks[unit.tracking];
    final action = await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: 232,
            width: MediaQuery.of(context).size.width - 112,
            child: ListView(
              children: <Widget>[
                ListTile(
                  dense: true,
                  leading: Icon(Icons.group),
                  title: Text("Endre ${unit.name}", style: title),
                  onTap: () => Navigator.pop(context, 1),
                ),
                Divider(),
                ListTile(
                  dense: true,
                  leading: Icon(tracking.status == TrackingStatus.Tracking
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline),
                  title: Text(
                    tracking.status == TrackingStatus.Tracking ? "Stopp sporing" : "Start sporing",
                    style: title,
                  ),
                  onTap: () => Navigator.pop(context, 2),
                ),
                Divider(),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.content_copy),
                  title: Text("Kopier UTM", style: title),
                  onTap: () => Navigator.pop(context, 3),
                ),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.content_copy),
                  title: Text("Kopier desmialgrader", style: title),
                  onTap: () => Navigator.pop(context, 4),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (action) {
      case 1:
        showDialog(
          context: context,
          builder: (context) => UnitEditor(unit: unit),
        );
        break;
      case 2:
        bloc.transition(tracking);
        break;
      case 3:
        _copy(toUTM(tracking.location, prefix: ""), onMessage);
        break;
      case 4:
        _copy(toDD(tracking.location, prefix: ""), onMessage);
        break;
    }
  }

  static void showUnitInfo(
    BuildContext context,
    Unit unit,
    TrackingBloc bloc,
    MessageCallback onMessage,
  ) {
    final style = Theme.of(context).textTheme.title;
    final tracking = bloc.tracks[unit.tracking];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          elevation: 0,
          backgroundColor: Colors.white,
          child: SizedBox(
            height: 380,
            width: MediaQuery.of(context).size.width - 96,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(left: 16, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('${unit.name}', style: style),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Divider(),
                _buildCopyableText(
                  context: context,
                  label: "UTM",
                  icon: Icon(Icons.my_location),
                  value: toUTM(tracking.location, prefix: ""),
                  onMessage: onMessage,
                ),
                _buildCopyableText(
                  context: context,
                  label: "Desimalgrader (DD)",
                  icon: Icon(Icons.my_location),
                  value: toDD(tracking.location, prefix: ""),
                  onMessage: onMessage,
                ),
                Divider(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildCopyableText(
                        context: context,
                        label: "Kallesignal",
                        icon: Icon(Icons.headset_mic),
                        value: unit.callsign,
                        onMessage: onMessage,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        child: _buildCopyableText(
                          context: context,
                          label: "Mobil",
                          icon: Icon(Icons.phone),
                          value: unit?.phone ?? "Ukjent",
                          onMessage: onMessage,
                        ),
                        onTap: () {
                          final number = unit?.phone ?? '';
                          if (number.isNotEmpty) launch("tel:$number");
                        },
                      ),
                    ),
                  ],
                ),
                Divider(),
                _buildCopyableText(
                  context: context,
                  label: "Terminaler",
                  icon: Icon(FontAwesomeIcons.mobileAlt),
                  value: tracking.devices.map((id) => bloc.deviceBloc.devices[id]?.number)?.join(', ') ?? '',
                  onMessage: onMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildCopyableText({
    BuildContext context,
    String label,
    Icon icon,
    String value,
    MessageCallback onMessage,
  }) {
    return GestureDetector(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon,
          border: InputBorder.none,
        ),
        child: Text(value),
      ),
      onLongPress: () {
        Navigator.pop(context);
        _copy(value, onMessage);
      },
    );
  }

  static void _copy(String value, MessageCallback onMessage) {
    Clipboard.setData(ClipboardData(text: value));
    if (onMessage != null) {
      onMessage('Kopiert til utklippstavlen');
    }
  }
}

Color _toTrackingStatusColor(BuildContext context, TrackingStatus status) {
  switch (status) {
    case TrackingStatus.None:
    case TrackingStatus.Created:
    case TrackingStatus.Closed:
      return Colors.red;
    case TrackingStatus.Tracking:
      return Colors.green;
    case TrackingStatus.Paused:
      return Colors.orange;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}
