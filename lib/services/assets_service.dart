import 'dart:collection';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:SarSys/models/Organization.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:SarSys/models/TalkGroup.dart';

class AssetsService {
  static const FLEET_MAP = "assets/config/fleet_map.json";

  static final _singleton = AssetsService._internal();

  final Map<String, List<TalkGroup>> _talkGroups = LinkedHashMap();
  final Map<String, String> _functions = LinkedHashMap();

  Map<String, dynamic> _assets = {};

  factory AssetsService() {
    return _singleton;
  }

  AssetsService._internal() {
    init();
  }

  Future<void> init() async {
    _talkGroups.clear();
    _assets = json.decode(await rootBundle.loadString(FLEET_MAP));
    assert(_assets.containsKey("talk_groups"), "Check fleet_map.json, 'talk_groups' is missing");
    _assets["talk_groups"].forEach((catalog, groups) {
      final List<TalkGroup> items = [];
      (groups as List).forEach((name) {
        items.add(TalkGroup(name: name as String, type: TalkGroupType.Tetra));
      });
      _talkGroups.putIfAbsent(catalog, () => items);
    });
  }

  Future<List<TalkGroup>> fetchTalkGroups(String catalog) async {
    if (_assets.isEmpty) {
      await init();
    }
    return _talkGroups[catalog];
  }

  Future<List<String>> fetchTalkGroupCatalogs() async {
    if (_assets.isEmpty) {
      await init();
    }
    return _talkGroups.keys.toList();
  }

  Future<Map<String, Organization>> fetchOrganizations() async {
    if (_assets.isEmpty) {
      await init();
    }
    return (_assets["organizations"] as Map<String, Map<String, dynamic>>).map(
      (String id, Map<String, dynamic> values) => MapEntry<String, Organization>(
        id,
        Organization(
          id: id,
          name: values["name"] as String,
          alias: values["alias"] as String,
          pattern: id,
        ),
      ),
    );
  }

  Future<Map<String, String>> fetchLevels() async {
    if (_assets.isEmpty) {
      await init();
    }
    return (_assets["levels"] as Map)?.map((id, value) => MapEntry(id as String, value as String));
  }

  Future<Map<String, String>> fetchDistricts() async {
    if (_assets.isEmpty) {
      await init();
    }
    return (_assets["districts"] as Map)?.map((id, value) => MapEntry(id as String, value as String));
  }

  Future<Map<String, String>> fetchDepartments() async {
    if (_assets.isEmpty) {
      await init();
    }
    return (_assets["departments"] as Map)?.map((id, value) => MapEntry(id as String, value as String));
  }

  Future<Map<String, String>> fetchFunctions() async {
    if (_assets.isEmpty) {
      await init();
    }
    return (_assets["functions"] as Map)?.map((id, value) => MapEntry(id as String, value as String));
  }
}
