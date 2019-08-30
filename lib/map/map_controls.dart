import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  final List<MapControl> controls;

  final Size _size = const Size(42.0, 42.0);

  const MapControls({Key key, this.controls}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: controls
          .expand((control) => [
                SizedBox(
                  width: _size.width,
                  height: _size.height,
                  child: _buildControl(context, control),
                ),
                if (control != controls.last || control.child != null) SizedBox(height: 4.0),
                if (control.child != null)
                  control.listenable == null
                      ? control.child
                      : ValueListenableBuilder(
                          valueListenable: control.listenable,
                          builder: (BuildContext context, MapControlState state, Widget child) {
                            return state.isToggled ? control.child : Container();
                          },
                        )
              ])
          .toList(growable: false),
    );
  }

  Widget _buildControl(BuildContext context, MapControl control) {
    return control.listenable == null
        ? _buildPressable(control, control.state)
        : ValueListenableBuilder(
            valueListenable: control.listenable,
            builder: (BuildContext context, MapControlState state, Widget child) {
              return _buildPressable(control, state);
            },
          );
  }

  Widget _buildPressable(MapControl control, MapControlState state) {
    return control.onLongPress == null
        ? _buildWithState(control, state)
        : GestureDetector(
            child: _buildWithState(control, state),
            onLongPress: control.onLongPress,
          );
  }

  Widget _buildWithState(MapControl control, MapControlState state) {
    return state.isLocked
        ? Stack(
            children: <Widget>[
              _buildButton(control, state),
              Positioned(
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Icon(Icons.lock, size: 16, color: Colors.green),
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
          color: state.isToggled ? Colors.green : Colors.black,
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
}

class MapControl {
  final IconData icon;
  final MapControlState state;
  final VoidCallback onPressed;
  final GestureLongPressCallback onLongPress;
  final ValueNotifier<MapControlState> listenable;
  final MapControls child;

  MapControl({
    @required this.icon,
    this.listenable,
    this.onPressed,
    this.onLongPress,
    this.state = const MapControlState(),
    this.child,
  });
}

class MapControlState {
  final bool isLocked;
  final bool isToggled;

  const MapControlState({
    this.isLocked = false,
    this.isToggled = false,
  });
}
