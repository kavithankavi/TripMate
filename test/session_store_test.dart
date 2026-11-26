import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/services/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('first launch has no PIN; setting one unlocks', () async {
    final s = SessionStore();
    await s.load();
    expect(s.hasPin, isFalse);
    await s.setPin('1234');
    expect(s.hasPin, isTrue);
    expect(s.isUnlocked, isTrue);

    final again = SessionStore();
    await again.load();
    expect(again.hasPin, isTrue);
    expect(again.isUnlocked, isFalse, reason: 'PIN is asked on every launch');
  });

  test('right and wrong PIN', () async {
    final s = SessionStore();
    await s.setPin('4321');
    s.lock();
    expect(await s.verifyPin('0000'), PinCheck.wrong);
    expect(await s.remainingAttempts(), SessionStore.maxPinAttempts - 1);
    expect(await s.verifyPin('4321'), PinCheck.ok);
    expect(s.isUnlocked, isTrue);
    expect(await s.remainingAttempts(), SessionStore.maxPinAttempts);
  });

  test('five wrong tries lock the PIN screen', () async {
    final s = SessionStore();
    await s.setPin('1111');
    for (var i = 0; i < SessionStore.maxPinAttempts - 1; i++) {
      expect(await s.verifyPin('2222'), PinCheck.wrong);
    }
    expect(await s.verifyPin('2222'), PinCheck.locked);
    expect(await s.lockedFor(), greaterThan(Duration.zero));
    // Even the right PIN is refused while locked.
    expect(await s.verifyPin('1111'), PinCheck.locked);
  });

  test('removePin forgets the PIN', () async {
    final s = SessionStore();
    await s.setPin('1111');
    await s.removePin();
    expect(s.hasPin, isFalse);
    expect(await s.verifyPin('1111'), PinCheck.wrong);
  });

  test('PIN is stored only as a salted hash', () {
    expect(SessionStore.hashPin('1234', 'a'), isNot(SessionStore.hashPin('1234', 'b')));
    expect(SessionStore.hashPin('1234', 'a'), isNot(contains('1234')));
  });
}
