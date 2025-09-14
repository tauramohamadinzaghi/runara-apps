// lib/screen/PaymentWebViewScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/donation_service.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String orderId;
  final String? redirectUrl; // opsional saja, kita abaikan di simulasi

  const PaymentWebViewScreen({
    super.key,
    required this.orderId,
    this.redirectUrl,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  final _svc = DonationService();
  bool _loading = false;
  String _status = 'pending';
  int _amount = 0;
  String _donor = '—';

  @override
  void initState() {
    super.initState();

    // Dengar perubahan dokumen donasi
    _svc.watchDonation(widget.orderId).listen((snap) {
      final d = snap.data();
      if (!mounted || d == null) return;
      setState(() {
        _status = (d['status'] ?? 'pending').toString();
        _amount = (d['amount'] ?? 0) as int;
        _donor = (d['donorName'] ?? 'Anonim').toString();
      });

      // Jika sudah settlement, langsung close halaman dengan result true
      if (_status == 'settlement' || _status == 'success' || _status == 'capture') {
        if (mounted) Navigator.pop(context, true);
      }
    });
  }

  Future<void> _simulatePay() async {
    setState(() => _loading = true);
    try {
      await _svc.simulateSettlement(widget.orderId);
    } finally {
      if (mounted) setState(() => _loading = false);
      // Navigator.pop dilakukan oleh listener ketika status = settlement
    }
  }

  Future<void> _simulateCancel() async {
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance.collection('donations').doc(widget.orderId).set({
        'status': 'cancel',
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _loading = false);
      if (mounted) Navigator.pop(context, false);
    }
  }

  String _fmtIdr(int v) {
    // format sederhana "Rp 50.000"
    final s = v.toString().replaceAll(RegExp(r'(?=(\d{3})+(?!\d))'), '.');
    return 'Rp $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1446),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1446),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset(
            'assets/ic_back.png',
            width: 18, height: 18,
            errorBuilder: (_, __, ___) => const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text('Bayar Donasi (Simulasi)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            // Kartu ringkasan
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF152449),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A3C6C)),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_donor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          _amount > 0 ? _fmtIdr(_amount) : 'Nominal tidak diketahui',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Status: ', style: TextStyle(color: Colors.white60)),
                            Text(
                              _status.toUpperCase(),
                              style: TextStyle(
                                color: _status == 'settlement' ? const Color(0xFF22C55E) : Colors.amberAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // Banner info simulasi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Mode simulasi: tidak terhubung payment gateway.\n'
                    'Tekan "Bayar (Simulasi)" untuk menandai donasi sebagai BERHASIL.',
                style: TextStyle(color: Colors.white70, height: 1.3),
              ),
            ),

            const Spacer(),
            // Tombol aksi
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _simulateCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batalkan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _simulatePay,
                    icon: _loading
                        ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_loading ? 'Memproses...' : 'Bayar (Simulasi)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B8AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
