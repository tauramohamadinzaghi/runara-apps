// lib/push_setup.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sos_bus.dart';

final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();

Future<void> initPush() async {
  await Firebase.initializeApp();

  final fm = FirebaseMessaging.instance;
  await fm.requestPermission(alert: true, badge: true, sound: true);

  // Subscribe ke topik umum (boleh kamu ganti per-user, mis: "sos-<uid>")
  await fm.subscribeToTopic('sos-all');
  await fm.subscribeToTopic('sos'); // tambahan


  // Local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _flnp.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (resp) {
      if (resp.payload == 'sos') {
        // Default jika payload tidak lengkap—UI tetap buka sheet
        SosBus.emit(const SosPayload(name: 'Unknown', role: 'Tunanetra', address: ''));
      }
    },
  );

  // Handler pesan
  FirebaseMessaging.onMessage.listen(_handleMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  final initMsg = await fm.getInitialMessage();
  if (initMsg != null) _handleMessage(initMsg);

  FirebaseMessaging.onBackgroundMessage(_bgHandler);
}

void _handleMessage(RemoteMessage m) {
  if (m.data['type'] != 'sos') return;

  final p = SosPayload(
    name: m.data['name'] ?? 'Unknown',
    role: m.data['role'] ?? 'Tunanetra',
    address: m.data['address'] ?? '',
    lat: double.tryParse(m.data['lat'] ?? ''),
    lng: double.tryParse(m.data['lng'] ?? ''),
  );

  // Emit ke UI
  SosBus.emit(p);

  // Tampilkan heads-up notif juga (kalau sedang foreground pun tidak apa)
  _flnp.show(
    1001,
    'Emergency Request',
    p.address.isEmpty ? 'Tap to open' : p.address,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'sos', 'SOS',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true, // Android: bisa pop-up penuh (butuh izin)
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    ),
    payload: 'sos',
  );
}

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
  if (m.data['type'] != 'sos') return;
  // Saat background: tampilkan notif agar bisa dibuka user
  await _flnp.show(
    1002,
    'Emergency Request',
    m.data['address'] ?? 'Tap to open',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'sos', 'SOS',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    ),
    payload: 'sos',
  );
}
