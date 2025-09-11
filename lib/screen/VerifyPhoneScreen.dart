// lib/screen/verify_phone_screen.dart
// Versi ini MENGGANTI alur Firebase Phone Auth (verificationId) menjadi
// alur OTP server sendiri + Firebase Custom Token.
//
// Cara kerja:
// 1) _startPhoneAuth() -> panggil /otp/start (kirim OTP via Twilio)
// 2) User masukkan 6 digit -> _submit() -> /otp/verify -> dapat custom token -> signInWithCustomToken
// 3) Jika sukses, arahkan user ke halaman berikutnya.
//
// Catatan:
// - Pastikan server Node OTP kamu berjalan (lokal atau deploy) dan variabel kServerBase di OtpApi benar.
// - Untuk Android emulator: kServerBase = 'http://10.0.2.2:3000'
// - Untuk iOS simulator:  kServerBase = 'http://localhost:3000'
// - Untuk device fisik:   kServerBase = 'http://<IP-laptop-kamu>:3000' dan pastikan firewall mengizinkan.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _bgBlue = Color(0xFF0D1B3D);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _errorRed = Color(0xFFFF4D4F);
const _btnDisabled = Color(0xFF243153);
const _otpShellEmpty = Color(0xFFE6EAF2);
const _otpShellFilled = Colors.white;
const _otpDashEmpty = Color(0xFFB8C1D8);

class VerifyPhoneScreen extends StatefulWidget {
  final String phoneE164;
  final String? linkEmail;     // ⬅️ baru
  final String? linkPassword;  // ⬅️ baru

  const VerifyPhoneScreen({
    super.key,
    required this.phoneE164,
    this.linkEmail,
    this.linkPassword,
  });

  static Widget fromRouteArgs(RouteSettings settings) {
    String phone = '+6281112345678';
    String? linkEmail;
    String? linkPassword;

    final args = settings.arguments;
    if (args is Map) {
      if (args['phoneE164'] is String && (args['phoneE164'] as String).isNotEmpty) {
        phone = args['phoneE164'] as String;
      }
      if (args['linkEmail'] is String && (args['linkEmail'] as String).isNotEmpty) {
        linkEmail = args['linkEmail'] as String;
      }
      if (args['linkPassword'] is String && (args['linkPassword'] as String).isNotEmpty) {
        linkPassword = args['linkPassword'] as String;
      }
    }
    return VerifyPhoneScreen(
      phoneE164: phone,
      linkEmail: linkEmail,
      linkPassword: linkPassword,
    );
  }


  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _otpC = TextEditingController();
  final _otpF = FocusNode();

  String? _err;
  bool _busy = false;
  bool _otpSent = false; // ganti logika verId -> OTP sudah dikirim

  int _secondsLeft = 60;
  Timer? _ticker;

  bool get _canVerify => _otpSent && _otpC.text.length == 6 && !_busy;

