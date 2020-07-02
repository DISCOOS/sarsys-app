import 'dart:collection';
import 'dart:convert';
import 'dart:async' show Future;

import 'package:flutter/services.dart' show rootBundle;

import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/features/affiliation/domain/entities/FleetMap.dart';
import 'package:SarSys/features/affiliation/domain/entities/OperationalFunction.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroupCatalog.dart';
import 'package:SarSys/features/affiliation/domain/entities/TalkGroup.dart';

class FleetMapService {
  static const ASSET = "assets/config/fleet_map.json";

  static final _singleton = FleetMapService._internal();

  final Map<String, FleetMap> _fleetMaps = LinkedHashMap();

  Map<String, dynamic> _assets = {};

  factory FleetMapService() {
    return _singleton;
  }

  FleetMapService._internal() {
    init();
  }

  Future<void> init() async {
    if (_assets.isEmpty) {
      _assets = json.decode(await rootBundle.loadString(ASSET));
    }
  }

  Future<FleetMap> _loadOrg(String prefix) async {
    await init();
    final org = (_assets["organisations"] as List).firstWhere(
      (org) => (org as Map<String, dynamic>).elementAt('prefix') == prefix,
      orElse: () => null,
    );
    if (org != null) {
      _fleetMaps.putIfAbsent(
        prefix,
        () => FleetMap.fromJson(org),
      );
    }
    return _fleetMaps[prefix];
  }

  Future<FleetMap> fetchFleetMap(String prefix) async {
    final map = _fleetMaps;
    if (!map.containsKey(prefix)) {
      await _loadOrg(prefix);
    }
    return _fleetMaps[prefix];
  }

  Future<List<TalkGroup>> fetchTalkGroups(String prefix, String catalog) async {
    if (!_fleetMaps.containsKey(prefix)) {
      await _loadOrg(prefix);
    }
    final org = _fleetMaps[prefix];
    return org?.catalogs
        ?.where(
          (test) => test.name == catalog,
        )
        ?.firstOrNull
        ?.groups;
  }

  Future<List<TalkGroupCatalog>> fetchTalkGroupCatalogs(String prefix) async {
    if (!_fleetMaps.containsKey(prefix)) {
      await _loadOrg(prefix);
    }
    final org = _fleetMaps[prefix];
    return org?.catalogs?.toList();
  }

  Future<List<OperationalFunction>> fetchFunctions(String prefix) async {
    if (!_fleetMaps.containsKey(prefix)) {
      await _loadOrg(prefix);
    }
    final org = _fleetMaps[prefix];
    return org?.functions?.toList();
  }
}
