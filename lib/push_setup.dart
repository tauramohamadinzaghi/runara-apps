// lib/push_setup.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_bus.dart';

final FlutterLocalNotificationsPlugin _flnp = FlutterLocalNotificationsPlugin();

Future<void> initPush() async {
  await Firebase.initializeApp();

  // minta izin notifikasi
  final fm = FirebaseMessaging.instance;
  await fm.requestPermission(alert: true, badge: true, sound: true);
  await fm.setAutoInitEnabled(true);

  // pastikan relawan (dan/atau semua device) join topik 'sos'
  await fm.subscribeToTopic('sos');

  // init local notifications + bikin channel 'sos'
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _flnp.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (resp) {
      // buka pop-out saat user tap notif
      SosBus.emit(const SosPayload(name: 'Unknown', role: 'Tunanetra', address: ''));
    },
  );

  final afln = _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await afln?.createNotificationChannel(const AndroidNotificationChannel(
    'sos', 'SOS',
    description: 'Emergency alerts',
    importance: Importance.max,
  ));

  // handler pesan foreground
  FirebaseMessaging.onMessage.listen(_handleMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // pesan yang membuka app dari terminated
  final initMsg = await fm.getInitialMessage();
  if (initMsg != null) _handleMessage(initMsg);

  // background handler
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

  // kirim ke UI → pop-out
  SosBus.emit(p);

  // tampilkan heads-up notif
  _flnp.show(
    1001,
    'Permintaan Bantuan Segera',
    p.address.isEmpty ? 'Tap untuk buka' : p.address,
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

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {
  await Firebase.initializeApp();
  if (m.data['type'] != 'sos') return;
  await _flnp.show(
    1002,
    'Permintaan Bantuan Segera',
    m.data['address'] ?? 'Tap untuk buka',
    const NotificationDetails(
      android: AndroidNotificationDetails('sos', 'SOS', importance: Importance.max, priority: Priority.high, fullScreenIntent: true),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    ),
    payload: 'sos',
  );
}
