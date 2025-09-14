// lib/screen/HomePageScreen.dart
import 'package:apps_runara/screen/AktivitasRiwayatPageScreen.dart';
import 'package:apps_runara/screen/MapsPageScreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'BantuanPageScreen.dart';
import 'PesanPageScreen.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // pastikan impor ini ada di file

// >>> ADDED
import 'package:url_launcher/url_launcher.dart';
import 'package:apps_runara/sos_bus.dart';
// >>> ADDED: for StreamSubscription
import 'dart:async';

// >>> ADDED: lokasi & reverse-geocoding
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'ChooseRoleScreen.dart';
import 'TunanetraPageScreen.dart';
import 'TipsPageScreen.dart';
import 'DonasiPageScreen.dart';
import 'package:apps_runara/screen/SettingsPageScreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// nav & header reusable
import 'widget/runara_thin_nav.dart';
import 'widget/runara_header.dart'; // RunaraHeaderSection, runaraGreetingIndo, runaraGreetingEmoji, RunaraNotificationSheet, AppNotification
import 'package:apps_runara/screen/CariPendampingPageScreen.dart';
import 'auth_service.dart';

/// =================== PALETTE ===================
const _bgBlue = Color(0xFF0D1B3D);
const _cardBlue = Color(0xFF152449);
const _navBlue = Color(0xFF0E1E44);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF22315E);
const _divider = Color(0xFF2A3C6C);

// === warna khusus section jadwal
const _scCard   = Color(0xFF1A2A6C);
const _scInner  = Color(0xFF2A3B8E);
const _scOrange = Color(0xFFFF8C00);
const _scBlue   = Color(0xFF4A90E2);

// === warna Icon Navigation (match HTML)
const _navActive     = Color(0xFF7B8AFF);   // aktif
const _navIdle       = Color(0xFF4B5B7A);   // non-aktif
const _navLabelIdle  = Color(0xFF8A9ABF);   // label non-aktif

// === warna Kustomisasi Fitur (match HTML)
const _cfBg          = Color(0xFF1B2543);
const _cfTile        = Color(0xFF2E3A6E);
const _cfBadge       = Color(0xFF3B4A7A);
const _cfTextSubtle  = Color(0xFF9CA0B7);
const _cfPrimary     = Color(0xFF9CA0F7);
const _cfReset       = Color(0xFF7B5FC5);

// === warna grid di pop-out "Semua Fitur"
const _allTileBg     = Color(0xFF2E3A6E);

/// ===== kecil: biar bisa pakai .ifEmpty(() => ...)
extension _StrX on String {
  String ifEmpty(String Function() fallback) => isEmpty ? fallback() : this;
}

class HomePageScreen extends StatefulWidget {
  final String role;
  final String name;

  const HomePageScreen({Key? key, required this.role, required this.name}) : super(key: key);

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}

/// =================== MODEL & HELPER ===================
enum UserRole { relawan, tunanetra }

class UserProfile {
  String name;
  UserRole role;
  int level; // start 0
  int xp;    // progress menuju level berikutnya
  static const int xpPerLevel = 100;

  UserProfile({
    required this.name,
    required this.role,
    this.level = 0,
    this.xp = 0,
  });

  double get progress => (xp % xpPerLevel) / xpPerLevel;
  int get shownLevel => level;

  void addXp(int amount) {
    xp += amount;
    while (xp >= xpPerLevel) {
      xp -= xpPerLevel;
      level++;
    }
  }

  String get roleLabel => role == UserRole.relawan ? 'Relawan' : 'Tunanetra';
}

// (hapus greetingIndo & greetingEmoji lokal — pakai dari runara_header.dart)
String formatKcal(double v) => v <= 0 ? '–' : '${v.toStringAsFixed(0)} Kcal';
String formatKm(double v) => v <= 0 ? '–' : '${v.toStringAsFixed(1)} Km';

