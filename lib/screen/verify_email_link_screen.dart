import 'package:flutter/material.dart';
import 'package:apps_runara/screen/auth_service.dart';

class VerifyEmailLinkScreen extends StatefulWidget {
  const VerifyEmailLinkScreen({super.key});

  @override
  State<VerifyEmailLinkScreen> createState() => _VerifyEmailLinkScreenState();
}

class _VerifyEmailLinkScreenState extends State<VerifyEmailLinkScreen> {
  bool _busy = false;
  String? _emailShown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['email'] is String) {
      _emailShown = args['email'] as String;
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _busy = true);
    try {
      final ok = await AuthService.i.refreshAndIsEmailVerified();
      if (!mounted) return;
      if (ok) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/signin',
              (_) => false,
          arguments: {'flashMessage': 'Sign up berhasil! Email terverifikasi.'},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum terverifikasi. Coba klik link di email, lalu tekan cek lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await AuthService.i.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verifikasi dikirim ulang.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D1B3D);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('VERIFY EMAIL', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 96),
            const SizedBox(height: 16),
            Text(
              'Kami mengirimkan link verifikasi ke:',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _emailShown ?? '-',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'Buka email kamu lalu klik tautan verifikasi. Setelah itu tekan tombol di bawah:',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : _checkVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9AA6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SAYA SUDAH VERIFIKASI'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : _resend,
              child: const Text('KIRIM ULANG EMAIL', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
