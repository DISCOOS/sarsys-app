// @dart=2.11

import 'dart:async';

import 'package:chopper/chopper.dart';

import 'package:SarSys/core/data/models/message_model.dart';
import 'package:SarSys/core/data/services/message_channel.dart';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/core/utils/data.dart';
import 'package:SarSys/features/affiliation/data/models/division_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Division.dart';
import 'package:SarSys/core/data/services/service.dart';

part 'division_service.chopper.dart';

/// Service for consuming the organisations endpoint
///
/// Delegates to a ChopperService implementation
class DivisionService extends StatefulServiceDelegate<Division, DivisionModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetList, StatefulGetFromId {
  DivisionService(
    this.channel,
  ) : delegate = DivisionServiceImpl.newInstance() {
    // Listen for Division messages
    DivisionMessageType.values.forEach(
      (type) => channel.subscribe(enumName(type), _onMessage),
    );
  }

  final MessageChannel channel;
  final DivisionServiceImpl delegate;

  /// Get stream of device messages
  Stream<DivisionMessage> get messages => _controller.stream;
  final StreamController<DivisionMessage> _controller = StreamController.broadcast();

  void publish(DivisionMessage message) {
    _controller.add(message);
  }

  void _onMessage(Map<String, dynamic> data) {
    publish(
      DivisionMessage(data),
    );
  }

  void dispose() {
    _controller.close();
    DivisionMessageType.values.forEach(
      (type) => channel.unsubscribe(enumName(type), _onMessage),
    );
  }
}

enum DivisionMessageType {
  DivisionCreated,
  DivisionInformationUpdated,
  DivisionDeleted,
}

class DivisionMessage extends MessageModel {
  DivisionMessage(Map<String, dynamic> data) : super(data);

  DivisionMessageType get type {
    final type = data.elementAt('type');
    return DivisionMessageType.values.singleWhere((e) => enumName(e) == type, orElse: () => null);
  }
}

@ChopperApi()
abstract class DivisionServiceImpl extends StatefulService<Division, DivisionModel> {
  DivisionServiceImpl()
      : super(
          decoder: (json) => DivisionModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<DivisionModel>(value, remove: const [
            'organisation',
          ]),
        );

  static DivisionServiceImpl newInstance([ChopperClient client]) => _$DivisionServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Division> state) => create(
        state.value.organisation.uuid,
        state.value,
      );

  @Post(path: '/organisations/{uuid}/divisions')
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Division body,
  );

  @override
  Future<Response<StorageState<Division>>> onUpdate(StorageState<Division> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '/divisions/{uuid}')
  Future<Response<StorageState<Division>>> update(
    @Path('uuid') String uuid,
    @Body() Division body,
  );

  @override
  Future<Response<StorageState<Division>>> onDelete(StorageState<Division> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '/divisions/{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  @override
  Future<Response<PagedList<StorageState<Division>>>> onGetPage(int offset, int limit, List<String> options) => getAll(
        offset,
        limit,
      );

  @Get(path: '/divisions')
  Future<Response<PagedList<StorageState<Division>>>> getAll(
    @Query('offset') int offset,
    @Query('limit') int limit,
  );
}
