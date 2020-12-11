import 'package:meta/meta.dart';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';

import 'package:SarSys/core/data/api.dart';
import 'package:SarSys/core/extensions.dart';
import 'package:SarSys/core/data/services/service.dart';
import 'package:SarSys/core/data/storage.dart';

import 'package:SarSys/core/domain/models/core.dart';

abstract class StatefulService<D extends JsonObject, R> extends JsonService<StorageState<D>, R> {
  StatefulService({
    @required JsonReducer reducer,
    @required JsonDecoder<D> decoder,
    bool isPaged = true,
    String dataField = 'data',
    String entriesField = 'entries',
    this.versionField = 'number',
    this.deletedField = 'deleted',
  })  : _decoder = decoder,
        _dataField = dataField,
        super(
          decoder: null,
          reducer: reducer,
          isPaged: isPaged,
          dataField: '.',
          entriesField: entriesField,
        );

  final String _dataField;
  final String versionField;
  final String deletedField;
  final JsonDecoder<D> _decoder;

  @override
  JsonDecoder<StorageState<D>> get decoder => _toStateful;

  StorageState<D> _toStateful(dynamic json) {
    final value = _decoder(
      Map.from(json).elementAt(_dataField),
    );
    final version = StateVersion(
      json[versionField] as int,
    );
    return version.isFirst ? toCreated(value, version) : toUpdated(value, version);
  }

  @visibleForOverriding
  Future<Response<String>> onCreate(StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<String>> onCreateWithId(String id, StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<String>> onCreateWithIds(List<String> ids, StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onUpdate(StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onUpdateWithId(String id, StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onUpdateWithIds(List<String> ids, StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onDelete(StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onDeleteWithId(String id, StorageState<D> state) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onDeleteWithIds(List<String> ids, StorageState<D> state) {
    throw UnimplementedError();
  }

  Future<Response<PagedList<StorageState<D>>>> onSearch(String filter, int offset, int limit, List<String> options) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onGetFromId(String id, {List<String> options = const []}) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<StorageState<D>>> onGetFromIds(List<String> ids, {List<String> options = const []}) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<PagedList<StorageState<D>>>> onGetPage(int offset, int limit, List<String> options) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<PagedList<StorageState<D>>>> onGetPageFromId(String id, int offset, int limit, List<String> options) {
    throw UnimplementedError();
  }

  @visibleForOverriding
  Future<Response<PagedList<StorageState<D>>>> onGetPageFromIds(
      List<String> ids, int offset, int limit, List<String> options) {
    throw UnimplementedError();
  }

  @protected
  StorageState<D> toCreated(D value, StateVersion version) => StorageState.created(
        value,
        version,
        isRemote: true,
      );

  @protected
  StorageState<D> toUpdated(D value, StateVersion version) => StorageState.updated(
        value,
        version,
        isRemote: true,
      );

  @protected
  StorageState<D> toDeleted(D value, StateVersion version) => StorageState.deleted(
        value,
        version,
        isRemote: true,
      );
}

abstract class StatefulServiceDelegate<D extends JsonObject, R> extends Service {
  StatefulService<D, R> get delegate;
}

mixin StatefulCreate<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> create(StorageState<D> state) async {
    final response = await delegate.onCreate(
      state,
    );
    return Api.from<String, StorageState<D>>(
      response,
      // Created 201 returns uri to created affiliation in body
      body: delegate.toCreated(
        state.value,
        StateVersion.first,
      ),
    );
  }
}

mixin StatefulCreateWithId<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> createWithId(String id, StorageState<D> state) async {
    return Api.from<String, StorageState<D>>(
      await delegate.onCreateWithId(
        id,
        state,
      ),
      // Created 201 returns uri to created affiliation in body
      body: delegate.toCreated(
        state.value,
        StateVersion.first,
      ),
    );
  }
}

mixin StatefulCreateWithIds<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> createWithIds(List<String> ids, StorageState<D> state) async {
    return Api.from<String, StorageState<D>>(
      await delegate.onCreateWithIds(
        ids,
        state,
      ),
      // Created 201 returns uri to created affiliation in body
      body: delegate.toCreated(
        state.value,
        StateVersion.first,
      ),
    );
  }
}

mixin StatefulUpdate<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> update(StorageState<D> state) async {
    return Api.from<StorageState<D>, StorageState<D>>(
      await delegate.onUpdate(
        state,
      ),
      // 204 No content
      body: delegate.toUpdated(
        state.value,
        state.version,
      ),
    );
  }
}

mixin StatefulUpdateWithId<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> updateWithId(String id, StorageState<D> state) async {
    return Api.from<StorageState<D>, StorageState<D>>(
      await delegate.onUpdateWithId(
        id,
        state,
      ),
      // 204 No content
      body: delegate.toUpdated(
        state.value,
        state.version,
      ),
    );
  }
}
mixin StatefulUpdateWithIds<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> updateWithIds(List<String> ids, StorageState<D> state) async {
    return Api.from<StorageState<D>, StorageState<D>>(
      await delegate.onUpdateWithIds(
        ids,
        state,
      ),
      // 204 No content
      body: delegate.toUpdated(
        state.value,
        state.version,
      ),
    );
  }
}

mixin StatefulDelete<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> delete(StorageState<D> state) async {
    return Api.from<void, StorageState<D>>(
      await delegate.onDelete(
        state,
      ),
      // 204 No content
      body: delegate.toDeleted(
        state.value,
        state.version,
      ),
    );
  }
}

