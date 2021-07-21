// @dart=2.11

import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';

@immutable
abstract class MessageModel {
  @mustCallSuper
  MessageModel(this.data);

  /// Get raw message data object
  final Map<String, dynamic> data;

  /// Message is sent a-priori of actual
  bool get isApriori => version.isNone;

  /// Get aggregate [uuid]
  String get uuid => data.elementAt('data/uuid');

  /// Check if message contains actual state
  bool get isState => data.hasPath('data/changed');

  /// Check if message contains patches to applied to current state
  bool get isPatches => data.hasPath('data/patches');

  /// Get state version
  StateVersion get version => StateVersion.fromJson(data);

  /// Get next state to apply
  Map<String, dynamic> get state => data.mapAt<String, dynamic>('data/changed');

  /// Get next patches to apply
  List<Map<String, dynamic>> get patches => data.listAt<Map<String, dynamic>>('data/patches');
}
