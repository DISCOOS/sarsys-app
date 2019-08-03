import 'package:SarSys/models/Point.dart';
import 'package:SarSys/utils/data_utils.dart';
import 'package:flutter/material.dart';

void jumpToPoint(BuildContext context, Point location) {
  if (location != null) {
    Navigator.pushReplacementNamed(context, "map", arguments: toLatLng(location));
  }
}
