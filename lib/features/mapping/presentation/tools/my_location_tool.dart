

import 'package:SarSys/features/mapping/presentation/tools/map_tools.dart';
import 'package:SarSys/features/mapping/domain/entities/Point.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:SarSys/features/mapping/data/services/location_service.dart';
import 'package:SarSys/features/user/presentation/screens/user_screen.dart';


class MyLocation {
  final Point? point;

  MyLocation(
      this.point,
      );
}

class MyLocationTool extends MapTool with MapSelectable<MyLocation> {

  @override
  bool active() => true;

  @override
  Iterable<MyLocation> get targets => [MyLocation(LocationService().current?.geometry)];

  @override
  void doProcessTap(BuildContext context, List<MyLocation> items) {
    Navigator.pushReplacementNamed(context, UserScreen.ROUTE_PROFILE);
  }

  @override
  LatLng toPoint(MyLocation me) {
    return toLatLng(me.point);
  }
}