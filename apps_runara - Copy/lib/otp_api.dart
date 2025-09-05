import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// GANTI sesuai target:
// - Android emulator: http://10.0.2.2:3000
// - iOS simulator:   http://localhost:3000
// - Device fisik:    http://<IP-laptop-kamu>:3000
const _base = 'https://otp-server-gamma.vercel.app/'; // ganti URL-mu

class OtpApi {
  static Future<void> start(String phoneE164, {String channel = 'sms'}) async {
    final r = await http.post(
      Uri.parse('$_base/otp/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phoneE164, 'channel': channel}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j['ok'] != true) {
      throw Exception(j['error'] ?? 'Gagal kirim OTP');
    }
  }

  static Future<void> verifyAndLogin(String phoneE164, String code) async {
    final r = await http.post(
      Uri.parse('$_base/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phoneE164, 'code': code}),
    );
    final j = jsonDecode(r.body);
    if (r.statusCode != 200 || j['ok'] != true) {
      throw Exception(j['error'] ?? 'Kode salah/expired');
    }
    final token = j['token'] as String;
    await FirebaseAuth.instance.signInWithCustomToken(token);
  }
}
