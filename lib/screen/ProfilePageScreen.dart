// lib/screen/ProfilePageScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget/runara_thin_nav.dart';
import 'widget/runara_header.dart';
import 'SettingsPageScreen.dart';

/// ===== Colors / Tokens =====
const _bgBlue   = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _gold     = Color(0xFFFFC42E);
const _accent   = Color(0xFF7B8AFF);
const _chip     = Color(0xFF3A4C86);
const _subtle   = Color(0xFFBFC3D9);

class ProfilePageScreen extends StatefulWidget {
  const ProfilePageScreen({super.key});
  @override
  State<ProfilePageScreen> createState() => _ProfilePageScreenState();
}

class _ProfilePageScreenState extends State<ProfilePageScreen> {
  // header data
  String _name = '—';
  String _roleLabel = 'Relawan';
  int _level = 0;
  double _progress = 0;
  DateTime? _joinedAt;

  // edit mode
  bool _editing = false;

  // controllers
  final _nameCtl     = TextEditingController();
  final _ageCtl      = TextEditingController();
  final _jobCtl      = TextEditingController();
  final _hobbyCtl    = TextEditingController();
  final _locationCtl = TextEditingController();

  // prefs keys
  static const _kName     = 'profile_name';
  static const _kAge      = 'profile_age';
  static const _kJob      = 'profile_job';
  static const _kHobby    = 'profile_hobby';
  static const _kLocation = 'profile_location';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _ageCtl.dispose();
    _jobCtl.dispose();
    _hobbyCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final u = FirebaseAuth.instance.currentUser;

    var display = (u?.displayName ?? '').trim();
    if (display.isEmpty) {
      final email = (u?.email ?? '').trim();
      display = email.isNotEmpty ? email.split('@').first : 'User';
    }

    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    final roleStr = prefs.getString(roleKey) ?? 'relawan';

    // load saved fields (fallback ke akun)
    _nameCtl.text     = prefs.getString(_kName)     ?? display;
    _ageCtl.text      = prefs.getString(_kAge)      ?? '22 Tahun';
    _jobCtl.text      = prefs.getString(_kJob)      ?? 'Seniman';
    _hobbyCtl.text    = prefs.getString(_kHobby)    ?? 'Bermusik';
    _locationCtl.text = prefs.getString(_kLocation) ?? 'Kota Bandung';

    if (!mounted) return;
    setState(() {
      _name      = _nameCtl.text;
      _roleLabel = roleStr == 'tunanetra' ? 'Tunanetra' : 'Relawan';
      _level     = 0;
      _progress  = 0;
      _joinedAt  = u?.metadata.creationTime;
    });
  }

  String _fmtJoin(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName,     _nameCtl.text.trim());
    await prefs.setString(_kAge,      _ageCtl.text.trim());
    await prefs.setString(_kJob,      _jobCtl.text.trim());
    await prefs.setString(_kHobby,    _hobbyCtl.text.trim());
    await prefs.setString(_kLocation, _locationCtl.text.trim());

    // update Firebase displayName (best effort)
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      try { await u.updateDisplayName(_nameCtl.text.trim()); } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _name = _nameCtl.text.trim().isEmpty ? '—' : _nameCtl.text.trim();
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil disimpan.')),
    );
  }

  void _cancel() => setState(() => _editing = false);

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Yakin ingin keluar?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: ()=>Navigator.pop(ctx,true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      // langsung ke halaman sign-in — pastikan route '/signin' terdaftar di MaterialApp
      Navigator.of(context).pushNamedAndRemoveUntil('/signin', (_) => false);
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPageScreen()),
    );
  }

  // Demo jadwal sederhana (statik)
  List<_Schedule> _demoSchedules() {
    final now = DateTime.now();
    DateTime d(int addDays) => DateTime(now.year, now.month, now.day + addDays);
    return [
      _Schedule(date: d(1), start: '06:20', end: '07:30', place: 'GBK – Senayan', role: 'Tunanetra'),
      _Schedule(date: d(4), start: '16:30', end: '17:45', place: 'Lap. Saparua', role: 'Relawan'),
      _Schedule(date: d(7), start: '06:00', end: '07:15', place: 'GOR Pajajaran', role: 'Tunanetra'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom; // tinggi keyboard (untuk padding dinamis)
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgBlue,
      resizeToAvoidBottomInset: true,
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // ===== Header (RunaraHeaderSection saja)
                SliverToBoxAdapter(
                  child: RunaraHeaderSection(
                    greeting: runaraGreetingIndo(DateTime.now()),
                    emoji:    runaraGreetingEmoji(DateTime.now()),
                    userName: _name,
                    roleLabel: _roleLabel,
                    level: _level,
                    progress: _progress,
                    hasUnread: RunaraNotificationCenter.hasUnread,
                    onTapBell: () async {
                      final changed = await RunaraNotificationCenter.open(context);
                      if (changed == true && mounted) setState(() {});
                    },
                    photoUrl: u?.photoURL, // avatar dari akun
                  ),
                ),

                // ===== Data Diri
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Data Diri',
                          style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: ()=> setState(()=> _editing = !_editing),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          child: Text(_editing ? 'Tutup' : 'Ubah'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _TwoByBars(
                      editing: _editing,
                      bars: [
                        _BarSpec(icon: Icons.badge_outlined,    label: 'Nama Lengkap', controller: _nameCtl),
                        _BarSpec(icon: Icons.cake_outlined,     label: 'Umur',          controller: _ageCtl),
                        _BarSpec(icon: Icons.work_outline,      label: 'Pekerjaan',     controller: _jobCtl),
                        _BarSpec(icon: Icons.interests_outlined,label: 'Hobi',          controller: _hobbyCtl),
                        _BarSpec(icon: Icons.location_on,       label: 'Lokasi',        controller: _locationCtl),
                        _BarSpec(icon: Icons.event_available,   label: 'Bergabung',     valueText: _fmtJoin(_joinedAt)),
                      ],
                    ),
                  ),
                ),

                if (_editing)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _cancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Batal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ===== Jadwal Pendampingan (rapi, non-klik)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Jadwal Pendampingan',
                          style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ScheduleSection(items: _demoSchedules()),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ===== Actions bawah: Pengaturan & Keluar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _openSettings,
                            icon: const Icon(Icons.settings),
                            label: const Text('Pengaturan'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Keluar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Padding dinamis setinggi keyboard untuk cegah overflow
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 24 + kb),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const RunaraThinNav(current: AppTab.profile),
    );
  }
}