String formatDateId(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/* ====== Jadwal Model ====== */
class AssistSchedule {
  final DateTime date; // tanggal agenda
  final String start;
  final String end;
  final String place;
  final String rolePill; // 'Tunanetra' atau 'Relawan'
  final String personName;

  const AssistSchedule({
    required this.date,
    required this.start,
    required this.end,
    required this.place,
    required this.rolePill,
    required this.personName,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserProfile? user;
  double totalCalories = 0;
  double totalDistance = 0;
  int sessionsPerWeek = 2;
  DateTime selectedDate = DateTime.now();

// AFTER:
  List<AppNotification> get _notifs => RunaraNotificationCenter.notifs;
  bool get _hasUnread => RunaraNotificationCenter.hasUnread;

  // ===== Quick Feature (untuk “Kustomisasi Fitur”)
  static const _quickKey = 'quick_priority_ids';
  static const _maxQuick = 4;
  // DEFAULT prioritas (tidak termasuk "Semua" karena "Semua" selalu ada)
  static const List<String> _defaultQuickIds = [
    'matchmaking', 'history', 'sos', 'settings'
  ];
  List<String> _quickIds = []; // disimpan ke SharedPreferences

  // Helper: sanitize daftar id fitur agar aman (hapus yang tidak dikenal/duplikat & batasi 4)
  List<String> _sanitizeQuick(List<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      if (seen.contains(id)) continue;
      if (!kAllFeatures.any((f) => f.id == id)) continue;
      out.add(id);
      seen.add(id);
      if (out.length >= _maxQuick) break;
    }
    return out;
  }

  // ===== Demo data jadwal (generate per tanggal) =====
  List<AssistSchedule> _schedulesFor(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);

    final tunanetraNames = ['Aldy Giovani', 'Sinta Dewi', 'Bima Pratama', 'Laras Sekar'];
    final relawanNames   = ['Raka Maulana', 'Hilda Afiah', 'Anwar Ramzi', 'Nadia Putri'];
    final places = ['Gelora Bung Karno', 'Lapangan Saparua', 'Stadion Jalak Harupat', 'GOR Pajajaran'];

    final idx = (date.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24)) % 4;
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    final List<AssistSchedule> list = [];
    list.add(AssistSchedule(
      date: date,
      start: '06:20',
      end: '07:30',
      place: places[idx],
      rolePill: 'Tunanetra',
      personName: tunanetraNames[idx],
    ));
    if (!isWeekend) {
      list.add(AssistSchedule(
        date: date,
        start: '16:30',
        end: '17:45',
        place: places[(idx + 1) % places.length],
        rolePill: 'Relawan',
        personName: relawanNames[idx],
      ));
    }
    return list;
  }

  late final StreamSubscription<SosPayload>? _sosSub;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _initUserThenNotifications();
    // HAPUS baris ini:
    // _sosSub = SosBus.stream.listen((p) { if (mounted) _showIncomingSos(p); });
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    super.dispose();
  }

  // << TAMBAH: buka Google Maps (opsional, masih disimpan bila perlu)
  Future<void> _openMaps({double? lat, double? lng, String address = ''}) async {
    Uri uri;
    if (lat != null && lng != null) {
      final q = Uri.encodeComponent(address.isEmpty ? '$lat,$lng' : address);
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&q=$q');
    } else {
      final q = Uri.encodeComponent(address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // >>> ADDED: izin & lokasi sekarang
  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location service dimatikan. Aktifkan dulu.')),
      );
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin lokasi ditolak.')),
      );
      return null;
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> _reverseAddress(double lat, double lng) async {
    try {
      final list = await placemarkFromCoordinates(lat, lng);
      if (list.isEmpty) return '';
      final p = list.first;
      final parts = [
        (p.street ?? '').trim(),
        (p.subLocality ?? '').trim(),
        (p.locality ?? '').trim(),
      ].where((e) => e.isNotEmpty).toList();
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }

  // >>> ADDED: composer SOS (khusus Tunanetra)
  void _openSosComposer() {
    final auth = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 14),
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 10),
              const Text('Permintaan Bantuan Segera',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2A3B8E),
                    backgroundImage: (auth?.photoURL != null) ? NetworkImage(auth!.photoURL!) : null,
                    child: (auth?.photoURL == null) ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // role chip
                      _ChipTiny(text: 'Tunanetra'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sos_rounded),
                  label: const Text('Kirim SOS Sekarang', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _sendSos();
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lokasi terkini Anda akan dikirim ke Relawan terdekat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendSos() async {
    if (user?.role != UserRole.tunanetra) return;

    final auth = FirebaseAuth.instance.currentUser;
    final pos = await _getCurrentPosition();
    if (pos == null) return;

    final addr = await _reverseAddress(pos.latitude, pos.longitude);

    await SosBus.sendSos(
      name: user?.name ?? (auth?.displayName ?? 'Tunanetra'),
      role: 'Tunanetra',
      address: addr,
      lat: pos.latitude,
      lng: pos.longitude,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS dikirim. Menunggu Relawan…')),
    );
  }

  // >>> ADDED: pop-out masuk untuk Relawan + ke MapsPageScreen
  void _showIncomingSos(SosPayload p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 12),
              const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 8),
              const Text(
                'Permintaan Bantuan Segera',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF2A3B8E),
                    backgroundImage: (p.photoUrl != null) ? NetworkImage(p.photoUrl!) : null,
                    child: (p.photoUrl == null) ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ChipTiny(text: p.role),
                      const SizedBox(height: 4),
                      Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                (p.address.isEmpty && p.lat != null && p.lng != null)
                    ? '${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}'
                    : (p.address.isEmpty ? 'Lokasi tidak diketahui' : p.address),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.location_pin),
                  label: const Text('Arahkan Lokasi', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openMapsPage(p);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMapsPage(SosPayload p) {
    if (p.lat == null || p.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi pengirim tidak tersedia.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapsPageScreen(
          targetLat: p.lat!,
          targetLng: p.lng!,
          targetName: p.name,
          targetAddress: p.address,
        ),
      ),
    );
  }

  Future<void> _initUserThenNotifications() async {
    final u = FirebaseAuth.instance.currentUser;

    String name = (u?.displayName ?? '').trim();
    if (name.isEmpty) {
      final email = (u?.email ?? '').trim();
      name = email.isNotEmpty ? email.split('@').first : 'User';
    }

    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    final roleStr = prefs.getString(roleKey) ?? 'relawan';
    final role = roleStr == 'tunanetra' ? UserRole.tunanetra : UserRole.relawan;
    user = UserProfile(name: name, role: role, level: 0, xp: 0);

    if (user?.role == UserRole.relawan) {
      // Dengarkan event SOS hanya untuk Relawan
      _sosSub = SosBus.stream.listen((p) {
        if (mounted) _showIncomingSos(p);
      });

      // Pastikan perangkat Relawan berlangganan topik 'sos'
      try {
        await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
        await FirebaseMessaging.instance.subscribeToTopic('sos');
      } catch (_) {}
    }

    // load & sanitize quick features
    final loaded = prefs.getStringList(_quickKey);
    if (loaded == null || loaded.isEmpty) {
      _quickIds = List<String>.from(_defaultQuickIds);
      await prefs.setStringList(_quickKey, _quickIds);
    } else {
      final cleaned = _sanitizeQuick(loaded);
      _quickIds = cleaned.isEmpty ? List<String>.from(_defaultQuickIds) : cleaned;
      if (cleaned.length != loaded.length) {
        await prefs.setStringList(_quickKey, _quickIds);
      }
    }

    if (mounted) setState(() {});
  }

  void _pickSessions() {}

  Future<void> _openMonthCalendar() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MonthCalendarSheet(initial: selectedDate),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // ⬇️ gunakan sheet reusable dari runara_header.dart
  // AFTER (cukup panggil helper dari header):
  Future<void> _openNotifications() async {
    await RunaraNotificationCenter.open(context);
    if (mounted) setState(() {}); // refresh badge kalau ada perubahan
  }

  // ======== state untuk Icon Navigation (aktif index) — 0 = "Semua"
  int _activeIconIndex = 0;

  void _openFeature(FeatureDef f) {
    switch (f.id) {
      case 'matchmaking':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CariPendampingPageScreen()),
        );
        break;
      case 'help':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BantuanPageScreen()),
        );
        break;
      case 'messages':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PesanPageScreen()),
        );
        break;
      case 'tips':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TipsPageScreen()),
        );
        break;
      case 'donation':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DonasiPageScreen()),
        );
        break;

      case 'history':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RiwayatAktivitasPageScreen()),
        );
        break;

      case 'settings':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPageScreen()),
        );
        break;

    // >>> ADDED: SOS hanya untuk Tunanetra
      case 'sos':
        if (user?.role == UserRole.tunanetra) {
          _openSosComposer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hanya Tunanetra yang bisa mengirim SOS.')),
          );
        }
        break;

    // Contoh lain (kalau nanti ada halamannya):
    // case 'messages': Navigator.pushNamed(context, '/messages'); break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fitur ${f.label.replaceAll('\n', ' ')} belum tersedia.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 900),
          ),
        );
    }
  }

  // ======== handler tombol Ubah di kanan "Fitur Runara"
  Future<void> _onEditFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cfBg,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CustomizeFeaturesSheet(
        initialSelected: _quickIds,
        maxSelected: _maxQuick,
      ),
    );

    if (saved != null) {
      final cleaned = _sanitizeQuick(saved); // SANITIZE sebelum simpan
      await prefs.setStringList(_quickKey, cleaned);
      setState(() {
        _quickIds = cleaned;
        final totalCount = 1 + _quickIds.length; // +1 karena "Semua" selalu ada
        if (_activeIconIndex >= totalCount) _activeIconIndex = 0;
      });
    }
  }

  // ======== POP-OUT: Semua Fitur (setengah layar)
  void _openAllFeatures() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.55,
        child: _AllFeaturesSheet(
          features: kAllFeatures,
          onTap: (f) {
            Navigator.pop(ctx);
            Future.microtask(() => _openFeature(f));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kcalText = formatKcal(totalCalories);
    final kmText = formatKm(totalDistance);
    final u = user;
    final auth = FirebaseAuth.instance.currentUser;

    // map id -> FeatureDef (pertahankan urutan _quickIds)
    List<FeatureDef> _mapIdsToFeatures(List<String> ids) {
      final out = <FeatureDef>[];
      for (final id in ids) {
        final idx = kAllFeatures.indexWhere((f) => f.id == id);
        if (idx != -1) out.add(kAllFeatures[idx]);
      }
      return out;
    }

    final selectedFeatures = _mapIdsToFeatures(_quickIds);
    int navActive = _activeIconIndex;
    final totalCount = 1 + selectedFeatures.length; // +1 untuk "Semua"
    if (navActive >= totalCount) navActive = 0;

    // Judul dinamis: Hari ini vs tanggal terpilih
    final bool today = isSameDay(selectedDate, DateTime.now());
    final String scheduleTitle =
    today ? 'Jadwal Pendampingan Hari Ini' : 'Jadwal Pendampingan • ${formatDateId(selectedDate)}';

    // Ambil jadwal untuk tanggal terpilih
    final schedules = _schedulesFor(selectedDate);

    return Scaffold(
      backgroundColor: _bgBlue,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg_space.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // ===== Header seragam via wrapper (pakai runara_header.dart)
                SliverToBoxAdapter(
                  child: RunaraHeaderSection(
                    greeting: runaraGreetingIndo(DateTime.now()),
                    emoji: runaraGreetingEmoji(DateTime.now()),
                    userName: u?.name ?? '—',
                    roleLabel: u?.roleLabel ?? 'Relawan',
                    level: u?.shownLevel ?? 0,
                    progress: u?.progress ?? 0,
                    hasUnread: _hasUnread,
                    onTapBell: _openNotifications,
                    photoUrl: auth?.photoURL, // ✅ ini yang pakai foto akun
                  ),
                ),

                // ===== Section title + tombol Ubah
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Fitur Runara',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _onEditFeatures,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.edit_outlined, size: 16),
                              SizedBox(width: 6),
                              Text('Ubah'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== Icon Navigation (Semua + DINAMIS)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    child: _FeatureIconNav(
                      features: selectedFeatures,
                      activeIndex: navActive,
                      onTap: (i) {
                        if (i == 0) {
                          _openAllFeatures();                 // buka sheet "Semua"
                        } else {
                          _openFeature(selectedFeatures[i - 1]); // langsung navigate sesuai fitur
                        }
                      },
                    ),
                  ),
                ),

                // ===== Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _StatsRow(kcalText: kcalText, kmText: kmText),
                  ),
                ),

                // ===== Info cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _TwoInfoCards(
                      onTapSchedule: _pickSessions,
                      scheduleSubtitle: '$sessionsPerWeek sesi/minggu',
                    ),
                  ),
                ),

                // ====== Jadwal ======
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: _ScheduleHeaderRow(
                      titleText: scheduleTitle,
                      onTapCalendar: _openMonthCalendar,
                    ),
                  ),
                ),

                // Date scroller: BLOK 5 HARI
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _FiveDayScroller(
                      selected: selectedDate,
                      onSelect: (d) => setState(() => selectedDate = d),
                    ),
                  ),
                ),

                // ==== render semua jadwal utk tanggal terpilih ====
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (schedules.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            alignment: Alignment.center,
                            child: const Text(
                              'Tidak ada jadwal.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        for (final s in schedules) ...[
                          _ScheduleCardNew(start: s.start, end: s.end, place: s.place),
                          const SizedBox(height: 12),
                          _PartnerCardRail(
                            rolePill: s.rolePill,
                            name: s.personName,
                            buttonDisabledText: 'Pantau lokasi',
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
              ],
            ),
          ),
        ],
      ),

      // === Bottom Nav tipis (RunaraThinNav)
      bottomNavigationBar: const RunaraThinNav(current: AppTab.home),
    );
  }
}

