// lib/sos_bus.dart
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class SosPayload {
  final String name;
  final String role;
  final String address;
  final double? lat;
  final double? lng;

  const SosPayload({
    required this.name,
    required this.role,
    required this.address,
    this.lat,
    this.lng,
  });
}

class SosBus {
  static bool _isSubscribed = false;

  // === Event bus (tambahan) ===
  static final StreamController<SosPayload> _ctrl =
  StreamController<SosPayload>.broadcast();

  static Stream<SosPayload> get stream => _ctrl.stream;

  static void emit(SosPayload payload) {
    // pastikan izin & subscribe tetap jalan
    ensureFcmReady();
    _ctrl.add(payload);
  }

  /// Minta izin notifikasi & subscribe ke topik "sos" (idempotent)
  static Future<void> ensureFcmReady() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      if (!_isSubscribed) {
        await FirebaseMessaging.instance.subscribeToTopic('sos');
        _isSubscribed = true;
      }
    } catch (_) {
      // biarkan silent; jangan ganggu UX
    }
  }

  /// Panggil Cloud Functions "sendSos"
  static Future<void> sendSos({
    String title = 'SOS',
    String body = 'Permintaan bantuan',
    String topic = 'sos',
  }) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
    final callable = functions.httpsCallable('sendSos');
    await callable.call(<String, dynamic>{
      'topic': topic,
      'title': title,
      'body': body,
    });
  }

  /// Pop-out SOS + tombol kirim
  static Future<void> showSosSheet(BuildContext context) async {
    await ensureFcmReady();

    // bottom sheet konfirmasi SOS
    // (warna disesuaikan agar cocok dengan tema kamu)
    // Tidak mengubah state luar — hanya menambah UI ini.
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kirim Permintaan Bantuan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tekan tombol di bawah untuk mengirim notifikasi SOS ke relawan di sekitar.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sos_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9AA6FF),
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: sending
                          ? null
                          : () async {
                        setState(() => sending = true);
                        try {
                          await sendSos();
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('SOS terkirim')),
                          );
                        } catch (e) {
                          setState(() => sending = false);
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal kirim SOS: $e')),
                          );
                        }
                      },
                      label: Text(sending ? 'Mengirim...' : 'Kirim SOS'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
