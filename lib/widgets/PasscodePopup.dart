import 'package:SarSys/models/Incident.dart';
import 'package:flutter/material.dart';

class PasscodeRoute extends PopupRoute {
  final Incident incident;

  PasscodeRoute(this.incident);

  @override
  bool get barrierDismissible => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Center(
      child: Material(
        child: DecoratedBox(
          child: Text("Test1"),
          decoration: BoxDecoration(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Color get barrierColor => Colors.black.withOpacity(0.6);

  @override
  String get barrierLabel => "Tap to cancel passcode popup";

  @override
  Duration get transitionDuration => Duration(microseconds: 300);
}
