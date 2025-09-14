// lib/sos_bus.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';

class SosPayload {
  final String name;
  final String role;
  final String address;
  final double? lat;
  final double? lng;
  // >>> ADDED: optional photo URL untuk avatar pengirim
  final String? photoUrl;

  const SosPayload({
    required this.name,
    required this.role,
    required this.address,
    this.lat,
    this.lng,
    // >>> ADDED
    this.photoUrl,
  });
}

class SosBus {
  // === STREAM BUS ===
  static final StreamController<SosPayload> _ctrl = StreamController<SosPayload>.broadcast();
  static Stream<SosPayload> get stream => _ctrl.stream;
  static bool _isSubscribed = false;

  static Future<void> _ensureFcmReady() async {
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (!_isSubscribed) {
        await FirebaseMessaging.instance.subscribeToTopic('sos');
        _isSubscribed = true;
      }
    } catch (_) {}
  }

  /// Kirim event SOS ke semua listener lokal (in-app)
  static void emit(SosPayload payload) {
    _ensureFcmReady();
    _ctrl.add(payload);
  }

  // >>> ADDED: alias agar bisa dipanggil sebagai SosBus.send(payload)
  static void send(SosPayload payload) => emit(payload);

  // === KIRIM SOS (memanggil Cloud Functions) ===
  static Future<void> sendSos({
    String title = 'Permintaan Bantuan Segera',
    String body = 'Tap untuk buka',
    String topic = 'sos',
    String name = '',
    String role = 'Tunanetra',
    String address = '',
    double? lat,
    double? lng,
  }) async {
    final fns = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
    final callable = fns.httpsCallable('sendSos');
    await callable.call(<String, dynamic>{
      'topic': topic,
      'title': title,
      'body': body,
      'name': name,
      'role': role,
      'address': address,
      'lat': lat,
      'lng': lng,
      // NOTE: photoUrl tidak wajib dikirim ke FCM. Tambah jika backend mendukung.
      // 'photoUrl': photoUrl,
    });
  }

  // === SHEET UNTUK MENGIRIM SOS (akun Tunanetra) ===
  static Future<void> showSendSheet(BuildContext context, {
    String name = '',
    String role = 'Tunanetra',
    String address = '',
    double? lat,
    double? lng,
  }) async {
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        bool sending = false;
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 12),
                const Text('Kirim Permintaan Bantuan', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Tekan tombol di bawah untuk mengirim notifikasi SOS ke relawan di sekitar.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sos_outlined),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9AA6FF), foregroundColor: Colors.black,
                      shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: sending ? null : () async {
                      setState(() => sending = true);
                      try {
                        await sendSos(name: name, role: role, address: address, lat: lat, lng: lng);
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS terkirim')));
                      } catch (e) {
                        setState(() => sending = false);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal kirim SOS: $e')));
                      }
                    },
                    label: Text(sending ? 'Mengirim...' : 'Kirim SOS'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // === SHEET MASUK UNTUK RELAWAN (sesuai gambar) ===
  static Future<void> showIncomingSheet(BuildContext context, SosPayload p) async {
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E2346),
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('Permintaan Bantuan Segera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            // >>> UPDATED: dukung foto profil jika tersedia
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(.1),
              backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty) ? NetworkImage(p.photoUrl!) : null,
              child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(p.role, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
            Text(p.name, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              p.address.isEmpty
                  ? ((p.lat != null && p.lng != null) ? '${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}' : 'Lokasi tidak diketahui')
                  : p.address,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.location_pin),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: const StadiumBorder()),
                onPressed: () async {
                  final lat = p.lat, lng = p.lng;
                  Uri? uri;
                  if (lat != null && lng != null) {
                    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                  } else if (p.address.isNotEmpty) {
                    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(p.address)}');
                  }
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                label: const Text('Arahkan Lokasi'),
              ),
            ),
          ]),
        );
      },
    );
  }
}
