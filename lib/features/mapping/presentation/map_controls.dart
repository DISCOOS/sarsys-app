

import 'dart:math';

import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';

class MapControls extends StatefulWidget {
  final double top;
  final List<MapControl>? _controls;
  final MapToolController? _controller;

  MapControls({
    Key? key,
    List<MapControl>? controls,
    MapToolController? controller,
    this.top = 100.0,
  })  : this._controls = controls,
        this._controller = controller,
        super(key: key);

  @override
  _MapControlsState createState() => _MapControlsState();
}

class _MapControlsState extends State<MapControls> {
  static const FAB = 56.0;
  static const SIZE = 42.0;
  static const SPACING = 4.0;
  static const PADDING = 32.0;

  final Size _size = const Size(SIZE, SIZE);

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    widget._controls!
        .where((control) => control.listenable != null)
        .forEach((control) => control.listenable!.addListener(_onChange));
  }

  @override
  void didUpdateWidget(MapControls old) {
    super.didUpdateWidget(old);
    if (old._controls != widget._controls) {
      _dispose();
      _init();
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    return widget._controls!.forEach((control) {
      control.listenable?.removeListener(_onChange);
      control.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final active = widget._controller?.tools.firstWhereOrNull(
          (tool) => tool.active(),
        ) !=
        null;
    final count = ((height - (active ? PADDING : PADDING + FAB)) / (SIZE + SPACING)).floor();

    final visible = widget._controls!
        .expand((control) => [control, if (control.state!.toggled && control.children.isNotEmpty) ...control.children])
        .toList(growable: false);

    final vertical = _buildList(context, visible, count, false);
    final horizontal = _buildList(context, visible, count, true);
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final top = landscape ? 8.0 : widget.top;
    final right = landscape ? 16.0 : 8.0;
    return Positioned(
      top: top,
      right: right,
      child: SafeArea(
        child: SizedBox(
          height: height - (top + PADDING),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ...vertical,
              Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [...horizontal, SizedBox(width: PADDING + FAB)],
              )
            ],
          ),
        ),
      ),
    );
  }

  List<SizedBox> _buildList(BuildContext context, List<MapControl> controls, int count, bool reversed) {
    return (reversed
            ? controls.skip(min(count, controls.length)).toList().reversed
            : controls.take(min(count, controls.length)))
        .expand((control) => [
              if (reversed && control != controls.last || control.children != null) SizedBox(width: SPACING),
              SizedBox(
                width: _size.width,
                height: _size.height,
                child: _buildControl(context, control),
              ),
              if (!reversed && control != controls.last || control.children != null) SizedBox(height: SPACING),
            ])
        .toList(growable: false);
  }

  Widget _buildControl(BuildContext context, MapControl control) {
    return control.listenable == null
        ? _buildPressable(control, control.state)
        : ValueListenableBuilder(
            valueListenable: control.listenable!,
            builder: (BuildContext context, MapControlState state, Widget? child) {
              return _buildPressable(control, state);
            },
          );
  }

  Widget _buildPressable(MapControl control, MapControlState? state) {
    return control.onLongPress == null
        ? _buildWithState(control, state!)
        : GestureDetector(
            child: _buildWithState(control, state!),
            onLongPress: control.onLongPress,
          );
  }

  Widget _buildWithState(MapControl control, MapControlState state) {
    return state.locked
        ? Stack(
            children: <Widget>[
              _buildButton(control, state),
              Positioned(
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(0),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Icon(Icons.lock, size: 16, color: Colors.blue),
                ),
              )
            ],
          )
        : _buildButton(control, state);
  }

  Widget _buildButton(MapControl control, MapControlState state) {
    return Container(
      child: IconButton(
        icon: Icon(
          control.icon,
          color: state.toggled ? Colors.blue : Colors.black,
        ),
        onPressed: control.onPressed,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(30.0),
      ),
    );
  }

  void _onChange() {
    if (mounted) setState(() {});
  }
}

class MapControl {
  final IconData icon;
  MapControlState? _state;
  final VoidCallback? onPressed;
  final GestureLongPressCallback? onLongPress;
  final ValueNotifier<MapControlState>? listenable;
  final List<MapControl> children;

  MapControlState? get state => _state;

  MapControl({
    required this.icon,
    this.listenable,
    this.onPressed,
    this.onLongPress,
    MapControlState? state,
    this.children = const [],
  }) {
    _state = state ?? const MapControlState();
    if (listenable != null) {
      listenable!.addListener(_onChange);
    }
  }

  void _onChange() {
    _state = listenable!.value;
  }

  void dispose() {
    listenable?.removeListener(_onChange);
    if (children.isNotEmpty) {
      children.forEach((control) => control.dispose());
    }
  }
}

class MapControlState {
  final bool locked;
  final bool toggled;

  const MapControlState({
    this.locked = false,
    this.toggled = false,
  });
}
