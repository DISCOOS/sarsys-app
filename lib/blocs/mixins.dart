/// Initialize data source
mixin InitableBloc<Type> {
  Future<Type> init();
}

/// Load data from data source
mixin LoadableBloc<Type> {
  Future<Type> load();
}

/// Create [data] in data source
mixin CreatableBloc<Type> {
  Future<Type> create(Type create);
}

/// Update [data] in data source
mixin UpdatableBloc<Type> {
  Future<Type> update(Type data);
}

/// Delete [data] from data source
mixin DeletableBloc<Type> {
  Future<Type> delete(String uuid);
}

/// Unload data from source source
mixin UnloadableBloc<Type> {
  Future<Type> unload();
}
