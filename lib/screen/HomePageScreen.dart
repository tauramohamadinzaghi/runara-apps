// lib/screen/HomePageScreen.dart
import 'package:apps_runara/screen/MapsPageScreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ChooseRoleScreen.dart';

import 'TunanetraPageScreen.dart';
import 'auth_service.dart';

/// =================== PALETTE ===================
const _bgBlue = Color(0xFF0D1B3D);
const _cardBlue = Color(0xFF152449);
const _navBlue = Color(0xFF0E1E44);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF22315E);
const _divider = Color(0xFF2A3C6C);

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
  int _selectedIndex = 0;

  // Function to navigate based on the tab selected
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate to different screens based on index
    if (index == 1) {
      // If the "Tunanetra" tab is selected, navigate to TunanetraPageScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TunanetraPageScreen()),
      );
    }
    // You can add more navigation logic for other tabs (like Home, Maps, etc.)
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
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

String greetingIndo(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return 'Selamat pagi';
  if (h >= 11 && h < 15) return 'Selamat siang';
  if (h >= 15 && h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

String greetingEmoji(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return '☀️';
  if (h >= 11 && h < 15) return '🌤️';
  if (h >= 15 && h < 18) return '🌇';
  return '🌙';
}

String formatKcal(double v) => v <= 0 ? '–' : '${v.toStringAsFixed(0)} Kcal';
String formatKm(double v) => v <= 0 ? '–' : '${v.toStringAsFixed(1)} Km';

DateTime startOfWeek(DateTime d) {
  // 1 = Mon ... 7 = Sun → balik ke Senin
  final wd = d.weekday;
  final onlyDate = DateTime(d.year, d.month, d.day);
  return onlyDate.subtract(Duration(days: wd - 1));
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;


/// =================== NOTIF MODEL ===================
class AppNotification {
  final String title;
  final String body;
  final DateTime time;
  bool read;
  AppNotification({
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  UserProfile? user;                  // ⬅️ nullable biar aman
  double totalCalories = 0;
  double totalDistance = 0;
  int sessionsPerWeek = 2;
  DateTime selectedDate = DateTime.now();

  final List<AppNotification> _notifs = [];
  bool get _hasUnread => _notifs.any((n) => !n.read);

  late DateTime _stripStart; // anchor awal minggu (Senin)
  // di dalam _HomePageState
  static const _quickKey = 'quick_priority_ids';
  static const _maxQuick = 4;
// default 4 fitur (boleh kamu ubah)
  static const List<String> _defaultQuickIds = ['find', 'activity', 'sos', 'settings'];

  List<String> _quickIds = []; // id fitur yg tampil di baris Home (selain "All")

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _stripStart = _startOfWeek(selectedDate);
    _initUserThenNotifications();
  }


  /// Senin sebagai awal minggu
  DateTime _startOfWeek(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: base.weekday - DateTime.monday));
  }

  Future<void> _initUserThenNotifications() async {
    final u = FirebaseAuth.instance.currentUser;

    // nama yang ditampilkan
    String name = (u?.displayName ?? '').trim();
    if (name.isEmpty) {
      final email = (u?.email ?? '').trim();
      name = email.isNotEmpty ? email.split('@').first : 'User';
    }

    // ambil role dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    final roleStr = prefs.getString(roleKey) ?? 'relawan';
    final role = roleStr == 'tunanetra' ? UserRole.tunanetra : UserRole.relawan;
    user = UserProfile(name: name, role: role, level: 0, xp: 0);

    // === Welcome hanya 1x untuk user baru ===
    final seenKey = 'seen_welcome_${u?.uid ?? 'local'}';
    final meta = u?.metadata;
    final isNewSignUp = meta != null &&
        meta.creationTime != null &&
        meta.lastSignInTime != null &&
        meta.creationTime!.millisecondsSinceEpoch ==
            meta.lastSignInTime!.millisecondsSinceEpoch;

    if (isNewSignUp && !(prefs.getBool(seenKey) ?? false)) {
      _notifs.add(AppNotification(
        title: 'Selamat datang 🎉',
        body: 'Halo $name, terima kasih telah bergabung di RUNARA. Yuk eksplor fitur dan mulai terhubung!',
        time: DateTime.now(),
        read: false,
      ));
      await prefs.setBool(seenKey, true);
    }

    // Contoh notif lain (biar nggak kosong)
    _seedDemoNotifications();

    if (mounted) setState(() {});
  }

// beberapa notif contoh (boleh kamu ganti/hapus nanti)
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
        AppNotification(
          title: 'Misi Selesai ✅',
          body: 'Kamu menyelesaikan 3 sesi minggu ini. Mantap! +30 XP',
          time: DateTime.now().subtract(const Duration(days: 2)),
          read: true,
        ),
      ]);
    }
  }


  void _pickSessions() async { /* ... punyamu ... */ }
  Future<void> _openMonthCalendar() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MonthCalendarSheet(
        initial: selectedDate,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
        _stripStart = _startOfWeek(picked); // sync strip ke minggu tanggal terpilih
      });
    }
  }

  void _simulateMissionDone() => setState(() => user?.addXp(30));

  Future<void> _openNotifications() async {
    // buka bottom sheet dan tunggu closed; return true kalau ada perubahan
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NotificationSheet(
        notifs: _notifs,
        onMarkAllRead: () {
          for (final n in _notifs) { n.read = true; }
        },
        onTapItem: (i) {
          _notifs[i].read = true;
        },
      ),
    );

    if (changed == true && mounted) setState(() {}); // refresh titik merah
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final kcalText = formatKcal(totalCalories);
    final kmText = formatKm(totalDistance);
    final u = user;

    return Scaffold(
      backgroundColor: _bgBlue,
      body: Stack(
        children: [
          // background
          Positioned.fill(
            child: Image.asset(
              'assets/bg_space.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // content
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // ======= Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad > 0 ? 8 : 16, 20, 12),
                    child: _Header(
                      greeting: greetingIndo(DateTime.now()),
                      emoji: greetingEmoji(DateTime.now()),
                      userName: u?.name ?? '—',
                      roleLabel: u?.roleLabel ?? 'Relawan',
                      level: u?.shownLevel ?? 0,
                      progress: u?.progress ?? 0,
                      hasUnread: _hasUnread,
                      onTapBell: _openNotifications,
                    ),
                  ),
                ),

                // ======= Judul "Fitur" + tombol All
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
                      ],
                    ),
                  ),
                ),

                // ======= Stats
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _StatsRow(kcalText: kcalText, kmText: kmText),
                  ),
                ),

                // ======= Info cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _TwoInfoCards(
                      onTapSchedule: _pickSessions,
                      scheduleSubtitle: '$sessionsPerWeek sesi/minggu',
                    ),
                  ),
                ),

                // ======= Jadwal hari ini (judul + ikon kalender)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Jadwal Pendampingan Hari Ini',
                            style: TextStyle(
                              color: Colors.white.withOpacity(.95),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Buka kalender bulan ini',
                          onPressed: _openMonthCalendar,
                          icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // ======= Date strip (selalu 7 hari)
                SliverToBoxAdapter(
                  child: _DateStrip(
                    stripStart: _stripStart,
                    selected: selectedDate,
                    onSelect: (d) {
                      setState(() {
                        selectedDate = d;
                        final last = _stripStart.add(const Duration(days: 6));
                        if (d.isBefore(_stripStart) || d.isAfter(last)) {
                          _stripStart = _startOfWeek(d);
                        }
                      });
                    },
                    onPrevWeek: () => setState(() {
                      _stripStart = _stripStart.subtract(const Duration(days: 7));
                      selectedDate = _stripStart; // opsional: snap ke Senin minggu tsb
                    }),
                    onNextWeek: () => setState(() {
                      _stripStart = _stripStart.add(const Duration(days: 7));
                      selectedDate = _stripStart; // opsional
                    }),
                    onPullDown: _openMonthCalendar, // tarik ke bawah hanya di strip ini
                  ),
                ),

                // ======= Kartu jadwal
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: GestureDetector(
                      onLongPress: _simulateMissionDone,
                      child: const _ScheduleCard(),
                    ),
                  ),
                ),
                // ======= Kartu partner
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 28),
                    child: _PartnerCard(),
                  ),
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 140)), // anti overflow
              ],

            ),
          ),
        ],
      ),

      // bottom nav
      bottomNavigationBar: _BottomNav(
        onTapHome: () {},
        onTapTunanetra: () =>
            Navigator.of(context).pushNamed('/profile', arguments: {'role': 'tunanetra'}),
        onTapMaps: () =>
            Navigator.of(context).pushReplacementNamed('/maps'),
        onTapChat: () => Navigator.of(context).pushNamed('/messages'),
        onTapMore: () => _showMoreSheet(context),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 44, height: 5,
                  decoration: BoxDecoration(color: Colors.white24,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Keluar', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/signin', (_) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllFeaturesSheet(BuildContext context) {}
}

class _NotificationSheet extends StatelessWidget {
  final List<AppNotification> notifs;
  final VoidCallback onMarkAllRead;
  final void Function(int index) onTapItem;

  const _NotificationSheet({
    required this.notifs,
    required this.onMarkAllRead,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.9;
    final hasWelcomeUnread = notifs.any((n) =>
    !n.read && n.title.toLowerCase().contains('selamat datang'));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),

              // header + mark all
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifikasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onMarkAllRead();
                      Navigator.of(context).pop(true); // tutup & minta refresh
                    },
                    child: const Text('Tandai semua dibaca'),
                  ),
                ],
              ),

              // banner welcome (opsional)
              if (hasWelcomeUnread) ...[
                _WelcomeBanner(onTap: () {
                  // contoh aksi: buka halaman fitur
                  Navigator.of(context).pop(true);
                  Navigator.of(context).pushNamed('/features');
                }),
                const SizedBox(height: 10),
              ],

              // daftar notifikasi
              Expanded(
                child: notifs.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Tidak ada notifikasi.',
                        style: TextStyle(color: Colors.white70)),
                  ),
                )
                    : ListView.separated(
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Colors.white12),
                  itemBuilder: (ctx, i) {
                    final n = notifs[i];
                    final icon = n.read
                        ? Icons.notifications_none
                        : Icons.circle_notifications;
                    final color =
                    n.read ? Colors.white60 : _accent;

                    return ListTile(
                      onTap: () {
                        onTapItem(i);               // tandai read
                        Navigator.pop(ctx, true);   // tutup & refresh
                      },
                      leading: Icon(icon, color: color),
                      title: Text(
                        n.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontWeight:
                          n.read ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        n.body,
                        style: const TextStyle(color: _subtle),
                      ),
                      trailing: Text(
                        _fmtTime(n.time),
                        style: const TextStyle(
                            color: _subtle, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}



// Banner cheerfull di atas list
class _WelcomeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _WelcomeBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF5B6CFF), Color(0xFF9AA6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white24,
              child: Text('🎉', style: TextStyle(fontSize: 20)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Selamat datang di RUNARA!\nKetuk untuk melihat semua fitur.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}


/* =========================================================================
   UI PIECES (header, quick actions, stats, cards, nav, dll)
   ========================================================================= */
class _Header extends StatelessWidget {

  final String greeting;
  final String emoji;
  final String userName;
  final String roleLabel;
  final int level;
  final double progress;
  final bool hasUnread;
  final VoidCallback onTapBell;

  const _Header({
    required this.greeting,
    required this.emoji,
    required this.userName,
    required this.roleLabel,
    required this.level,
    required this.progress,
    required this.hasUnread,
    required this.onTapBell,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBlue.withOpacity(.7),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/avatar.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: _divider,
                alignment: Alignment.center,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Greeting & name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // greeting + emoji
                Row(
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.1,
                      ),
                    ),
                    _Badge(text: roleLabel),
                  ],
                ),
                const SizedBox(height: 8),
                // Level progress
                Row(
                  children: [
                    const Icon(Icons.shield_moon, size: 16, color: _subtle),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, c) => Container(
                              height: 8,
                              width: c.maxWidth * progress.clamp(0, 1),
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('LV.$level',
                        style: const TextStyle(
                            color: _subtle, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // bell with badge
          InkWell(
            onTap: onTapBell,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                  const Icon(Icons.notifications_none, color: Colors.white),
                ),
                // ganti Stack kecil di icon lonceng:
                if (hasUnread)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const Text('•', // atau angka jika kamu ikutkan count
                          style: TextStyle(color: Colors.white, fontSize: 12, height: 1)),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A4C86),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Stats
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

/// Two Info Cards
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
            dynamicSubtitle: null, // diganti di bawah
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

class _DateStrip extends StatefulWidget {
  final DateTime stripStart;  // Start of the current week (Monday)
  final DateTime selected;    // Selected date
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPullDown;  // Pull down to open calendar

  const _DateStrip({
    required this.stripStart,
    required this.selected,
    required this.onSelect,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onPullDown,
  });

  @override
  State<_DateStrip> createState() => _DateStripState();
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 28,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _DateStripState extends State<_DateStrip> {
  double _pull = 0;

  late double _calendarPosition; // Track vertical drag for swipe down action

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => widget.stripStart.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            // Adjust position or behavior here based on swipe
            _calendarPosition += details.primaryDelta!;
          });
        },
        onVerticalDragEnd: (_) {
          // Reset or transition smoothly
          setState(() {
            var _calendarPosition = 0;  // or set it to the default position
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: _cardBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _ArrowBtn(icon: Icons.chevron_left, onTap: widget.onPrevWeek),
              const SizedBox(width: 4),
              ...days.map((d) {
                final isToday = _isSameDay(d, DateTime.now());
                final isSelected = _isSameDay(d, widget.selected);
                return Expanded(
                  child: _DayPill(
                    weekday: _weekdayShort(d.weekday),
                    day: d.day,
                    selected: isSelected,
                    isToday: isToday,
                    onTap: () => widget.onSelect(d),
                  ),
                );
              }).toList(),
              const SizedBox(width: 4),
              _ArrowBtn(icon: Icons.chevron_right, onTap: widget.onNextWeek),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayShort(int w) {
    const map = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return map[w]!;
  }
}

class _DayPill extends StatelessWidget {
  final String weekday;
  final int day;
  final bool selected;
  final bool isToday;  // isToday flag to track if it's today's date
  final VoidCallback onTap;

  const _DayPill({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Check if it's the current day
    final isCurrentDay = DateTime.now().day == day &&
        DateTime.now().month == DateTime.now().month &&
        DateTime.now().year == DateTime.now().year;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isCurrentDay
              ? Colors.blueAccent  // Today is highlighted in blue
              : selected
              ? Colors.orange  // Selected date gets orange
              : Colors.transparent, // Default background is transparent
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday, style: const TextStyle(color: _subtle, fontSize: 12)),
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 16,
              backgroundColor: selected || isCurrentDay ? Colors.white : Colors.transparent,
              child: Text(
                '$day',
                style: TextStyle(
                  color: isCurrentDay
                      ? Colors.blueAccent // Today's text is blue
                      : selected
                      ? Colors.white // Selected date text is white
                      : Colors.white, // Default text is white
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekdayShort(int w) {
  // 1=Mon ... 7=Sun
  const map = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
  return map[w]!;
}

class ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const ArrowButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 28,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class DayPillWidget extends StatelessWidget {
  final String weekday;
  final int day;
  final bool selected;
  final VoidCallback onTap;

  const DayPillWidget({super.key,
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _cardBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday, style: const TextStyle(color: _subtle, fontSize: 12)),
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: selected ? Colors.white : Colors.white10,
              child: Text(
                '$day',
                style: TextStyle(
                  color: selected ? _bgBlue : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatePill extends StatelessWidget {
  final String weekday;
  final int day;
  final bool selected;
  const DatePill({super.key, required this.weekday, required this.day, this.selected = false});
  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: Colors.white24, width: 1);
    return Container(
      width: 62,
      decoration: BoxDecoration(
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(weekday, style: const TextStyle(color: _subtle, fontSize: 12)),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: 16,
            backgroundColor: selected ? Colors.white : Colors.white10,
            child: Text(
              '$day',
              style: TextStyle(
                color: selected ? _bgBlue : Colors.blueAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Schedule card
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_run_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: _subtle),
                    SizedBox(width: 6),
                    Text('06:20 ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('07:30', style: TextStyle(color: _subtle)),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: _subtle),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Gelora Bung Karno',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Partner card
class _PartnerCard extends StatelessWidget {
  const _PartnerCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _navBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _divider),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/avatar.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white70),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniTag(text: 'Tunanetra'),
                SizedBox(height: 4),
                Text(
                  'Aldy Giovani',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: TextStyle(fontWeight: FontWeight.w800),
            ),
            icon: Icon(Icons.my_location_rounded, size: 18),
            label: Text('Pantau lokasi'),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  const _MiniTag({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onTapHome, onTapTunanetra, onTapMaps, onTapChat, onTapMore;
  const _BottomNav({
    required this.onTapHome,
    required this.onTapTunanetra,
    required this.onTapMaps,
    required this.onTapChat,
    required this.onTapMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: _navBlue,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: true,
            onTap: onTapHome,
          ),
          _NavButton(
            icon: Icons.groups_2_rounded,
            label: 'Tunanetra',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TunanetraPageScreen()), // Navigate to TunanetraPageScreen
              );
            },
          ),
          _NavButton(
            icon: Icons.map_rounded,
            label: 'Maps',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapsPageScreen()),
              );
            },
          ),
          _NavButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Hubungkan',
            onTap: () {
              // Implement navigation for Hubungkan if needed
            },
          ),
          _NavButton(
            icon: Icons.more_horiz_rounded,
            label: '$defaultFirebaseAppName', // Ensure this variable is defined
            onTap: onTapMore,
          ),
        ],

      ),
    );
  }
}
class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _accent : _subtle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// In the HomePage or Bottom Navigation logic


/* =========================================================================
   (OPSIONAL) LEMBAR PILIHAN, BULAN, NOTIF — tetap seperti punyamu
   ========================================================================= */
class _MonthCalendarSheet extends StatefulWidget {
  final DateTime initial;
  const _MonthCalendarSheet({required this.initial});
  @override
  State<_MonthCalendarSheet> createState() => _MonthCalendarSheetState();

  void onSelect(DateTime date) {}
}

class _MonthCalendarSheetState extends State<_MonthCalendarSheet> {
  late DateTime _cursor;  // Date currently being displayed
  double _calendarPosition = 0.0; // Track vertical swipe position
  final DateTime currentDate = DateTime.now();  // Current date for reference

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.initial.year, widget.initial.month, 1);  // Set initial month
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9; // Max height for calendar sheet
    final daysInMonth = DateUtils.getDaysInMonth(_cursor.year, _cursor.month); // Number of days in the month
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday; // First day of the week
    final leadingEmpty = (firstWeekday - 1) % 7; // Empty spaces before the first day of the month

    return SafeArea(
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _calendarPosition += details.primaryDelta!; // Track swipe position
          });
        },
        onVerticalDragEnd: (_) {
          if (_calendarPosition > 50) {
            setState(() {
              _cursor = DateTime(_cursor.year, _cursor.month + 1, 1); // Swipe down to go to the next month
            });
          } else if (_calendarPosition < -50) {
            setState(() {
              _cursor = DateTime(_cursor.year, _cursor.month - 1, 1); // Swipe up to go to the previous month
            });
          }
          setState(() {
            _calendarPosition = 0.0;  // Reset swipe position after the drag ends
          });
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Month Navigation (Previous & Next Month)
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _cursor = DateTime(_cursor.year, _cursor.month - 1, 1); // Go to the previous month
                        });
                      },
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
                      onPressed: () {
                        setState(() {
                          _cursor = DateTime(_cursor.year, _cursor.month + 1, 1); // Go to the next month
                        });
                      },
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Grid for Dates
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: leadingEmpty + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leadingEmpty) {
                        return const SizedBox.shrink(); // Empty space for the first days of the week
                      }
                      final day = index - leadingEmpty + 1; // Calculate the day number
                      final date = DateTime(_cursor.year, _cursor.month, day);
                      final isSelected = _isSameDay(date, currentDate); // Check if the day is today

                      return InkWell(
                        onTap: () {
                          widget.onSelect(date); // Return selected date back to parent widget
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orangeAccent : _cardBlue, // Highlight current day with a special color
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // Bold for selected day
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

  // Helper function to check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Helper function to get the month name
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
        child: Text(t, style: const TextStyle(
            color: _subtle, fontWeight: FontWeight.w700)),
      ),
    );
  }
}



