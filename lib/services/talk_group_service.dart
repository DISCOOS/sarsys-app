import 'dart:collection';
import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;

import 'package:SarSys/models/TalkGroup.dart';

class TalkGroupService {
  static const TALKGROUP = "assets/config/talk_groups.json";

  static final _singleton = TalkGroupService._internal();

  final Map<String, List<TalkGroup>> _talkGroups = LinkedHashMap();

  factory TalkGroupService() {
    return _singleton;
  }

  TalkGroupService._internal() {
    init();
  }

  Future<void> init() async {
    _talkGroups.clear();
    final Map<String, dynamic> assets = json.decode(await rootBundle.loadString(TALKGROUP));
    assets.forEach((catalog, groups) {
      final List<TalkGroup> items = [];
      (groups as List).forEach((name) {
        items.add(TalkGroup(name: name as String, type: TalkGroupType.Tetra));
      });
      _talkGroups.putIfAbsent(catalog, () => items);
    });
  }

  Future<List<TalkGroup>> fetchTalkGroups(String catalog) async {
    if (_talkGroups.isEmpty) {
      await init();
    }
    return _talkGroups[catalog];
  }

  Future<List<String>> fetchCatalogs() async {
    if (_talkGroups.isEmpty) {
      await init();
    }
    return _talkGroups.keys.toList();
  }
}