mixin StatefulDeleteWithId<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> deleteWithId(String id, StorageState<D> state) async {
    return Api.from<void, StorageState<D>>(
      await delegate.onDeleteWithId(
        id,
        state,
      ),
      // 204 No content
      body: delegate.toDeleted(
        state.value,
        state.version,
      ),
    );
  }
}

mixin StatefulDeleteWithIds<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> deleteWithIds(List<String> ids, StorageState<D> state) async {
    return Api.from<void, StorageState<D>>(
      await delegate.onDeleteWithIds(
        ids,
        state,
      ),
      // 204 No content
      body: delegate.toDeleted(
        state.value,
        state.version,
      ),
    );
  }
}

mixin StatefulSearch<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<List<StorageState<D>>>> search(
    String filter, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    return Api.from<PagedList<StorageState<D>>, List<StorageState<D>>>(
      await delegate.onSearch(
        filter,
        offset,
        limit,
        options,
      ),
    );
  }
}

mixin StatefulGetFromId<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> getFromId(String id, {List<String> options = const []}) async {
    return Api.from<StorageState<D>, StorageState<D>>(
      await delegate.onGetFromId(id, options: options),
    );
  }
}

mixin StatefulGetList<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<List<StorageState<D>>>> getList({
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final body = <StorageState<D>>[];
    var response = await getPage(
      offset,
      limit,
      options,
    );
    while (response.is200) {
      body.addAll(response.body);
      if (response.page.hasNext) {
        response = await getPage(
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: body);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<StorageState<D>>>> getPage(int offset, int limit, List<String> options) async {
    return Api.from<PagedList<StorageState<D>>, List<StorageState<D>>>(
      await delegate.onGetPage(offset, limit, options),
    );
  }
}

mixin StatefulGetListFromId<S extends StatefulService<D, R>, D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<List<StorageState<D>>>> getListFromId(
    String id, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <StorageState<D>>[];
    var response = await getPageFromId(
      id,
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body);
      if (response.page.hasNext) {
        response = await getPageFromId(
          id,
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<StorageState<D>>>> getPageFromId(
    String id,
    int offset,
    int limit,
    List<String> options,
  ) async {
    return Api.from<PagedList<StorageState<D>>, List<StorageState<D>>>(
      await delegate.onGetPageFromId(id, offset, limit, options),
    );
  }
}

mixin StatefulGetFromIds<D extends JsonObject, R> on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<StorageState<D>>> getFromIds(List<String> ids, {List<String> options = const []}) async {
    return Api.from<StorageState<D>, StorageState<D>>(
      await delegate.onGetFromIds(ids, options: options),
    );
  }
}

mixin StatefulGetListFromIds<S extends StatefulService<D, R>, D extends JsonObject, R>
    on StatefulServiceDelegate<D, R> {
  Future<ServiceResponse<List<StorageState<D>>>> getListFromIds(
    List<String> ids, {
    int offset = 0,
    int limit = 20,
    List<String> options = const [],
  }) async {
    final items = <StorageState<D>>[];
    var response = await getPageFromIds(
      ids?.toPage(offset: offset, limit: limit)?.toList(),
      offset,
      limit,
      options,
    );
    while (response.is200) {
      items.addAll(response.body);
      offset += limit;
      if (offset < ids.length) {
        response = await getPageFromIds(
          ids,
          response.page.next,
          response.page.limit,
          options,
        );
      } else {
        return ServiceResponse.ok(body: items);
      }
    }
    return response;
  }

  Future<ServiceResponse<List<StorageState<D>>>> getPageFromIds(
    List<String> ids,
    int offset,
    int limit,
    List<String> options,
  ) async {
    return Api.from<PagedList<StorageState<D>>, List<StorageState<D>>>(
      await delegate.onGetPageFromIds(ids, offset, limit, options),
    );
  }
}
