import 'dart:async' show Future;

import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

part 'app_config_service.chopper.dart';

/// Service for consuming the app-config endpoint
///
/// Delegates to a ChopperService implementation
class AppConfigService implements ServiceDelegate<AppConfigServiceImpl> {
  final AppConfigServiceImpl delegate;

  AppConfigService() : delegate = AppConfigServiceImpl.newInstance();

  /// Initializes configuration to default values for given version.
  ///
  /// POST ../app-config
  Future<ServiceResponse<AppConfig>> create(AppConfig config) async {
    return Api.from<String, AppConfig>(
      await delegate.create(
        config,
      ),
      // Created 201 returns uri to created config in body
      body: config,
    );
  }

  /// GET ../app-config/{uuid}
  Future<ServiceResponse<AppConfig>> fetch(String uuid) async {
    return Api.from<AppConfig, AppConfig>(await delegate.fetch(
      uuid,
    ));
  }

  /// PATCH ../app-config/{uuid}
  Future<ServiceResponse<AppConfig>> update(AppConfig config) async {
    return Api.from<AppConfig, AppConfig>(
      await delegate.update(
        config.uuid,
        config,
      ),
      body: config,
    );
  }

  /// DELETE ../app-config/{uuid}
  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<AppConfig, AppConfig>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/app-configs')
abstract class AppConfigServiceImpl extends JsonService<AppConfig, AppConfigModel> {
  AppConfigServiceImpl()
      : super(
          decoder: (json) => AppConfigModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<AppConfigModel>(value),
        );
  static AppConfigServiceImpl newInstance([ChopperClient client]) => _$AppConfigServiceImpl(client);

  /// Initializes configuration to default values for given version.
  ///
  /// POST /app-configs/{version}
  @Post()
  Future<Response<String>> create(
    @Body() AppConfig config,
  );

  /// GET /app-configs/{uuid}
  @Get(path: "{uuid}")
  Future<Response<AppConfig>> fetch(
    @Path('uuid') String uuid,
  );

  /// PATCH ../app-configs/{uuid}
  @Patch(path: "{uuid}")
  Future<Response<AppConfig>> update(
    @Path('uuid') String uuid,
    @Body() AppConfig config,
  );

  /// DELETE ../app-configs/{uuid}
  @Delete(path: "{uuid}")
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}
