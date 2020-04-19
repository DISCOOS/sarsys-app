import 'package:SarSys/core/storage.dart';
import 'package:hive/hive.dart';

import 'package:SarSys/models/AuthToken.dart';

class AuthTokenRepository {
  AuthTokenRepository({this.compactWhen = 10});
  final int compactWhen;

  Box<StorageState<AuthToken>> _tokens;
  AuthToken operator [](String userId) => _tokens?.get(userId)?.value;

  Iterable<String> get keys => List.unmodifiable(_tokens?.keys ?? []);
  Iterable<AuthToken> get values => List.unmodifiable(_tokens?.values?.map((state) => state.value) ?? []);

  bool containsKey(String userId) => _tokens?.keys?.contains(userId) ?? false;
  bool containsValue(AuthToken token) => _tokens?.values?.contains(token) ?? false;

  bool get isReady => _tokens?.isOpen == true;
  void _assert() {
    if (!isReady) {
      throw '$AuthTokenRepository is not ready';
    }
  }

  Future<Box<StorageState<AuthToken>>> _open() async => Hive.openBox(
        '$AuthTokenRepository',
        encryptionKey: await Storage.hiveKey<AuthToken>(),
        compactionStrategy: (_, deleted) => compactWhen < deleted,
      );

  Future<List<AuthToken>> load() async {
    _tokens ??= await _open();
    return values;
  }

  Future<AuthToken> put(AuthToken token) async => _put(token);

  Future<AuthToken> delete(String userId) async {
    _assert();
    final token = _tokens.get(userId);
    if (token != null) {
      await _tokens.delete(userId);
    }
    return token?.value;
  }

  Future<Iterable<AuthToken>> clear() async {
    final tokens = _tokens.values.toList();
    await _tokens.clear();
    return tokens.map((state) => state.value);
  }

  Future<AuthToken> _put(AuthToken token) async {
    _assert();
    await _tokens.put(
      token.userId,
      StorageState.local(token),
    );
    return token;
  }
}
