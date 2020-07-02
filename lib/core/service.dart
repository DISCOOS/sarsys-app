import 'package:SarSys/models/core.dart';
import 'package:SarSys/services/service.dart';

abstract class Service {}

abstract class ServiceDelegate<S> implements Service {
  S get delegate;
}

mixin ServiceFetchAll<T extends Aggregate> {
  Future<ServiceResponse<List<T>>> fetchAll({int offset = 0, int limit = 20}) async {
    final body = <T>[];
    var response = await fetch(offset, limit);
    while (response.is200) {
      body.addAll(response.body);
      if (response.page.hasNext) {
        response = await fetch(
          response.page.next,
          response.page.limit,
        );
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
  }

  /// GET /divisions
  Future<ServiceResponse<List<T>>> fetch(int offset, int limit) {
    throw UnimplementedError("fetch not implemented");
  }
}

mixin ServiceFetchDescendants<T extends Aggregate> {
  Future<ServiceResponse<List<T>>> fetchAll(
    String uuid, {
    int offset = 0,
    int limit = 20,
  }) async {
    final divisions = <T>[];
    var response = await fetch(uuid, offset, limit);
    while (response.is200) {
      divisions.addAll(response.body);
      if (response.page.hasNext) {
        response = await fetch(
          uuid,
          response.page.next,
          response.page.limit,
        );
      } else {
        return ServiceResponse.ok(body: divisions);
      }
    }
    return response;
  }

  /// GET /divisions
  Future<ServiceResponse<List<T>>> fetch(String uuid, int offset, int limit) {
    throw UnimplementedError("fetch not implemented");
  }
}
