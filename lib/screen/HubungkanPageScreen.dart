import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class HubungkanPageScreen extends StatefulWidget {
  const HubungkanPageScreen({super.key});

  @override
  State<HubungkanPageScreen> createState() => _HubungkanPageScreenState();
}

class _HubungkanPageScreenState extends State<HubungkanPageScreen> {
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF05184A);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // BATAL kiri-atas
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      // Coba kembali ke halaman sebelumnya
                      final popped = await Navigator.of(context).maybePop();
                      // Jika tidak ada halaman sebelumnya (dibuka sebagai halaman pertama),
                      // kasih fallback aman ke root (ubah sesuai routes kamu kalau perlu)
                      if (!popped && mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                      }
                    },
                    child: const Text('Batal',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                ],
              ),

              const SizedBox(height: 16),

              // Judul lebih besar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shield_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Integrasi Alat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24, // <- lebih besar
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Lingkaran berdenyut
              const _PulseAvatar(),

              const SizedBox(height: 20),

              const Text(
                'Proses Pengkoneksian Berjalan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16, // <- lebih besar
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '00.22',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'MASUKKAN KODE BERIKUT UNTUK OPSI INTEGRASI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.2,
                  fontSize: 14, // <- lebih besar
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              // Input kode
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _codeCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF05184A),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tombol HUBUNGKAN
              SizedBox(
                width: 220,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9AFF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
    onPressed: () async {
    FocusScope.of(context).unfocus();
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Masukkan kode terlebih dahulu')),
    );
    return;
    }

    try {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
    final callable = functions.httpsCallable('confirmPair');
    final resp = await callable.call({'code': code});
    // contoh sukses:
    // resp.data => { ok: true, deviceId: 'esp32-abc' }
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Berhasil terhubung')),
    );
    if (mounted) Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
    // tampilkan pesan error dari server
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Gagal hubungkan: ${e.message}')),
    );
    }
                  },
                  child: const Text('Hubungkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar berdenyut (3 lingkaran)
class _PulseAvatar extends StatelessWidget {
  const _PulseAvatar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: const [
          _PulseCircle(size: 192, color: Color(0xFF3F4A8A), delay: 0),
          _PulseCircle(size: 144, color: Color(0xFF5F6ACB), delay: 1),
          _PulseCircle(
            size: 96,
            color: Color(0xFF8B9AFF),
            delay: 2,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PulseCircle extends StatefulWidget {
  final double size;
  final Color color;
  final int delay;
  final Widget? child;
  const _PulseCircle({
    super.key,
    required this.size,
    required this.color,
    required this.delay,
    this.child,
  });

  @override
  State<_PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<_PulseCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..forward(from: widget.delay / 3)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final scale = 1 + 0.15 * (t < .5 ? (t * 2) : (2 - t * 2));
        final opacity = 0.4 + 0.6 * (t < .5 ? (t * 2) : (2 - t * 2));
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
              child: widget.child == null ? null : Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
