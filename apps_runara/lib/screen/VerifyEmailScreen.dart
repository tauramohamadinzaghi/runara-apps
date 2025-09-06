// lib/screen/verify_email_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';

const _bgBlue = Color(0xFF0D1B3D);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _errorRed = Color(0xFFFF4D4F);

class VerifyEmailLinkScreen extends StatefulWidget {
  final String email;
  const VerifyEmailLinkScreen({super.key, required this.email});

  // ⬇️ builder route yang TIDAK mungkin null
  static Widget fromRouteArgs(RouteSettings settings) {
    String email = 'user@email.com';
    final args = settings.arguments;
    if (args is Map && args['email'] is String && (args['email'] as String).isNotEmpty) {
      email = args['email'] as String;
    }
    return VerifyEmailLinkScreen(email: email);
  }

  @override
  State<VerifyEmailLinkScreen> createState() => _VerifyEmailLinkScreenState();
}

class _VerifyEmailLinkScreenState extends State<VerifyEmailLinkScreen> {
  String? _error;
  bool _busy = false;
  int _secondsLeft = 60;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AuthService.i.sendEmailVerification();
    });
    _startCountdown();
  }

  @override
  void dispose() { _ticker?.cancel(); super.dispose(); }

  void _startCountdown() {
    _ticker?.cancel();
    _secondsLeft = 60;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) t.cancel();
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 999));
    });
  }

  Future<void> _checkVerified() async {
    setState(() { _busy = true; _error = null; });
    try {
      final ok = await AuthService.i.refreshAndIsEmailVerified();
      if (ok && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin', (r) => false,
          arguments: {'flashMessage': 'Sign up berhasil! Email terverifikasi. Silakan Sign In.'},
        );
      } else {
        _error = 'Belum terverifikasi. Klik tautan di email, lalu tekan tombol ini lagi.';
      }
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlue,
      appBar: AppBar(
        backgroundColor: _bgBlue, elevation: 0,
        title: const Text('VERIFY EMAIL', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Image.asset('assets/ic_back.png', width: 36, height: 36),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: const Color(0x222B3B6B), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(children: [
              const Text('Cek email kamu', style: TextStyle(color: Colors.green, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Kami telah mengirimkan tautan verifikasi ke:', style: TextStyle(color: _subtle, fontSize: 18)),
              const SizedBox(height: 8),
              Text(widget.email, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _checkVerified,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Saya sudah klik tautan verifikasi'),
            ),
          ),
          const SizedBox(height: 16),
          if (_secondsLeft > 0)
            Text('Kirim ulang dalam ${_fmt(_secondsLeft)}',
                textAlign: TextAlign.center, style: const TextStyle(color: _accent, fontSize: 16)),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(color: _errorRed, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
                TextButton(onPressed: () => setState(() => _error = null),
                    child: const Text('Tutup', style: TextStyle(color: Colors.white))),
              ]),
            ),
          ],
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