  @override
  void initState() {
    super.initState();
    _otpC.addListener(() => setState(() {}));
    _startPhoneAuth(); // kirim OTP langsung ketika layar dibuka
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _otpF.requestFocus());
  }

  @override
  void dispose() {
    _otpC.dispose();
    _otpF.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = 60);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) return t.cancel();
      setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _startPhoneAuth() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await _otpStart(widget.phoneE164);
      if (!mounted) return;
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_canVerify) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await _otpVerifyAndLogin(widget.phoneE164, _otpC.text);
      if (!mounted) return;
      // Di titik ini user sudah sign-in dengan custom token
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '(unknown)';
      // Arahkan ke halaman berikutnya / signin page sesuai alur app kamu
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/signin',
            (r) => false,
        arguments: {'flashMessage': 'Verifikasi berhasil! UID: $uid'},
      );
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    _otpC.text = '';
    setState(() => _otpSent = false);
    await _startPhoneAuth();
    _startCountdown();
    if (!_otpF.hasFocus) _otpF.requestFocus();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(
          2, '0')}'
          .replaceAll(' ', '');

  @override
  Widget build(BuildContext context) {
    final verifyColor = _canVerify ? _accent : _btnDisabled;

    return Scaffold(
      backgroundColor: _bgBlue,
      appBar: AppBar(
        backgroundColor: _bgBlue,
        title: const Text(
            'VERIFY PHONE', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            // ... (ilustrasi + teks sesuai desain kamu) ...
            const SizedBox(height: 10),
            _OtpCapsule(
              controller: _otpC,
              focusNode: _otpF,
              onTap: () {
                if (!_otpF.hasFocus) _otpF.requestFocus();
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _canVerify ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: verifyColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: verifyColor,
                  disabledForegroundColor: Colors.white,
                ),
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text(
                    'Verify', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Color(0x332C3B6B)),
            const SizedBox(height: 10),
            const Text('Tidak menerima kode?', style: TextStyle(color: _subtle),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (_secondsLeft > 0)
              Text('Kirim ulang dalam ${_fmt(_secondsLeft)}',
                  style: const TextStyle(color: _accent, fontSize: 18),
                  textAlign: TextAlign.center)
            else
              Center(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _resend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF31406B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Kirim ulang kode'),
                  ),
                ),
              ),
            const SizedBox(height: 26),
            const Text('Tips: pastikan nomor aktif dan sinyal stabil.',
                style: TextStyle(color: _subtle), textAlign: TextAlign.center),
            const SizedBox(height: 36),
          ],
        ),
        if (_err != null)
          Positioned(
            left: 16, right: 16, top: 12,
            child: Material(
              color: _errorRed,
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_err!, style: const TextStyle(color: Colors
                          .white))),
                  TextButton(onPressed: () => setState(() => _err = null),
                      child: const Text('Tutup', style: TextStyle(color: Colors
                          .white)))
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ====== Helper panggilan API ======
  Future<void> _otpStart(String phoneE164) async {
    final r = await http.post(
      Uri.parse('${OtpApi.base}/otp/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phoneE164}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j['ok'] != true) {
      throw Exception(j['error'] ?? 'Gagal kirim OTP');
    }
  }

  Future<void> _otpVerifyAndLogin(String phoneE164, String code) async {
    final r = await http.post(
      Uri.parse('${OtpApi.base}/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phoneE164, 'code': code}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j['ok'] != true) {
      throw Exception(j['error'] ?? 'Kode salah/expired');
    }

    final token = j['token'] as String;
    // 1) sign in dengan custom token
    final cred = await FirebaseAuth.instance.signInWithCustomToken(token);

    // 2) opsional: link email+password
    if (widget.linkEmail != null && widget.linkPassword != null) {
      final emailCred = EmailAuthProvider.credential(
        email: widget.linkEmail!,
        password: widget.linkPassword!,
      );
      try {
        await cred.user?.linkWithCredential(emailCred);
        // (opsional) kirim verifikasi email
        await cred.user?.sendEmailVerification();
      } on FirebaseAuthException catch (e) {
        // kalau sudah terpakai, bisa tampilkan pesan agar user sign in email biasa
        if (e.code != 'provider-already-linked') rethrow;
      }
    }
  }
}


  class _OtpCapsule extends StatelessWidget {
  final TextEditingController controller; final FocusNode focusNode; final VoidCallback onTap;
  const _OtpCapsule({required this.controller, required this.focusNode, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Stack(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final digit = i < controller.text.length ? controller.text[i] : null;
            final filled = digit != null;
            return Expanded(
              child: Container(
                height: 62,
                margin: EdgeInsets.only(right: i == 5 ? 0 : 12),
                decoration: BoxDecoration(
                  color: filled ? _otpShellFilled : _otpShellEmpty,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: filled
                    ? Text(digit!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _bgBlue))
                    : Container(
                  width: (MediaQuery.of(context).size.width / 6) * .46, height: 6,
                  decoration: BoxDecoration(color: _otpDashEmpty, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            );
          }),
        ),
        Opacity(
          opacity: 0,
          child: TextField(
            focusNode: focusNode,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          ),
        ),
      ]),
    );
  }
}

// ====== Minimal OtpApi (konfigurasi base URL server di sini) ======
// ====== Minimal OtpApi (konfigurasi base URL server di sini) ======
class OtpApi {
  // Android emulator -> 10.0.2.2
  // iOS simulator   -> localhost
  // Device fisik    -> ganti ke IP laptop kamu, mis: http://192.168.1.10:3000
  static const String base = 'http://10.0.2.2:3000';
}

