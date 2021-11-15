

import 'dart:async';

import 'package:SarSys/core/data/storage.dart';
import 'package:SarSys/core/domain/repository.dart';
import 'package:hive/hive.dart';

import 'package:SarSys/features/user/domain/entities/AuthToken.dart';

class AuthTokenRepository implements Repository<String, AuthToken?> {
  AuthTokenRepository();

  @override
  AuthToken? operator [](String? userId) => userId == null ? null : _tokens?.get(userId);
  Box<AuthToken>? _tokens;

  @override
  bool get isEmpty => _tokens == null || _tokens!.isOpen && _tokens!.isEmpty;

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  int get length => isEmpty ? 0 : _tokens!.length;

  AuthToken? get(String userId) => _tokens!.get(userId);
  Iterable<String> get keys => List.unmodifiable(_tokens?.keys ?? []);
  Iterable<AuthToken> get values => List.unmodifiable((_tokens?.values ?? []) as Iterable<dynamic>);

  bool containsKey(String? userId) => _tokens?.keys.contains(userId) ?? false;
  bool containsValue(AuthToken token) => _tokens?.values.contains(token) ?? false;

  bool get isReady => _tokens?.isOpen == true;
  void _assert() {
    if (!isReady) {
      throw '$AuthTokenRepository is not ready';
    }
  }

  FutureOr<Box<AuthToken>?> _open() async {
    if (_tokens == null) {
      _tokens = await Hive.openBox(
        '$AuthTokenRepository',
        encryptionCipher: await Storage.hiveCipher<AuthToken>(),
      );
    }
    return _tokens;
  }

  Future<List<AuthToken>> load() async {
    _tokens = await _open();
    return values as FutureOr<List<AuthToken>>;
  }

  Future<AuthToken> put(AuthToken token) async => _put(token);

  Future<AuthToken?> delete(String? userId) async {
    _assert();
    final token = _tokens!.get(userId);
    if (token != null) {
      await _tokens!.delete(userId);
    }
    return token;
  }

  Future<Iterable<AuthToken>> clear() async {
    final tokens = _tokens!.values.toList();
    await _tokens!.clear();
    return tokens;
  }

  Future<AuthToken> _put(AuthToken token) async {
    _assert();
    await _tokens!.put(
      token.userId,
      token,
    );
    return token;
  }
}
