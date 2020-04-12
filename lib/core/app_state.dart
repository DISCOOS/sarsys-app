import 'dart:io';
import 'dart:convert';
import 'package:SarSys/blocs/app_config_bloc.dart';
import 'package:SarSys/blocs/user_bloc.dart';
import 'package:SarSys/map/map_widget.dart';
import 'package:SarSys/map/models/map_widget_state_model.dart';
import 'package:SarSys/pages/devices_page.dart';
import 'package:SarSys/pages/units_page.dart';
import 'package:SarSys/screens/screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

T readState<T>(BuildContext context, String identifier, {T defaultValue}) =>
    PageStorage.of(context)?.readState(context, identifier: identifier) ?? defaultValue;

T writeState<T>(BuildContext context, String identifier, T value) {
  PageStorage.of(context)?.writeState(context, value, identifier: identifier);
  return value;
}

Future<PageStorageBucket> readAppState(PageStorageBucket bucket, {BuildContext context}) async {
  // TODO: Store app_state using Hive
  final json = readFromFile(await getApplicationDocumentsDirectory(), "app_state.json");
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
  }
  return bucket;
}

_writeTypedState<T>(
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

Future writeAppState(PageStorageBucket bucket, {BuildContext context}) async {
  final json = {
    RouteWriter.STATE: bucket.readState(context, identifier: RouteWriter.STATE),
    UnitsPageState.STATE: bucket.readState(context, identifier: UnitsPageState.STATE),
    DevicesPageState.STATE: bucket.readState(context, identifier: DevicesPageState.STATE),
    MapWidgetState.STATE: _readTypedState<MapWidgetStateModel>(context, bucket, MapWidgetState.STATE)?.toJson(),
  };
  writeToFile(json, await getApplicationDocumentsDirectory(), "app_state.json");
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

Future clearAppStateAndData(BuildContext context) async {
  await BlocProvider.of<AppConfigBloc>(context).init();
  await BlocProvider.of<UserBloc>(context).clear();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  deleteFile(await getApplicationDocumentsDirectory(), "app_state.json");
}