/// ==== “2 bar per baris” layout ====
class _BarSpec {
  final IconData icon;
  final String label;
  final TextEditingController? controller; // kalau null → static
  final String? valueText;                 // untuk static display
  _BarSpec({
    required this.icon,
    required this.label,
    this.controller,
    this.valueText,
  });
}

class _TwoByBars extends StatelessWidget {
  final bool editing;
  final List<_BarSpec> bars;
  const _TwoByBars({required this.editing, required this.bars});

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        const columns = 2; // dua per baris
        final barWidth = (w - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: bars.map((b) {
            return SizedBox(
              width: barWidth,
              child: _InfoBar(
                icon: b.icon,
                label: b.label,
                controller: b.controller,
                staticText: b.valueText,
                editing: editing && b.controller != null, // "Bergabung" tetap statis
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InfoBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController? controller;
  final String? staticText;
  final bool editing;

  const _InfoBar({
    required this.icon,
    required this.label,
    required this.controller,
    required this.staticText,
    required this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 11),
                ),
                const SizedBox(height: 6),
                editing
                    ? SizedBox(
                  height: 24,
                  child: TextField(
                    controller: controller!,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.0,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      filled: true,
                      fillColor: Colors.white.withOpacity(.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                )
                    : Text(
                  controller?.text ?? (staticText ?? '—'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ==== Jadwal (rapi, non-klik) ====
class _Schedule {
  final DateTime date;
  final String start, end, place, role;
  _Schedule({
    required this.date,
    required this.start,
    required this.end,
    required this.place,
    required this.role,
  });
}

class _ScheduleSection extends StatelessWidget {
  final List<_Schedule> items;
  const _ScheduleSection({required this.items});

  String _wkId(int w) {
    const m = {1:'Sen',2:'Sel',3:'Rab',4:'Kam',5:'Jum',6:'Sab',7:'Min'};
    return m[w]!;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: const Text('Tidak ada jadwal.', style: TextStyle(color: Colors.white70)),
      );
    }

    return Column(
      children: [
        for (final s in items) ...[
          _ScheduleItem(
            dayShort: _wkId(s.date.weekday),
            dayNum: s.date.day.toString().padLeft(2,'0'),
            start: s.start,
            end: s.end,
            place: s.place,
            role: s.role,
          ),
          const SizedBox(height: 10),
        ]
      ],
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String dayShort;
  final String dayNum;
  final String start, end, place, role;
  const _ScheduleItem({
    required this.dayShort,
    required this.dayNum,
    required this.start,
    required this.end,
    required this.place,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _cardBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Tanggal
          Container(
            width: 56,
            decoration: BoxDecoration(
              color: _chip.withOpacity(.5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayShort, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(dayNum, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Detail
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('$start – $end', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place_rounded, size: 16, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // Role pill (kanan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(role, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
