import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the logged-in session and the hashed 4 digit PIN in the
/// platform keystore (Android Keystore / iOS Keychain).
class SessionStore {
  static const _storage = FlutterSecureStorage();
  static const _kSession = 'session_phone';
  static const int maxPinAttempts = 5;

  String? _phone;

  /// The phone number of the logged-in user, or null when logged out.
  String? get phone => _phone;
  bool get isLoggedIn => _phone != null;

  Future<void> load() async {
    _phone = await _storage.read(key: _kSession);
  }

  Future<void> saveSession(String phone) async {
    _phone = phone;
    await _storage.write(key: _kSession, value: phone);
  }

  Future<void> clearSession() async {
    _phone = null;
    await _storage.delete(key: _kSession);
  }

  // ---- PIN ----

  String _k(String phone, String name) => 'pin_${name}_$phone';

  Future<bool> hasPin(String phone) async =>
      (await _storage.read(key: _k(phone, 'hash'))) != null;

  Future<void> setPin(String phone, String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _k(phone, 'salt'), value: salt);
    await _storage.write(key: _k(phone, 'hash'), value: _hash(pin, salt));
    await _storage.write(key: _k(phone, 'fails'), value: '0');
  }

  /// Returns true when [pin] matches. After [maxPinAttempts] wrong tries the
  /// PIN is removed and the user must sign in with OTP again.
  Future<bool> verifyPin(String phone, String pin) async {
    final salt = await _storage.read(key: _k(phone, 'salt'));
    final hash = await _storage.read(key: _k(phone, 'hash'));
    if (salt == null || hash == null) return false;
    if (_hash(pin, salt) == hash) {
      await _storage.write(key: _k(phone, 'fails'), value: '0');
      return true;
    }
    final fails =
        int.tryParse(await _storage.read(key: _k(phone, 'fails')) ?? '0') ?? 0;
    if (fails + 1 >= maxPinAttempts) {
      await removePin(phone);
    } else {
      await _storage.write(key: _k(phone, 'fails'), value: '${fails + 1}');
    }
    return false;
  }

  Future<int> remainingAttempts(String phone) async {
    final fails =
        int.tryParse(await _storage.read(key: _k(phone, 'fails')) ?? '0') ?? 0;
    return maxPinAttempts - fails;
  }

  Future<void> removePin(String phone) async {
    for (final n in ['salt', 'hash', 'fails']) {
      await _storage.delete(key: _k(phone, n));
    }
  }

  String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Salted, iterated SHA-256. The PIN itself is never stored.
  String _hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }
}
