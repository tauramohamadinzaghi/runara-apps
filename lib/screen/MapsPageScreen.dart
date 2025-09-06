import 'package:flutter/material.dart';

/// ===== Palet warna (selaras dengan halaman lain) =====
const _bgBlue   = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue  = Color(0xFF0E1E44);
const _accent   = Color(0xFF9AA6FF);
const _subtle   = Color(0xFFBFC3D9);

class MapsPageScreen extends StatelessWidget {
  const MapsPageScreen({super.key});

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
                // ===== Header compact =====
                Padding(
                  padding: EdgeInsets.fromLTRB(16, (topPad > 0 ? 12 : 20), 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBlue.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.map_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Maps',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.my_location_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== Body placeholder peta =====
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

      // ===== Bottom nav: Home & Tunanetra & Maps saling navigasi
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
