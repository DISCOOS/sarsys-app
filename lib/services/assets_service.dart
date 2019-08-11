import 'dart:collection';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:SarSys/models/Division.dart';
import 'package:SarSys/models/Organization.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:SarSys/models/TalkGroup.dart';

class AssetsService {
  static const FLEET_MAP = "assets/config/fleet_map.json";

  static final _singleton = AssetsService._internal();

  final Map<String, Organization> _organizations = LinkedHashMap();

  Map<String, dynamic> _assets = {};

  factory AssetsService() {
    return _singleton;
  }

  AssetsService._internal() {
    init();
  }

  Future<void> init() async {
    if (_assets.isEmpty) {
      _assets = json.decode(await rootBundle.loadString(FLEET_MAP));
    }
  }

  Future _loadOrg(String orgId) async {
    await init();
    _organizations.putIfAbsent(orgId, () => Organization.fromJson(_assets["organizations"][orgId]));
  }

  Future<List<TalkGroup>> fetchTalkGroups(String orgId, String catalog) async {
    if (!_organizations.containsKey(orgId)) {
      await _loadOrg(orgId);
    }
    return _organizations[orgId]
        .talkGroups[catalog]
        .map((name) => TalkGroup(name: name, type: TalkGroupType.Tetra))
        .toList(growable: false);
  }

  Future<List<String>> fetchTalkGroupCatalogs(String orgId) async {
    if (!_organizations.containsKey(orgId)) {
      await _loadOrg(orgId);
    }
    return _organizations[orgId].talkGroups.keys.toList(growable: false).toList(growable: false);
  }

  Future<Map<String, Division>> fetchDivisions(String orgId) async {
    if (!_organizations.containsKey(orgId)) {
      await _loadOrg(orgId);
    }
    return _organizations[orgId].divisions;
  }

  Future<Map<String, String>> fetchAllDepartments(String orgId) async {
    if (!_organizations.containsKey(orgId)) {
      await _loadOrg(orgId);
    }
    final Map<String, String> departments = {};
    _organizations[orgId].divisions.values.forEach(
          (division) => departments.addAll(division.departments),
        );
    return departments;
  }

  Future<Map<String, String>> fetchFunctions(String orgId) async {
    if (!_organizations.containsKey(orgId)) {
      await _loadOrg(orgId);
    }
    return _organizations[orgId].functions;
  }
}
