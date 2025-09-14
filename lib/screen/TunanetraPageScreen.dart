// lib/screen/TunanetraPageScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// widgets reusable
import 'widget/runara_thin_nav.dart';
import 'widget/runara_header.dart'; // RunaraHeaderSection, RunaraNotificationCenter, runaraGreetingIndo, runaraGreetingEmoji

// layar tujuan ketika “Pantau lokasi” & “Profil”
import 'MapsPageScreen.dart';
import 'ProfilePageScreen.dart';

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

  // status badge notifikasi ambil dari RunaraNotificationCenter
  bool get _hasUnread => RunaraNotificationCenter.hasUnread;

  // dummy data list (bisa diganti dari Firestore/REST nanti)
  final List<_TunaMember> _members = const [
    _TunaMember(name: 'Aldy Giovani', connectedAtText: '16/05/2025'),
    _TunaMember(name: 'Rani Pratiwi', connectedAtText: '12/05/2025'),
    _TunaMember(name: 'Dimas Pratama', connectedAtText: '09/05/2025'),
    _TunaMember(name: 'Nadia Kusuma', connectedAtText: '05/05/2025'),
  ];

  @override
  void initState() {
    super.initState();
    _initHeaderData();
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

    if (!mounted) return;
    setState(() {
      _name = name;
      _roleLabel = roleStr == 'tunanetra' ? 'Tunanetra' : 'Relawan';
      _level = 0;
      _progress = 0; // isi sesuai progress nyata jika sudah ada
    });
  }

  Future<void> _openNotifications() async {
    await RunaraNotificationCenter.open(context);
    if (mounted) setState(() {}); // refresh badge
  }

  final auth = FirebaseAuth.instance.currentUser;

  // ====== ACTIONS ======
  void _openMaps() {
    // Langsung ke halaman peta (versi umum). Kalau nanti ada lat/lng, bisa dorong SosTrackingMapScreen.open(...)
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapsPageScreen()));
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePageScreen()));
  }

  void _openScheduleSheet(_TunaMember m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text('Jadwal ${m.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            _ScheduleRow(time: 'Sab, 18 Mei • 06:00 – 07:15', place: 'GOR Pajajaran'),
            const SizedBox(height: 8),
            _ScheduleRow(time: 'Sel, 21 Mei • 16:30 – 17:45', place: 'Lap. Saparua'),
            const SizedBox(height: 8),
            _ScheduleRow(time: 'Jum, 24 Mei • 06:30 – 07:30', place: 'GBK – Senayan'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Tutup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openActionSheet(_TunaMember m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Text(
                    'Terkoneksi • ${m.connectedAtText}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.location_on_rounded,
                label: 'Pantau lokasi',
                subtitle: 'Buka peta untuk memantau',
                onTap: () {
                  Navigator.pop(context);
                  _openMaps();
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.calendar_month_rounded,
                label: 'Jadwal',
                subtitle: 'Lihat jadwal pendampingan',
                onTap: () {
                  Navigator.pop(context);
                  _openScheduleSheet(m);
                },
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.person_outline_rounded,
                label: 'Profil',
                subtitle: 'Lihat dan kelola profil',
                onTap: () {
                  Navigator.pop(context);
                  _openProfile();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                    greeting: runaraGreetingIndo(DateTime.now()),
                    emoji: runaraGreetingEmoji(DateTime.now()),
                    userName: _name,
                    roleLabel: _roleLabel,
                    level: _level,
                    progress: _progress,
                    hasUnread: _hasUnread,
                    onTapBell: _openNotifications,
                    photoUrl: auth?.photoURL, // ✅ pakai foto akun
                  ),
                ),

                // === LIST (pakai SliverList dengan builder delegate)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) {
                        if (i.isOdd) return const SizedBox(height: 10);
                        final idx = i ~/ 2;
                        if (idx >= _members.length) return null;
                        final m = _members[idx];
                        return _TunaCard(
                          member: m,
                          onTapAnywhere: () => _openActionSheet(m), // seluruh kartu/isi bisa diklik
                          onTapLocation: () => _openMaps(),
                          onTapSchedule: () => _openScheduleSheet(m),
                          onTapProfile: () => _openProfile(),
                        );
                      },
                      childCount: _members.length * 2 - 1,
                    ),
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

/* ====================== MODEL ======================= */

class _TunaMember {
  final String name;
  final String connectedAtText;
  const _TunaMember({required this.name, required this.connectedAtText});
}

/* ====================== LIST CARD ======================= */

class _TunaCard extends StatelessWidget {
  final _TunaMember member;
  final VoidCallback onTapAnywhere;
  final VoidCallback onTapLocation;
  final VoidCallback onTapSchedule;
  final VoidCallback onTapProfile;

  const _TunaCard({
    required this.member,
    required this.onTapAnywhere,
    required this.onTapLocation,
    required this.onTapSchedule,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    // Gunakan InkWell full-bleed agar KAPANPUN disentuh memicu aksi
    return Semantics(
      label: 'Kartu Tunanetra ${member.name}',
      button: true,
      child: InkWell(
        onTap: onTapAnywhere,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _cardBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar (klik → profil)
                  InkWell(
                    onTap: onTapProfile,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF283456),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: Colors.white70, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Identitas (klik → sheet)
                  Expanded(
                    child: InkWell(
                      onTap: onTapAnywhere,
                      borderRadius: BorderRadius.circular(8),
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
                            member.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Status / tanggal (klik → sheet)
                  InkWell(
                    onTap: onTapAnywhere,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                      child: Column(
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
                            member.connectedAtText,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tombol aksi
              Row(
                children: [
                  Expanded(
                    child: _FilledBtn(
                      color: const Color(0xFF8B8FEA),
                      icon: Icons.location_on_rounded,
                      label: 'Pantau lokasi',
                      onTap: onTapLocation,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilledBtn(
                      color: const Color(0xFFFF9B2F),
                      icon: Icons.calendar_month_rounded,
                      label: 'Jadwal',
                      onTap: onTapSchedule,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ====================== SHEET WIDGETS ======================= */

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        )),
                  ]
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final String time;
  final String place;
  const _ScheduleRow({required this.time, required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.place_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              place,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
