//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//import 'package:shared_preferences/shared_preferences.dart';

//const TunanetraPageScreen({Key? key}) : super(key: key);
/// ===== Palette (samakan dg Home) =====
const _bgBlue   = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue  = Color(0xFF0E1E44);
const _accent   = Color(0xFF9AA6FF);
const _subtle   = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF3A4C86);

class TunanetraPageScreen extends StatelessWidget {
  const TunanetraPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

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
            child: Column(
              children: [
                // === HEADER (diperkecil)
                // di dalam Column > children:
                Padding(
                  // header turun sedikit: tambah top padding
                  padding: EdgeInsets.fromLTRB(16, (topPad > 0 ? 18 : 26), 16, 10),
                  child: const _HeaderTunanetraLarge(),
                ),

                // === LIST
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => const _TunaCard(
                      name: 'Aldy Giovani',
                      dateText: '16/05/2025',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // === BOTTOM NAV (konten dinaikkan sedikit)
      bottomNavigationBar: _BottomNav(
        selected: _BottomItem.tunanetra,
        onTapHome: () => Navigator.of(context).pushReplacementNamed('/home'),
        onTapTunanetra: () {},
        onTapMaps: () => Navigator.of(context).pushReplacementNamed('/maps'), // ⬅️ hanya ini yang ditambah
        onTapChat: () {},
        onTapMore: () {},
      ),
    );
  }
}

/* ===================== HEADER (compact) ===================== */
// GANTI kelas header lama dengan ini
class _HeaderTunanetraLarge extends StatelessWidget {
  const _HeaderTunanetraLarge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBlue.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(22),      // radius lebih besar
      ),
      padding: const EdgeInsets.all(16),              // padding lebih besar
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar LEBIH besar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'H',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Teks & progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // greeting + emoji
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Selamat malam',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16, // lebih besar
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('🌙', style: TextStyle(fontSize: 17)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Text(
                      'Hilda Afiah',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18, // lebih besar
                        height: 1.05,
                      ),
                    ),
                    SizedBox(width: 6),
                    _RoleBadge(text: 'Relawan', fontSize: 12), // badge ikut besar
                  ],
                ),

                // 👉 kebawahin progress: jarak ditambah
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 16, color: _subtle), // ukuran ok
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8, // bar sedikit lebih tebal
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: .60,
                            child: Container(
                              height: 8,
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
                    const Text(
                      'LV.0',
                      style: TextStyle(
                        color: _subtle,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Lonceng + dot sedikit lebih besar
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
              ),
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgBlue, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String text;
  final double fontSize;
  const _RoleBadge({required this.text, this.fontSize = 11});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: _chipBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.0),
      ),
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
                    color: Color(0xFF283456), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tunanetra',
                      style: TextStyle(
                          color: Color(0xFFFFC107), fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Terkoneksi',
                    style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 12)),
                const SizedBox(height: 3),
                Text(dateText,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
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
        height: 42, // sedikit lebih kecil
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/* ===================== BOTTOM NAV (LARGE) ===================== */

enum _BottomItem { home, tunanetra, maps, chat, more }

class _BottomNav extends StatelessWidget {
  final VoidCallback onTapHome, onTapTunanetra, onTapMaps, onTapChat, onTapMore;
  final _BottomItem selected;

  const _BottomNav({
    required this.onTapHome,
    required this.onTapTunanetra,
    required this.onTapMaps,
    required this.onTapChat,
    required this.onTapMore,
    this.selected = _BottomItem.home,
  });

  @override
  Widget build(BuildContext context) {
    return Container
      (
      height: 86, // ⬆️ sedikit lebih tinggi
      decoration: const BoxDecoration(
        color: _navBlue,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      // konten center, tidak terlalu nempel ke bawah
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: selected == _BottomItem.home,
            onTap: onTapHome,
          ),
          _NavButton(
            icon: Icons.groups_rounded,
            label: 'Tunanetra',
            selected: selected == _BottomItem.tunanetra,
            onTap: onTapTunanetra,
          ),
          _NavButton(
            icon: Icons.map_rounded,
            label: 'Maps',
            selected: selected == _BottomItem.maps,
            onTap: onTapMaps,
          ),
          _NavButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Hubungkan',
            selected: selected == _BottomItem.chat,
            onTap: onTapChat,
          ),
          _NavButton(
            icon: Icons.more_horiz_rounded,
            label: 'Lainnya',
            selected: selected == _BottomItem.more,
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

  // ⬆️ ukuran lebih besar
  static const double _iconSize = 26;  // sebelumnya 20–22
  static const double _fontSize = 13;  // sebelumnya 11–12
  static const double _gap      = 4;

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
        width: 72, // beri ruang untuk label lebih besar
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,  // konten agak naik ke atas container
          children: [
            Icon(icon, color: color, size: _iconSize),
            const SizedBox(height: _gap),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: _fontSize,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