/* ====== sisa class & widget di bawah ini tidak terkait header,
   dipertahankan apa adanya ====== */

class _FeatureIconNav extends StatelessWidget {
  final List<FeatureDef> features; // List of dynamic features
  final int activeIndex;           // The active index (0 = "Semua")
  final ValueChanged<int> onTap;   // The onTap callback

  const _FeatureIconNav({
    required this.features,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // "Semua" (tetap ada)
        _IconTile(
          label: 'Semua',
          isActive: activeIndex == 0,
          offsetY: -2, // if you want to align with other tiles, change it to -7
          child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 28),
          onTap: () => onTap(0), // Call onTap with index 0 for "Semua"
        ),

        // Dynamic feature tiles
        for (int i = 0; i < features.length; i++)
          _IconTile(
            label: features[i].label,
            isActive: activeIndex == i + 1,
            offsetY: -7, // Keeping consistent offset for dynamic features
            child: features[i].mono != null
                ? Text(
              features[i].mono!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            )
                : Icon(features[i].icon ?? Icons.circle, color: Colors.white, size: 28),
            onTap: () => onTap(i + 1), // Pass the feature index here
          ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final String label;
  final bool isActive;
  final Widget child;
  final double offsetY; // offset vertikal tile (negatif = naik)
  final VoidCallback onTap;

  const _IconTile({
    required this.label,
    required this.isActive,
    required this.child,
    this.offsetY = 0,
    required this.onTap,
  });

  static const double _labelBoxHeight = 30; // 2 baris @ fontSize 12, height 1.25

  @override
  Widget build(BuildContext context) {
    final Color bg = isActive ? _navActive : _navIdle;
    final Color textColor = isActive ? Colors.white : _navLabelIdle;

    return SizedBox(
      width: 64, // w-16
      child: Transform.translate(
        offset: Offset(0, offsetY),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kotak ikon tetap 64x64 — tidak berubah
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
            const SizedBox(height: 8),
            // Label dikunci tingginya supaya 1/2 baris tidak mengubah layout
            SizedBox(
              height: _labelBoxHeight,
              child: Center(
                child: Text(
                  label,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900, // Inter 700 ~ tebal
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================================
   KUSTOMISASI FITUR — Bottom Sheet (tanpa status bar dekoratif)
   ========================================================================= */

class _CustomizeFeaturesSheet extends StatefulWidget {
  final List<String> initialSelected;
  final int maxSelected;
  const _CustomizeFeaturesSheet({
    required this.initialSelected,
    required this.maxSelected,
  });

  @override
  State<_CustomizeFeaturesSheet> createState() => _CustomizeFeaturesSheetState();
}

class _CustomizeFeaturesSheetState extends State<_CustomizeFeaturesSheet> {
  late List<String> _selected; // prioritas
  List<FeatureDef> get _all => kAllFeatures; // tidak ada "Semua" di sini

  @override
  void initState() {
    super.initState();
    // SANITIZE initialSelected (hapus id tak dikenal/duplikat dan batasi max)
    final seen = <String>{};
    _selected = widget.initialSelected.where((id) {
      final exists = _all.any((f) => f.id == id);
      if (!exists) return false;
      if (seen.contains(id)) return false;
      if (seen.length >= widget.maxSelected) return false;
      seen.add(id);
      return true;
    }).toList();
  }

  void _toggleAdd(String id) {
    if (_selected.contains(id)) return;
    if (_selected.length >= widget.maxSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maksimal ${widget.maxSelected} fitur prioritas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _selected.add(id));
  }

  void _remove(String id) {
    setState(() => _selected.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    // fitur non-prioritas
    final nonSelected = _all.where((f) => !_selected.contains(f.id)).toList();

    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 64, height: 6,
                decoration: BoxDecoration(color: _cfBadge, borderRadius: BorderRadius.circular(999)),
              ),
              const SizedBox(height: 14),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const Text('Kustomisasi Fitur',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                    const SizedBox(height: 8),
                    const Text('Ketuk untuk memindahkan. Maks 4 di bagian Prioritas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _cfTextSubtle, fontSize: 13)),
                    const SizedBox(height: 20),

                    // PRIORITAS
                    Row(
                      children: const [
                        Text('Prioritas (tampil di Home)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _cfBadge),
                        borderRadius: BorderRadius.circular(12),
                        color: _cfBg,
                      ),
                      child: _selected.isEmpty
                          ? const Center(
                        child: Text('Belum ada fitur prioritas', style: TextStyle(color: _cfTextSubtle, fontSize: 13)),
                      )
                          : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _selected
                            .where((id) => _all.any((e) => e.id == id))
                            .map((id) {
                          final f = _all.firstWhere((e) => e.id == id,
                              orElse: () => FeatureDef(id: id, label: id));
                          return _PrioritySquare(
                            feature: f,
                            onRemove: () => _remove(id),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // NON-PRIORITAS
                    Row(
                      children: const [
                        Text('Non-Prioritas',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: nonSelected.map((f) {
                        return _AddSquare(
                          feature: f,
                          onAdd: () => _toggleAdd(f.id),
                        );
                      }).toList(),
                    ),

                    // Footer buttons
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _selected.clear()),
                          child: const Text('Reset', style: TextStyle(color: _cfReset, fontSize: 14)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, _selected);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cfPrimary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          child: const Text('Simpan'),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureDef {
  final String id;
  final String label;       // gunakan \n untuk dua baris
  final IconData? icon;
  final String? mono;       // bila ingin menampilkan teks besar "SOS"
  const FeatureDef({required this.id, required this.label, this.icon, this.mono});
}

// === Semua fitur yang dapat dipilih di kustomisasi (TANPA "Semua")
const List<FeatureDef> kAllFeatures = [
  FeatureDef(id: 'matchmaking', label: 'Cari\nPendamping', icon: Icons.handshake_outlined),
  FeatureDef(id: 'messages',    label: 'Pesan',               icon: Icons.chat_bubble_outline),
  FeatureDef(id: 'tips',        label: 'Tips',                icon: Icons.lightbulb_outline),
  FeatureDef(id: 'donation',    label: 'Donasi',              icon: Icons.volunteer_activism_outlined),
  FeatureDef(id: 'help',        label: 'Bantuan',             icon: Icons.help_outline),
  FeatureDef(id: 'history',     label: 'Riwayat\nAktivitas',  icon: Icons.receipt_long_outlined),
  FeatureDef(id: 'sos',         label: 'Permintaan\nBantuan', mono: 'SOS'),
  FeatureDef(id: 'settings',    label: 'Pengaturan',          icon: Icons.settings_outlined),
];

class _AddSquare extends StatelessWidget {
  final FeatureDef feature;
  final VoidCallback onAdd;
  const _AddSquare({required this.feature, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: _cfTile,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(
                  color: _cfBadge,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: const Text('+', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (feature.mono != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(feature.mono!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Icon(feature.icon ?? Icons.circle, color: Colors.white, size: 22),
                      ),
                    Text(
                      feature.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySquare extends StatelessWidget {
  final FeatureDef feature;
  final VoidCallback onRemove;
  const _PrioritySquare({required this.feature, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _cfTile,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: _cfBadge,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: const Text('–', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (feature.mono != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(feature.mono!, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Icon(feature.icon ?? Icons.circle, color: Colors.white, size: 20),
                      ),
                    Text(
                      feature.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.05, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================================
   UI PIECES LAIN
   ========================================================================= */

class _StatsRow extends StatelessWidget {
  final String kcalText;
  final String kmText;
  const _StatsRow({required this.kcalText, required this.kmText});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department,
            label: 'Total Calories',
            value: kcalText,
            valueColor: Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.route_rounded,
            label: 'Total Distance',
            value: kmText,
            valueColor: Colors.lightBlueAccent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _subtle, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: value == '–' ? Colors.white54 : valueColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TwoInfoCards extends StatelessWidget {
  final VoidCallback onTapSchedule;
  final String scheduleSubtitle;
  const _TwoInfoCards({
    required this.onTapSchedule,
    required this.scheduleSubtitle,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: _InfoCard(
            bg: Color(0xFFBFC8FF),
            tint: Color(0xFF6C79FF),
            title: 'Jumlah Tunanetra\nTerkoneksi',
            subtitle: '8 Orang',
            icon: Icons.group_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoCard(
            bg: Color(0xFFFFD59A),
            tint: Color(0xFFFF9E1B),
            title: 'Jadwal\nPendampingan',
            subtitle: '',
            icon: Icons.calendar_month_rounded,
            dynamicSubtitle: null,
            onTap: null,
          ).copyWith(
            onTap: onTapSchedule,
            dynamicSubtitle: scheduleSubtitle,
          ),
        ),
      ],
    );
  }
}

extension _InfoCardCopy on _InfoCard {
  _InfoCard copyWith({
    Color? bg,
    Color? tint,
    String? title,
    String? subtitle,
    IconData? icon,
    VoidCallback? onTap,
    String? dynamicSubtitle,
  }) =>
      _InfoCard(
        bg: bg ?? this.bg,
        tint: tint ?? this.tint,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        icon: icon ?? this.icon,
        onTap: onTap ?? this.onTap,
        dynamicSubtitle: dynamicSubtitle ?? this.dynamicSubtitle,
      );
}

class _InfoCard extends StatelessWidget {
  final Color bg;
  final Color tint;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? dynamicSubtitle;
  const _InfoCard({
    required this.bg,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.dynamicSubtitle,
  });
  @override
  Widget build(BuildContext context) {
    final sub = dynamicSubtitle ?? subtitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tint.withOpacity(.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: tint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: tint.withOpacity(.9),
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                sub,
                style: TextStyle(
                  color: tint.withOpacity(.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* ===================== HEADER ROW (Jadwal) ===================== */
class _ScheduleHeaderRow extends StatelessWidget {
  final String titleText;
  final VoidCallback onTapCalendar;
  const _ScheduleHeaderRow({required this.titleText, required this.onTapCalendar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titleText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Kalender',
          onPressed: onTapCalendar,
          icon: const Icon(Icons.calendar_today_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

/* ===================== DATE SCROLLER: blok 5 hari ===================== */
class _FiveDayScroller extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const _FiveDayScroller({required this.selected, required this.onSelect});

  static int _daysInMonth(DateTime d) => DateUtils.getDaysInMonth(d.year, d.month);

  static DateTime _prevBlock(DateTime sel) {
    final blockStart = ((sel.day - 1) ~/ 5) * 5 + 1; // 1,6,11,16,21,26
    final prevStart = blockStart - 5;
    if (prevStart >= 1) return DateTime(sel.year, sel.month, prevStart);

    // mundur ke bulan sebelumnya, blok terakhir
    final prevMonth = DateTime(sel.year, sel.month - 1, 1);
    final dim = _daysInMonth(prevMonth);
    final lastStart = ((dim - 1) ~/ 5) * 5 + 1;
    return DateTime(prevMonth.year, prevMonth.month, lastStart);
  }

  static DateTime _nextBlock(DateTime sel) {
    final dim = _daysInMonth(sel);
    final blockStart = ((sel.day - 1) ~/ 5) * 5 + 1;
    final nextStart = blockStart + 5;
    if (nextStart <= dim) return DateTime(sel.year, sel.month, nextStart);

    // maju ke bulan berikutnya, blok pertama (1-5)
    final nextMonth = DateTime(sel.year, sel.month + 1, 1);
    return DateTime(nextMonth.year, nextMonth.month, 1);
  }

  String _wk(int w) {
    const m = {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'};
    return m[w]!;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dim = _daysInMonth(selected);
    final start = ((selected.day - 1) ~/ 5) * 5 + 1;
    final endDay = (start + 4 <= dim) ? start + 4 : dim;

    final days = List<DateTime>.generate(
      endDay - start + 1,
          (i) => DateTime(selected.year, selected.month, start + i),
    );

    return Row(
      children: [
        _RoundIconBtn(icon: Icons.chevron_left, onTap: () => onSelect(_prevBlock(selected))),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days.map((d) {
                final isSelected = d.year == selected.year &&
                    d.month == selected.month &&
                    d.day == selected.day;
                final isToday = isSameDay(d, now);

                // Biru = tanggal realtime (persisten), Oranye = tanggal dipilih (kecuali hari ini)
                Color? bg;
                if (isToday) {
                  bg = _scBlue;
                } else if (isSelected) {
                  bg = _scOrange;
                }

                // Teks putih di biru/transparan, hitam di oranye (sesuai HTML)
                final Color textColor = (bg == _scOrange) ? Colors.black : Colors.white;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _DayChipBtn(
                    weekday: _wk(d.weekday),
                    day: d.day,
                    bg: bg,
                    textColor: textColor,
                    // titik putih JANGAN muncul pada tanggal realtime
                    showWhiteDot: isSelected && !isToday,
                    onTap: () => onSelect(d),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RoundIconBtn(icon: Icons.chevron_right, onTap: () => onSelect(_nextBlock(selected))),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(.3)),
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: Colors.white.withOpacity(.9)),
      ),
    );
  }
}

class _DayChipBtn extends StatelessWidget {
  final String weekday;
  final int day;
  final Color? bg;
  final Color textColor;
  final bool showWhiteDot;
  final VoidCallback onTap;

  const _DayChipBtn({
    required this.weekday,
    required this.day,
    required this.bg,
    required this.textColor,
    required this.showWhiteDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bg ?? Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showWhiteDot)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(weekday, style: TextStyle(color: textColor, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '$day',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

/* ===================== SCHEDULE CARD (HTML-like) ===================== */
class _ScheduleCardNew extends StatelessWidget {
  final String start, end, place;
  const _ScheduleCardNew({required this.start, required this.end, required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _scCard, borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _scInner, borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.directions_walk_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.access_time, size: 16, color: Colors.white.withOpacity(.7)),
                  const SizedBox(width: 6),
                  Text(start, style: const TextStyle(
                      color: _scOrange, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text(end, style: TextStyle(
                      color: Colors.white.withOpacity(.7), fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.place_rounded, size: 16, color: Colors.white.withOpacity(.7)),
                  const SizedBox(width: 6),
                  Text(place, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ===================== PARTNER CARD + RAIL (HTML-like) ===================== */
class _PartnerCardRail extends StatelessWidget {
  final String rolePill;
  final String name;
  final String buttonDisabledText;
  const _PartnerCardRail({
    required this.rolePill,
    required this.name,
    required this.buttonDisabledText,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // vertical rail di luar kartu
        Positioned.fill(
          left: 0, right: null,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(left: 2),
              width: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        // card
        Container(
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: _scCard, borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  color: _scInner, shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _scInner, borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        rolePill,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: .5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _scInner, borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          buttonDisabledText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* =========================================================================
   BOTTOM SHEET KALENDER (bulan penuh untuk pilih tanggal)
   ========================================================================= */
class _MonthCalendarSheet extends StatefulWidget {
  final DateTime initial;
  const _MonthCalendarSheet({required this.initial});
  @override
  State<_MonthCalendarSheet> createState() => _MonthCalendarSheetState();
}

class _MonthCalendarSheetState extends State<_MonthCalendarSheet> {
  late DateTime _cursor;
  double _calendarPosition = 0.0;
  final DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.initial.year, widget.initial.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final daysInMonth = DateUtils.getDaysInMonth(_cursor.year, _cursor.month);
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday;
    final leadingEmpty = (firstWeekday - 1) % 7;

    return SafeArea(
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() => _calendarPosition += details.primaryDelta ?? 0);
        },
        onVerticalDragEnd: (_) {
          if (_calendarPosition > 50) {
            setState(() => _cursor = DateTime(_cursor.year, _cursor.month + 1, 1));
          } else if (_calendarPosition < -50) {
            setState(() => _cursor = DateTime(_cursor.year, _cursor.month - 1, 1));
          }
          setState(() => _calendarPosition = 0.0);
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _cursor = DateTime(_cursor.year, _cursor.month - 1, 1)),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "${_getMonthName(_cursor.month)} ${_cursor.year}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _cursor = DateTime(_cursor.year, _cursor.month + 1, 1)),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: leadingEmpty + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingEmpty) return const SizedBox.shrink();
                      final day = index - leadingEmpty + 1;
                      final date = DateTime(_cursor.year, _cursor.month, day);
                      final isSelected = isSameDay(date, currentDate);

                      return InkWell(
                        onTap: () => Navigator.pop(context, date),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orangeAccent : _cardBlue,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return months[month - 1];
  }
}

class Dow extends StatelessWidget {
  final String t;
  const Dow(this.t);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(t, style: const TextStyle(color: _subtle, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/* =========================================================================
   SHEET: SEMUA FITUR (setengah layar) — anti overflow
   ========================================================================= */
class _AllFeaturesSheet extends StatelessWidget {
  final List<FeatureDef> features;
  final ValueChanged<FeatureDef> onTap;

  const _AllFeaturesSheet({required this.features, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Semua Fitur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: features.length,
            itemBuilder: (context, i) {
              final feature = features[i];
              return _AllFeatureTile(
                feature: feature,
                onTap: () => onTap(feature),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AllFeatureTile extends StatelessWidget {
  final FeatureDef feature;
  final VoidCallback onTap;
  const _AllFeatureTile({required this.feature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _allTileBg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (feature.mono != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  feature.mono!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Icon(feature.icon, color: Colors.white, size: 22),
              ),
            // Label anti-overflow
            SizedBox(
              height: 28,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  feature.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== util kecil untuk chip role =====
class _ChipTiny extends StatelessWidget {
  final String text;
  const _ChipTiny({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF2A3B8E), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
