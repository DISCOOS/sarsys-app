import 'dart:async' show Future;

import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/settings/data/models/app_config_model.dart';
import 'package:chopper/chopper.dart';

import 'package:SarSys/features/settings/domain/entities/AppConfig.dart';

part 'app_config_service.chopper.dart';

/// Service for consuming the app-config endpoint
///
/// Delegates to a ChopperService implementation
class AppConfigService extends StatefulServiceDelegate<AppConfig, AppConfigModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetFromId {
  final AppConfigServiceImpl delegate;

  AppConfigService() : delegate = AppConfigServiceImpl.newInstance();
}

@ChopperApi(baseUrl: '/app-configs')
abstract class AppConfigServiceImpl extends StatefulService<AppConfig, AppConfigModel> {
  AppConfigServiceImpl()
      : super(
          decoder: (json) => AppConfigModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<AppConfigModel>(value),
        );
  static AppConfigServiceImpl newInstance([ChopperClient client]) => _$AppConfigServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<AppConfig> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() AppConfig body,
  );

  @override
  Future<Response<StorageState<AppConfig>>> onUpdate(StorageState<AppConfig> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<AppConfig>>> update(
    @Path('uuid') String uuid,
    @Body() AppConfig body,
  );

  @override
  Future<Response<StorageState<AppConfig>>> onDelete(StorageState<AppConfig> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<StorageState<AppConfig>>> onGetFromId(
    String id, {
    List<String> options = const [],
  }) =>
      get(id);

  @Get(path: '{uuid}')
  Future<Response<StorageState<AppConfig>>> get(@Path('uuid') uuid);
}
