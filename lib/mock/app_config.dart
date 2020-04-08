import 'dart:convert';

import 'package:SarSys/models/AppConfig.dart';
import 'package:SarSys/services/app_config_service.dart';
import 'package:SarSys/services/service_response.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel, rootBundle;
import 'package:uuid/uuid.dart';

class AppConfigServiceMock extends Mock implements AppConfigService {
  static AppConfigService build(String asset, String baseUrl, Client client) {
    final AppConfigServiceMock mock = AppConfigServiceMock();
    Box box;
    AppConfig config;
    when(mock.asset).thenAnswer((_) => asset);
    when(mock.baseUrl).thenAnswer((_) => baseUrl);
    when(mock.client).thenAnswer((_) => client);
    when(mock.init()).thenAnswer((_) async {
      // Required since provider need access to service bindings prior to calling 'runApp()'
      WidgetsFlutterBinding.ensureInitialized();
      // All services are caching using hive
      await Hive.initFlutter();
      config = await _init(asset, box, overwrite: true);
      box ??= await Hive.openBox(AppConfigService.BOX_NAME);
      return ServiceResponse.ok(
        body: config = config,
      );
    });
    when(mock.load()).thenAnswer((_) async {
      box ??= await Hive.openBox(AppConfigService.BOX_NAME);
      return ServiceResponse.ok(
        body: config = await _init(asset, box),
      );
    });
    when(mock.update(any)).thenAnswer((c) async {
      config = c.positionalArguments[0];
      box ??= await Hive.openBox(AppConfigService.BOX_NAME);
      await box.put(AppConfigService.KEY_JSON, jsonEncode(config.toJson()));
      return ServiceResponse.ok(
        body: config = config,
      );
    });
    return mock;
  }

  static Future<AppConfig> _init(String asset, Box box, {bool overwrite = false}) async {
    Map<String, dynamic> defaults;
    var config = box.get(AppConfigService.KEY_JSON);
    if (config == null || overwrite) {
      defaults = json.decode(await rootBundle.loadString(asset));
      await box.put(AppConfigService.KEY_VERSION, AppConfigService.VERSION);
      if (config == null) {
        final uuid = Uuid().v4();
        final udid = await FlutterUdid.udid;
        defaults['uuid'] = uuid;
        defaults['udid'] = udid;
      } else {
        defaults = jsonDecode(config)..addAll(defaults);
      }
      config = jsonEncode(defaults);
      await box.put(AppConfigService.KEY_JSON, config);
    }
    return AppConfig.fromJson(
      jsonDecode(config),
    );
  }
}
