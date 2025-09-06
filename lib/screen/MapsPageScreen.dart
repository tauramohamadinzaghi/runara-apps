import 'package:flutter/material.dart';

/// ===== Palet warna (selaras dengan halaman lain) =====
const _bgBlue   = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue  = Color(0xFF0E1E44);
const _accent   = Color(0xFF9AA6FF);
const _subtle   = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF3A4C86);

class MapsPageScreen extends StatefulWidget {
  const MapsPageScreen({super.key});

  @override
  State<MapsPageScreen> createState() => _MapsPageScreenState();
}

class _MapsPageScreenState extends State<MapsPageScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scale   = Tween<double>(begin: 0.8,  end: 1.4).animate(curve);
    _opacity = Tween<double>(begin: 0.75, end: 0.0).animate(curve);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                // ===== Header dari HTML (versi Flutter) =====
                Padding(
                  padding: EdgeInsets.fromLTRB(16, (topPad > 0 ? 12 : 20), 16, 10),
                  child: _HeaderWithStatus(scale: _scale, opacity: _opacity),
                ),

                // ===== Konten peta (placeholder) =====
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: _cardBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.map_rounded, size: 96, color: Colors.white24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ===== Bottom nav: bisa pindah Home <-> Tunanetra <-> Maps
      bottomNavigationBar: _BottomNavLarge(
        selected: _BottomItem.maps,
        onTapHome:      () => Navigator.of(context).pushReplacementNamed('/home'),
        onTapTunanetra: () => Navigator.of(context).pushReplacementNamed('/tunanetra'),
        onTapMaps:      () {}, // sudah di Maps
        onTapChat:      () {}, // TODO: route chat
        onTapMore:      () {}, // TODO: sheet "lainnya"
      ),
    );
  }
}

/* ================== HEADER DARI HTML (Flutter) ================== */

class _HeaderWithStatus extends StatelessWidget {
  final Animation<double> scale;
  final Animation<double> opacity;

  const _HeaderWithStatus({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBlue.withOpacity(.72),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar "H"
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2B3B7A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'H',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Teks + badge + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting + emoji
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Selamat malam',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    SizedBox(width: 6),
                    Text('🌙', style: TextStyle(fontSize: 16)),
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
                        fontSize: 17,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(width: 6),
                    _RoleBadge(text: 'Relawan', fontSize: 11),
                  ],
                ),
                const SizedBox(height: 10),

                // Shield + progress + LV
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 16, color: _subtle),
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
                          FractionallySizedBox(
                            widthFactor: .60, // 60%
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _chipBlue, // #4B5B9E-ish
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Kolom status: "Berjalan" + indikator hijau berdenyut
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Berjalan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: 20,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Pulse ring (animasi)
                    AnimatedBuilder(
                      animation: scale,
                      builder: (context, _) {
                        return Opacity(
                          opacity: opacity.value,
                          child: Transform.scale(
                            scale: scale.value,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF22C55E), width: 2), // green-500
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Titik tengah: hijau dengan border putih, titik inti gelap
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _bgBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF22C55E), width: 1),
                        ),
                      ),
                    ),
                  ],
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
      decoration: BoxDecoration(color: _chipBlue, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.0),
      ),
    );
  }
}

/* ===================== Bottom Nav (reusable) ===================== */

enum _BottomItem { home, tunanetra, maps, chat, more }

class _BottomNavLarge extends StatelessWidget {
  final VoidCallback onTapHome, onTapTunanetra, onTapMaps, onTapChat, onTapMore;
  final _BottomItem selected;

  const _BottomNavLarge({
    super.key,
    required this.onTapHome,
    required this.onTapTunanetra,
    required this.onTapMaps,
    required this.onTapChat,
    required this.onTapMore,
    this.selected = _BottomItem.home,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: const BoxDecoration(
        color: _navBlue,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavBtn(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: selected == _BottomItem.home,
            onTap: onTapHome,
          ),
          _NavBtn(
            icon: Icons.groups_rounded,
            label: 'Tunanetra',
            selected: selected == _BottomItem.tunanetra,
            onTap: onTapTunanetra,
          ),
          _NavBtn(
            icon: Icons.map_rounded,
            label: 'Maps',
            selected: selected == _BottomItem.maps,
            onTap: onTapMaps,
          ),
          _NavBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Hubungkan',
            selected: selected == _BottomItem.chat,
            onTap: onTapChat,
          ),
          _NavBtn(
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _iconSize = 26;
  static const double _fontSize = 13;

  const _NavBtn({
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
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: _iconSize),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
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
