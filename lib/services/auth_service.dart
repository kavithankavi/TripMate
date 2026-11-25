import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config.dart';
import '../firebase_options.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum OtpSendResult {
  /// An SMS code was sent; show the OTP screen.
  codeSent,

  /// Android verified the number automatically; no code entry needed.
  autoVerified,
}

/// Small interface so the app can run with a mock (dev) backend or Firebase.
abstract class AuthService {
  bool get isDevMode;

  /// Sends an OTP to [phoneNumber] in E.164 format, e.g. +919876543210.
  Future<OtpSendResult> sendOtp(String phoneNumber);

  /// Verifies [code] for the number passed to the last [sendOtp] call.
  Future<void> verifyOtp(String code);

  Future<void> signOut();

  static Future<AuthService> create() async {
    if (AppConfig.useFirebase) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      return FirebasePhoneAuthService();
    }
    return MockAuthService();
  }
}

/// DEV MODE ONLY. Accepts [AppConfig.mockOtpCode] for any number.
/// No SMS is sent. Never ship a store build in this mode.
class MockAuthService implements AuthService {
  String? _pendingNumber;

  @override
  bool get isDevMode => true;

  @override
  Future<OtpSendResult> sendOtp(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _pendingNumber = phoneNumber;
    return OtpSendResult.codeSent;
  }

  @override
  Future<void> verifyOtp(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_pendingNumber == null) {
      throw AuthException('Please request a new code.');
    }
    if (code != AppConfig.mockOtpCode) {
      throw AuthException('Incorrect code. Please try again.');
    }
    _pendingNumber = null;
  }

  @override
  Future<void> signOut() async {}
}

/// Real OTP using Firebase phone authentication.
class FirebasePhoneAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int? _resendToken;
  String? _lastNumber;

  @override
  bool get isDevMode => false;

  @override
  Future<OtpSendResult> sendOtp(String phoneNumber) {
    final completer = Completer<OtpSendResult>();
    final sameNumber = phoneNumber == _lastNumber;
    _lastNumber = phoneNumber;
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: sameNumber ? _resendToken : null,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android instant verification / auto-retrieval.
        try {
          await _auth.signInWithCredential(credential);
          if (!completer.isCompleted) {
            completer.complete(OtpSendResult.autoVerified);
          }
        } catch (_) {
          // Fall back to manual code entry.
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(AuthException(_friendly(e)));
        }
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(OtpSendResult.codeSent);
        }
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
    return completer.future;
  }

  @override
  Future<void> verifyOtp(String code) async {
    final id = _verificationId;
    if (id == null) throw AuthException('Please request a new code.');
    try {
      await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendly(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'invalid-verification-code':
        return 'Incorrect code. Please try again.';
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }
}
