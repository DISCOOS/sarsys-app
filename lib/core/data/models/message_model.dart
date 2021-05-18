import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';

@immutable
abstract class MessageModel {
  @mustCallSuper
  MessageModel(this.data);

  final Map<String, dynamic> data;

  String get uuid => data.elementAt('data/uuid');
  bool get isState => data.hasPath('data/changed');
  bool get isPatches => data.hasPath('data/patches');
  StateVersion get version => StateVersion.fromJson(data);

  Map<String, dynamic> get state => data.mapAt<String, dynamic>('data/changed');
  List<Map<String, dynamic>> get patches => data.listAt<Map<String, dynamic>>('data/patches');
}
