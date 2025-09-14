// lib/services/donation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonationService {
  final _col = FirebaseFirestore.instance.collection('donations');
  final _stats = FirebaseFirestore.instance.collection('donation_stats').doc('aggregate');

  /// Buat donasi "bohongan" lalu langsung dianggap BERHASIL (settlement).
  /// Return: { orderId, redirectUrl }
  Future<Map<String, dynamic>> startDonation({
    required int amount,
    String? donorName,
    String? message,
    String? campaignId,
    String channel = 'mock', // penanda simulasi
    Map<String, dynamic>? extra,
  }) async {
    final orderId = _genOrderId();
    final now = FieldValue.serverTimestamp();

    // Simpan transaksi (pending -> settlement)
    await _col.doc(orderId).set({
      'orderId': orderId,
      'amount': amount,
      'donorName': (donorName == null || donorName.trim().isEmpty) ? 'Anonim' : donorName.trim(),
      'message': message ?? '',
      'campaignId': campaignId,
      'status': 'pending',
      'channel': channel,
      'createdAt': now,
      if (extra != null) ...extra,
    });

    // LANGSUNG dianggap berhasil
    await _col.doc(orderId).set({
      'status': 'settlement',
      'settledAt': now,
    }, SetOptions(merge: true));

    // Update agregat
    await _stats.set({
      'totalAmount': FieldValue.increment(amount),
      'totalTx': FieldValue.increment(1),
      'updatedAt': now,
    }, SetOptions(merge: true));

    return {
      'orderId': orderId,
      // untuk kompatibilitas lama, kita tetap kembalikan "redirectUrl"
      // tapi nanti layar payment kita abaikan WebView-nya.
      'redirectUrl': 'about:blank',
    };
  }

  /// Untuk layar "payment" simulasi (opsional)
  Future<void> simulateSettlement(String orderId) async {
    await _col.doc(orderId).set({
      'status': 'settlement',
      'settledAt': FieldValue.serverTimestamp(),
      'channel': 'mock',
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDonation(String orderId) {
    return _col.doc(orderId).snapshots();
  }

  Future<Map<String, dynamic>> checkStatus(String orderId) async {
    final snap = await _col.doc(orderId).get();
    final data = snap.data() ?? {};
    return {
      'order_id': orderId,
      'transaction_status': (data['status'] ?? 'pending').toString(),
      'amount': data['amount'] ?? 0,
      'channel': data['channel'] ?? 'mock',
    };
  }

  String _genOrderId() {
    final r = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'RUNARA-${DateTime.now().millisecondsSinceEpoch}-$r';
    // contoh: RUNARA-1736851234567-034912
  }
}
