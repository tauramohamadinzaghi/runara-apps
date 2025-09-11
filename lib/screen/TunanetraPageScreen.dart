import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// widgets reusable
import 'widget/runara_thin_nav.dart';
import 'widget/runara_header.dart'; // RunaraHeaderSection, RunaraNotificationSheet, AppNotification

/// ===== Palette (samakan dg Home) =====
const _bgBlue   = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue  = Color(0xFF0E1E44);
const _accent   = Color(0xFF9AA6FF);
const _subtle   = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF3A4C86);

class TunanetraPageScreen extends StatefulWidget {
  const TunanetraPageScreen({super.key});

  @override
  State<TunanetraPageScreen> createState() => _TunanetraPageScreenState();
}

class _TunanetraPageScreenState extends State<TunanetraPageScreen> {
  // data untuk header
  String _name = '—';
  String _roleLabel = 'Relawan';
  int _level = 0;
  double _progress = 0.0;

  // notifikasi
  final List<AppNotification> _notifs = [];
  bool get _hasUnread => _notifs.any((n) => !n.read);

  @override
  void initState() {
    super.initState();
    _initHeaderData();
    _seedDemoNotifications();
  }

  Future<void> _initHeaderData() async {
    final u = FirebaseAuth.instance.currentUser;
    var name = (u?.displayName ?? '').trim();
    if (name.isEmpty) {
      final email = (u?.email ?? '').trim();
      name = email.isNotEmpty ? email.split('@').first : 'User';
    }

    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    final roleStr = prefs.getString(roleKey) ?? 'relawan';

    setState(() {
      _name = name;
      _roleLabel = roleStr == 'tunanetra' ? 'Tunanetra' : 'Relawan';
      _level = 0;
      _progress = 0; // isi sesuai progress nyata jika sudah ada
    });
  }

  void _seedDemoNotifications() {
    if (_notifs.isEmpty) {
      _notifs.addAll([
        AppNotification(
          title: 'Tips Hari Ini 💡',
          body: 'Coba pemanasan 5 menit sebelum berlari.',
          time: DateTime.now().subtract(const Duration(hours: 2)),
          read: true,
        ),
        AppNotification(
          title: 'Jadwal Mendatang',
          body: 'Pendampingan Jumat 06:20 di GBK. Siapkan perlengkapan ya!',
          time: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
          read: false,
        ),
      ]);
    }
  }

  Future<void> _openNotifications() async {
    final changed = await RunaraNotificationSheet.show(
      context,
      notifs: _notifs,
      onMarkAllRead: () {
        for (final n in _notifs) n.read = true;
      },
      onTapItem: (i) => _notifs[i].read = true,
    );
    if (changed == true && mounted) setState(() {});
  }

  String _greetingIndo(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 11) return 'Selamat pagi';
    if (h >= 11 && h < 15) return 'Selamat siang';
    if (h >= 15 && h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  String _greetingEmoji(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 11) return '☀️';
    if (h >= 11 && h < 15) return '🌤️';
    if (h >= 15 && h < 18) return '🌇';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
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
                // === HEADER reusable (padding & tinggi seragam lewat Section)
                SliverToBoxAdapter(
                  child: RunaraHeaderSection(
                    greeting: _greetingIndo(DateTime.now()),
                    emoji: _greetingEmoji(DateTime.now()),
                    userName: _name,
                    roleLabel: _roleLabel,
                    level: _level,
                    progress: _progress,
                    hasUnread: _hasUnread,
                    onTapBell: _openNotifications,
                  ),
                ),

                // === LIST (pakai SliverList supaya nggak nested scroll)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                  sliver: SliverList.builder(
                    itemCount: 4 * 2 - 1, // item + separator
                    itemBuilder: (_, i) {
                      if (i.isOdd) return const SizedBox(height: 10);
                      final idx = i ~/ 2;
                      return const _TunaCard(
                        name: 'Aldy Giovani',
                        dateText: '16/05/2025',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const RunaraThinNav(current: AppTab.tunanetra),
    );
  }
}

/* ====================== LIST CARD ======================= */

class _TunaCard extends StatelessWidget {
  final String name;
  final String dateText;
  const _TunaCard({required this.name, required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _cardBlue, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF283456),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tunanetra',
                      style: TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Terkoneksi',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.75),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dateText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.9),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilledBtn(
                  color: const Color(0xFF8B8FEA),
                  icon: Icons.location_on_rounded,
                  label: 'Pantau lokasi',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilledBtn(
                  color: const Color(0xFFFF9B2F),
                  icon: Icons.calendar_month_rounded,
                  label: 'Jadwal',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FilledBtn({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
