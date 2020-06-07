import 'dart:io';
import 'dart:convert';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/map/models/map_widget_state_model.dart';
import 'package:SarSys/features/device/presentation/pages/devices_page.dart';
import 'package:SarSys/features/unit/presentation/pages/units_page.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/widgets.dart';

const String PAGE_STORAGE_BUCKET_FILE_PATH = "page_storage_bucket.json";

T getPageState<T>(BuildContext context, String identifier, {T defaultValue}) {
  var value;
  final bucket = PageStorage.of(context);
  if (bucket != null) {
    value = bucket.readState(context, identifier: identifier);
  }
  return value ?? defaultValue;
}

T putPageState<T>(BuildContext context, String identifier, T value, {bool write = true}) {
  final bucket = PageStorage.of(context);
  if (bucket != null) {
    bucket.writeState(context, value, identifier: identifier);
    if (write) {
      writePageStorageBucket(bucket);
    }
  }
  return value;
}

Future<PageStorageBucket> readPageStorageBucket(PageStorageBucket bucket, {BuildContext context}) async {
  final json = readFromFile(await getApplicationDocumentsDirectory(), PAGE_STORAGE_BUCKET_FILE_PATH);
  if (json != null) {
    bucket.writeState(context, json[RouteWriter.STATE], identifier: RouteWriter.STATE);
    bucket.writeState(context, json[UnitsPageState.STATE], identifier: UnitsPageState.STATE);
    bucket.writeState(context, json[DevicesPageState.STATE], identifier: DevicesPageState.STATE);
    _writeTypedState(
      context,
      bucket,
      MapWidgetState.STATE,
      json,
      (state) => MapWidgetStateModel.fromJson(state),
      defaultValue: () => MapWidgetStateModel(),
    );
  } else {
    bucket.writeState(context, null, identifier: RouteWriter.STATE);
    bucket.writeState(context, null, identifier: UnitsPageState.STATE);
    bucket.writeState(context, null, identifier: DevicesPageState.STATE);
    bucket.writeState(context, null, identifier: MapWidgetState.STATE);
  }
  return bucket;
}

void _writeTypedState<T>(
  BuildContext context,
  PageStorageBucket bucket,
  Object identifier,
  Map<String, dynamic> state,
  T fromJson(dynamic state), {
  T defaultValue(),
}) {
  final typed = state?.containsKey(identifier) == true && state[identifier] != null
      ? fromJson(state[identifier])
      : defaultValue();
  bucket.writeState(context, typed, identifier: identifier);
}

Map<String, dynamic> readFromFile(Directory dir, String fileName) {
  var values;
  File file = File(dir.path + "/" + fileName);
  if (file.existsSync()) {
    values = json.decode(file.readAsStringSync());
  }
  return values;
}

Future writePageStorageBucket(PageStorageBucket bucket, {BuildContext context}) async {
  final json = {
    RouteWriter.STATE: bucket.readState(context, identifier: RouteWriter.STATE),
    UnitsPageState.STATE: bucket.readState(context, identifier: UnitsPageState.STATE),
    DevicesPageState.STATE: bucket.readState(context, identifier: DevicesPageState.STATE),
    MapWidgetState.STATE: _readTypedState<MapWidgetStateModel>(context, bucket, MapWidgetState.STATE)?.toJson(),
  };
  writeToFile(json, await getApplicationDocumentsDirectory(), PAGE_STORAGE_BUCKET_FILE_PATH);
}

T _readTypedState<T>(BuildContext context, PageStorageBucket bucket, Object identifier, {T defaultValue}) {
  return (bucket.readState(context, identifier: identifier) ?? defaultValue) as T;
}

void writeToFile(Map<String, dynamic> content, Directory dir, String fileName) {
  File file = File(dir.path + "/" + fileName);
  if (!file.existsSync()) {
    file.createSync();
  }
  file.writeAsStringSync(json.encode(content));
}

void deleteFile(Directory dir, String fileName) {
  File file = File(dir.path + "/" + fileName);
  if (file.existsSync()) {
    file.deleteSync();
  }
}

Future clearPageStates() async {
  deleteFile(await getApplicationDocumentsDirectory(), PAGE_STORAGE_BUCKET_FILE_PATH);
  return Future.value();
}
