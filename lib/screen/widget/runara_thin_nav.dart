import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppTab { home, tunanetra, maps, hubungkan, profile }

class RunaraThinNav extends StatelessWidget {
  final AppTab current;
  /// (opsional) kirim nama lengkap; widget akan ambil nama depan
  final String? profileName;

  const RunaraThinNav({
    super.key,
    required this.current,
    this.profileName,
  });

  // palette
  static const _navBlue = Color(0xFF0E1E44);
  static const _accent  = Color(0xFF9AA6FF);
  static const _subtle  = Color(0xFFBFC3D9);

  @override
  Widget build(BuildContext context) {
    // tentukan label tab Profile (nama depan)
    final String profileLabel = _resolveFirstName(profileName);

    return Container(
      height: 86,
      decoration: const BoxDecoration(
        color: _navBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _item(context, Icons.home_rounded,       'Home',        AppTab.home),
          _item(context, Icons.groups_rounded,     'Tunanetra',   AppTab.tunanetra),
          _item(context, Icons.map_rounded,        'Maps',        AppTab.maps),
          _item(context, Icons.wifi_rounded,       'Hubungkan',   AppTab.hubungkan),
          _item(context, Icons.person_rounded,     profileLabel,  AppTab.profile),
        ],
      ),
    );
  }

  /// Ambil nama depan dari:
  /// 1) [overrideName] jika dikirim
  /// 2) FirebaseAuth.displayName
  /// 3) prefix email (sebelum @)
  /// 4) fallback "Profil"
  String _resolveFirstName(String? overrideName) {
    String pick(String? s) => (s ?? '').trim();

    // 1) dari parameter
    final fromParam = pick(overrideName);
    if (fromParam.isNotEmpty) {
      return fromParam.split(RegExp(r'\s+'))[0];
    }

    try {
      final u = FirebaseAuth.instance.currentUser;
      // 2) displayName
      final dn = pick(u?.displayName);
      if (dn.isNotEmpty) return dn.split(RegExp(r'\s+'))[0];

      // 3) email prefix
      final em = pick(u?.email);
      if (em.isNotEmpty) return em.split('@').first;
    } catch (_) {}

    // 4) fallback
    return 'Profil';
  }

  Widget _item(BuildContext context, IconData icon, String label, AppTab tab) {
    final bool selected = tab == current;
    final Color color = selected ? _accent : _subtle;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (selected) return;
        Navigator.of(context).pushReplacementNamed(_routeFor(tab));
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // kotak highlight saat aktif
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: selected
                  ? BoxDecoration(
                color: _accent.withOpacity(.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent, width: 1),
              )
                  : null,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _routeFor(AppTab tab) {
    switch (tab) {
      case AppTab.home:       return '/home';
      case AppTab.tunanetra:  return '/tunanetra';
      case AppTab.maps:       return '/maps';
      case AppTab.hubungkan:  return '/hubungkan';
      case AppTab.profile:    return '/profile';
    }
  }
}
