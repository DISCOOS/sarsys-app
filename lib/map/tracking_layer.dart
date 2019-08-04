import 'dart:ui' as ui;

import 'package:SarSys/blocs/tracking_bloc.dart';
import 'package:SarSys/models/Point.dart';
import 'package:SarSys/models/Tracking.dart';
import 'package:SarSys/models/Unit.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

typedef MessageCallback = void Function(String message);

class TrackingLayerOptions extends LayerOptions {
  double size;
  double opacity;
  bool showLabels;
  final TrackingBloc bloc;
  final MessageCallback onMessage;

  TrackingLayerOptions({
    @required this.bloc,
    this.size = 24.0,
    this.opacity = 0.6,
    this.showLabels = true,
    this.onMessage,
    Stream<void> rebuild,
  }) : super(rebuild: rebuild);
}

class TrackingLayer extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is TrackingLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState map, Stream<void> stream) {
    return StreamBuilder<void>(
      stream: stream, // a Stream<int> or null
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        return _build(context, options as TrackingLayerOptions, map);
      },
    );
  }

  Widget _build(BuildContext context, TrackingLayerOptions options, MapState map) {
    final bounds = map.getBounds();
    final tracks = options.bloc.tracks;
    final units = options.bloc.units.values.where((unit) => bounds.contains(toLatLng(tracks[unit.tracking].location)));
    return options.bloc.isEmpty
        ? Container()
        : Stack(children: [
            ...units.map((unit) => _buildPoint(context, options, map, unit, tracks[unit.tracking])).toList(),
            if (options.showLabels)
              ...units.map((unit) => _buildLabel(context, options, map, unit, tracks[unit.tracking].location)).toList(),
          ]);
  }

  Widget _buildPoint(BuildContext context, TrackingLayerOptions options, MapState map, Unit unit, Tracking tracking) {
    var size = options.size;
    var pos = map.project(toLatLng(tracking.location));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      width: size,
      height: size,
      left: pos.x - size / 2,
      top: pos.y - size / 2,
      child: GestureDetector(
        child: Opacity(
          opacity: options.opacity,
          child: CustomPaint(
            painter: _PointPainter(
              size: size,
              color: _toTrackingStatusColor(context, tracking.status),
            ),
          ),
        ),
        //TODO: onLongPress: () => _showUnitActions(context, options, map, unit, tracking, pos),
        onDoubleTap: () => _showUnitInfo(context, options, map, unit, tracking, pos),
      ),
    );
  }

  _buildLabel(BuildContext context, TrackingLayerOptions options, MapState map, Unit unit, Point point) {
    var pos = map.project(toLatLng(point));
    pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

    return Positioned(
      left: pos.x,
      top: pos.y,
      child: CustomPaint(
        painter: _LabelPainter(
          unit.name,
        ),
      ),
    );
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

  void _showUnitInfo(
    BuildContext context,
    TrackingLayerOptions options,
    MapState map,
    Unit unit,
    Tracking tracking,
    CustomPoint position,
  ) {
    final style = Theme.of(context).textTheme.title;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          elevation: 0,
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.only(left: 16, top: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('${unit.name}', style: style),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: SizedBox(
            height: 320,
            width: MediaQuery.of(context).size.width - 96,
            child: Column(
              children: <Widget>[
                Divider(),
                _buildCopyableText(
                  context: context,
                  label: "UTM",
                  icon: Icon(Icons.my_location),
                  value: toUTM(tracking.location, prefix: ""),
                  onMessage: options.onMessage,
                ),
                _buildCopyableText(
                  context: context,
                  label: "Desimalgrader (DD)",
                  icon: Icon(Icons.my_location),
                  value: toDD(tracking.location, prefix: ""),
                  onMessage: options.onMessage,
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
                        onMessage: options.onMessage,
                      ),
                    ),
                    Expanded(
                      child: _buildCopyableText(
                        context: context,
                        label: "Mobiltelefon",
                        icon: Icon(Icons.phone),
                        value: unit?.phone ?? "Ukjent",
                        onMessage: options.onMessage,
                      ),
                    ),
                  ],
                ),
                Divider(),
                _buildCopyableText(
                  context: context,
                  label: "Terminaler",
                  icon: Icon(FontAwesomeIcons.mobileAlt),
                  value: tracking.devices.map((id) => options.bloc.deviceBloc.devices[id].number).join(', '),
                  onMessage: options.onMessage,
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }

  GestureDetector _buildCopyableText({
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
        Clipboard.setData(ClipboardData(text: value));
        if (onMessage != null) {
          onMessage('Kopiert til utklippstavlen');
        }
      },
    );
  }
}

class _PointPainter extends CustomPainter {
  final double size;
  final Color color;
  final double opacity;

  const _PointPainter({
    this.size,
    this.color,
    this.opacity = 0.6,
  });

  @override
  void paint(Canvas canvas, _) {
    final paint = Paint()..color = Colors.white;
    final radius = size / 2.0;
    final offset = size / 2.0;
    final center = Offset(offset, offset - 1);
    canvas.drawCircle(center, radius, paint);

    var path = Path();
    path.addOval(Rect.fromCircle(center: center.translate(0, 0), radius: radius + 1));
    canvas.drawShadow(path, Colors.black45, 2, true);

    paint.color = color;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, paint);
    canvas.drawCircle(center, 1, paint..color = Colors.black);
  }

  @override
  bool shouldRepaint(_PointPainter oldPainter) {
    return oldPainter.size != size || oldPainter.opacity != opacity;
  }
}

class _LabelPainter extends CustomPainter {
  final String label;

  const _LabelPainter(this.label);

  @override
  void paint(Canvas canvas, _) {
    final paint = Paint()..color = Colors.white;

    var builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 12.0, textAlign: TextAlign.left))
      ..pushStyle(ui.TextStyle(color: Colors.black))
      ..addText(label);
    var p = builder.build()..layout(ui.ParagraphConstraints(width: 48));
    var height = p.height;
    var width = p.maxIntrinsicWidth;
    var rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 22),
        width: width + 4,
        height: height + 4,
      ),
      Radius.circular(4),
    );
    var path = Path()..addRRect(rect);
    canvas.drawShadow(path, Colors.black45, 2, true);
    canvas.drawRRect(rect, paint);
    canvas.drawParagraph(p, Offset(-width / 2, height + 1));
  }

  @override
  bool shouldRepaint(_LabelPainter oldPainter) {
    return true;
  }
}
