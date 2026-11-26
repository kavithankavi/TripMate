import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result of a PIN check.
enum PinCheck { ok, wrong, locked }

/// Keeps the 4 digit login PIN as a salted hash in the platform keystore
/// (Android Keystore / iOS Keychain). There is no account or phone number:
/// the PIN protects the app on this phone.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kSalt = 'pin_salt';
  static const _kHash = 'pin_hash';
  static const _kFails = 'pin_fails';
  static const _kLockedUntil = 'pin_locked_until';

  /// Wrong tries allowed before the PIN screen is locked for [lockout].
  static const int maxPinAttempts = 5;
  static const Duration lockout = Duration(seconds: 30);

  bool _hasPin = false;
  bool _unlocked = false;

  /// True once a PIN has been created on this phone.
  bool get hasPin => _hasPin;

  /// True after the correct PIN was entered in this app session.
  bool get isUnlocked => _unlocked;

  Future<void> load() async {
    _hasPin = (await _storage.read(key: _kHash)) != null;
    _unlocked = false;
  }

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _storage.write(key: _kSalt, value: salt);
    await _storage.write(key: _kHash, value: hashPin(pin, salt));
    await _storage.write(key: _kFails, value: '0');
    await _storage.delete(key: _kLockedUntil);
    _hasPin = true;
    _unlocked = true;
  }

  /// Checks [pin]. After [maxPinAttempts] wrong tries further tries are
  /// refused for [lockout].
  Future<PinCheck> verifyPin(String pin) async {
    if (await lockedFor() > Duration.zero) return PinCheck.locked;
    final salt = await _storage.read(key: _kSalt);
    final hash = await _storage.read(key: _kHash);
    if (salt == null || hash == null) return PinCheck.wrong;
    if (hashPin(pin, salt) == hash) {
      await _storage.write(key: _kFails, value: '0');
      _unlocked = true;
      return PinCheck.ok;
    }
    final fails = await _fails() + 1;
    if (fails >= maxPinAttempts) {
      await _storage.write(key: _kFails, value: '0');
      await _storage.write(
          key: _kLockedUntil,
          value: '${DateTime.now().add(lockout).millisecondsSinceEpoch}');
      return PinCheck.locked;
    }
    await _storage.write(key: _kFails, value: '$fails');
    return PinCheck.wrong;
  }

  Future<int> remainingAttempts() async => maxPinAttempts - await _fails();

  /// How long the PIN screen stays locked, or [Duration.zero].
  Future<Duration> lockedFor() async {
    final v = int.tryParse(await _storage.read(key: _kLockedUntil) ?? '');
    if (v == null) return Duration.zero;
    final left = DateTime.fromMillisecondsSinceEpoch(v).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Locks the app; the PIN is needed again.
  void lock() => _unlocked = false;

  /// Forgets the PIN (used by "Forgot PIN", together with erasing trips).
  Future<void> removePin() async {
    for (final k in [_kSalt, _kHash, _kFails, _kLockedUntil]) {
      await _storage.delete(key: k);
    }
    _hasPin = false;
    _unlocked = false;
  }

  Future<int> _fails() async =>
      int.tryParse(await _storage.read(key: _kFails) ?? '0') ?? 0;

  String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Salted, iterated SHA-256. The PIN itself is never stored.
  static String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }
}
