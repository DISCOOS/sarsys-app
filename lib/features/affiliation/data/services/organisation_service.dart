// @dart=2.11

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/affiliation/data/models/organisation_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Organisation.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'organisation_service.chopper.dart';

/// Service for consuming the organisations endpoint
///
/// Delegates to a ChopperService implementation
class OrganisationService extends StatefulServiceDelegate<Organisation, OrganisationModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList, StatefulGetFromId {
  OrganisationService(
    this.channel,
  ) : delegate = OrganisationServiceImpl.newInstance() {
    // Listen for Organisation messages
    OrganisationMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final OrganisationServiceImpl delegate;

  /// Get stream of device messages
  Stream<OrganisationMessage> get messages => _controller.stream;
  final StreamController<OrganisationMessage> _controller = StreamController.broadcast();

  void publish(OrganisationMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      OrganisationMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    OrganisationMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage),
    );
  }
}

enum OrganisationMessageType {
  OrganisationCreated,
  OrganisationInformationUpdated,
  OrganisationDeleted,
}

class OrganisationMessage extends MessageModel {
  OrganisationMessage(Map<String, dynamic> data) : super(data);

  OrganisationMessageType get type {
    final type = data.elementAt('type');
    return OrganisationMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}

@ChopperApi(baseUrl: '/organisations')
abstract class OrganisationServiceImpl extends StatefulService<Organisation, OrganisationModel> {
  OrganisationServiceImpl()
      : super(
          decoder: (json) => OrganisationModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<OrganisationModel>(value),
        );

  static OrganisationServiceImpl newInstance([ChopperClient client]) => _$OrganisationServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Organisation> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Organisation body,
  );

  @override
  Future<Response<StorageState<Organisation>>> onUpdate(StorageState<Organisation> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Organisation>>> update(
    @Path('uuid') String uuid,
    @Body() Organisation body,
  );

  @override
  Future<Response<StorageState<Organisation>>> onDelete(StorageState<Organisation> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Organisation>>>> onGetPage(int offset, int limit, List<String> options) =>
      getAll(
        offset,
        limit,
      );

  @Get()
  Future<Response<PagedList<StorageState<Organisation>>>> getAll(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
