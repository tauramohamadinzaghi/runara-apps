import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;

class AuthService {
  AuthService._();
  static final AuthService i = AuthService._();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Aman untuk v6 maupun v7
  static final gsi.GoogleSignIn _google = gsi.GoogleSignIn.instance;

  // ---------- GOOGLE SIGN-IN (kompatibel v6 & v7) ----------
  static Future<void> initGoogleSignIn({
    String? serverClientId,
    String? clientId,
    String? hostedDomain,
    String? nonce,
  }) async {
    try {
      await (_google as dynamic).initialize(
        serverClientId: serverClientId,
        clientId: clientId,
        hostedDomain: hostedDomain,
        nonce: nonce,
      );
    } catch (_) {
      // v6 tidak punya initialize()
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    gsi.GoogleSignInAccount? acc;

    // v7: attemptLightweightAuthentication()
    try {
      acc = await (_google as dynamic).attemptLightweightAuthentication();
    } catch (_) {}

    // v6: signInSilently()
    if (acc == null) {
      try {
        acc = await (_google as dynamic).signInSilently();
      } catch (_) {}
    }

    // UI -> v7: authenticate() ; fallback v6: signIn()
    if (acc == null) {
      try {
        acc = await (_google as dynamic).authenticate();
      } catch (_) {
        try {
          acc = await (_google as dynamic).signIn();
        } catch (_) {}
      }
    }

    if (acc == null) {
      throw FirebaseAuthException(
        code: 'google-canceled',
        message: 'Login Google dibatalkan.',
      );
    }

    final dynamic gAuth = await acc.authentication;
    final String? idToken = (gAuth as dynamic).idToken as String?;
    String? accessToken;
    try {
      accessToken = (gAuth as dynamic).accessToken as String?;
    } catch (_) {
      accessToken = null; // v7 memang tidak punya accessToken
    }

    if (idToken == null && accessToken == null) {
      throw FirebaseAuthException(
        code: 'no-google-token',
        message:
        'Tidak menerima token Google. Cek SHA-1/SHA-256 & OAuth di Firebase Console.',
      );
    }

    final OAuthCredential cred = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    return _auth.signInWithCredential(cred);
  }

  // ---------- FACEBOOK ----------
  Future<UserCredential> signInWithFacebook() async {
    final result = await FacebookAuth.instance
        .login(permissions: const ['email', 'public_profile']);

    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw FirebaseAuthException(
        code: 'fb-failed',
        message: result.message ?? 'Facebook login gagal.',
      );
    }

    final OAuthCredential cred =
    FacebookAuthProvider.credential(result.accessToken!.tokenString);
    return _auth.signInWithCredential(cred);
  }

  // ---------- EMAIL / PASSWORD ----------
  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpEmailPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user?.updateDisplayName(displayName);
    }
    return cred;
  }

  Future<void> sendEmailVerification() async {
    final u = _auth.currentUser;
    if (u == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'Belum ada user yang login/terdaftar.',
      );
    }
    if (!u.emailVerified) {
      await u.sendEmailVerification();
    }
  }

  Future<bool> refreshAndIsEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ---------- PHONE AUTH (OTP) ----------
  int? _resendToken;

  /// Return:
  /// - ""  : auto-verified (instant/auto-retrieval)
  /// - verId: perlu input kode 6 digit
  Future<String> startPhoneAuth(String phoneNumberE164) async {
    final c = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumberE164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential cred) async {
        try {
          await _auth.signInWithCredential(cred);
          if (!c.isCompleted) c.complete('');
        } catch (e) {
          if (!c.isCompleted) c.completeError(e);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!c.isCompleted) c.completeError(e);
      },
      codeSent: (String verificationId, int? token) {
        _resendToken = token;
        if (!c.isCompleted) c.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!c.isCompleted) c.complete(verificationId);
      },
    );

    return c.future;
  }

  Future<UserCredential> verifySmsCode(
      String verificationId, String smsCode) {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(cred);
  }

  Future<void> startPhoneVerification({
    required String phoneE164,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onAutoVerified,
    required void Function(FirebaseAuthException e) onFailed,
    required void Function(String verId) onCodeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken ?? _resendToken,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  Future<void> submitSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final user = _auth.currentUser;
    if (user != null) {
      await user.linkWithCredential(cred);
      await user.reload();
    } else {
      await _auth.signInWithCredential(cred);
    }
  }

  void resetResendToken() => _resendToken = null;

  // ---------- SIGN OUT ----------
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
          () async {
        try {
          await _google.signOut();
        } catch (_) {}
      }(),
          () async {
        try {
          await FacebookAuth.instance.logOut();
        } catch (_) {}
      }(),
    ]);
  }

  User? get currentUser => _auth.currentUser;
}
