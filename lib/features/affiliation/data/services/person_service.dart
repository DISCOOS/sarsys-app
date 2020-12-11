import 'dart:async';
import 'package:SarSys/core/data/services/stateful_service.dart';
import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/models/core.dart';
import 'package:SarSys/features/affiliation/data/models/person_model.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:chopper/chopper.dart';

part 'person_service.chopper.dart';

/// Service for consuming the persons endpoint
///
/// Delegates to a ChopperService implementation
class PersonService extends StatefulServiceDelegate<Person, PersonModel>
    with StatefulCreate, StatefulUpdate, StatefulDelete, StatefulGetFromId {
  PersonService() : delegate = PersonServiceImpl.newInstance();
  final PersonServiceImpl delegate;
}

@ChopperApi(baseUrl: '/persons')
abstract class PersonServiceImpl extends StatefulService<Person, PersonModel> {
  PersonServiceImpl()
      : super(
          decoder: (json) => PersonModel.fromJson(json),
          reducer: (value) => JsonUtils.toJson<PersonModel>(value),
        );

  static PersonServiceImpl newInstance([ChopperClient client]) => _$PersonServiceImpl(client);

  @override
  Future<Response<String>> onCreate(StorageState<Person> state) => create(
        state.value.uuid,
        state.value,
      );

  @Post()
  Future<Response<String>> create(
    @Path() String uuid,
    @Body() Person body,
  );

  @override
  Future<Response<StorageState<Person>>> onUpdate(StorageState<Person> state) => update(
        state.value.uuid,
        state.value,
      );

  @Patch(path: '{uuid}')
  Future<Response<StorageState<Person>>> update(
    @Path('uuid') String uuid,
    @Body() Person body,
  );

  @override
  Future<Response<StorageState<Person>>> onDelete(StorageState<Person> state) => delete(
        state.value.uuid,
      );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );

  Future<Response<StorageState<Person>>> onGetFromId(String id, {List<String> options = const []}) => get(id);

  @Get(path: '{uuid}')
  Future<Response<StorageState<Person>>> get(
    @Path('uuid') String uuid,
  );
}
