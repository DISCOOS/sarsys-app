import 'dart:async';
import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/features/affiliation/domain/entities/Person.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:chopper/chopper.dart';

part 'person_service.chopper.dart';

/// Service for consuming the persons endpoint
///
/// Delegates to a ChopperService implementation
class PersonService with ServiceGet<Person> implements ServiceDelegate<PersonServiceImpl> {
  final PersonServiceImpl delegate;

  PersonService() : delegate = PersonServiceImpl.newInstance();

  Future<ServiceResponse<Person>> get(String uuid) async {
    return Api.from<Person, Person>(
      await delegate.get(uuid: uuid),
    );
  }

  Future<ServiceResponse<Person>> create(Person person) async {
    return Api.from<String, Person>(
      await delegate.create(
        person,
      ),
      // Created 201 returns uri to created person in body
      body: person,
    );
  }

  Future<ServiceResponse<Person>> update(Person person) async {
    return Api.from<Person, Person>(
      await delegate.update(
        person.uuid,
        person,
      ),
      // Created 201 returns uri to created person in body
      body: person,
    );
  }

  Future<ServiceResponse<void>> delete(String uuid) async {
    return Api.from<Person, void>(await delegate.delete(
      uuid,
    ));
  }
}

@ChopperApi(baseUrl: '/persons')
abstract class PersonServiceImpl extends ChopperService {
  static PersonServiceImpl newInstance([ChopperClient client]) => _$PersonServiceImpl(client);

  @Post()
  Future<Response<String>> create(
    @Body() Person body,
  );

  @Get(path: '{uuid}')
  Future<Response<Person>> get({
    @Path('uuid') String uuid,
  });

  @Patch(path: '{uuid}')
  Future<Response<Person>> update(
    @Path('uuid') String uuid,
    @Body() Person body,
  );

  @Delete(path: '{uuid}')
  Future<Response<void>> delete(
    @Path('uuid') String uuid,
  );
}