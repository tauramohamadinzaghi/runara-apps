// lib/screen/SettingPageScreen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// ============ PALETTE ============
const _cardBlue = Color(0xFF152449);
const _accent   = Color(0xFF7B8AFF);
const _accent2  = Color(0xFF9AA6FF);
// transparan sebelumnya bikin “hilang” di tema terang, jadi tak pakai lagi untuk profil card
// const _glassTop = Color(0x22152449);
// const _glassBot = Color(0x113A4C86);

class SettingsPageScreen extends StatefulWidget {
  const SettingsPageScreen({super.key});

  @override
  State<SettingsPageScreen> createState() => _SettingsPageScreenState();
}

class _SettingsPageScreenState extends State<SettingsPageScreen> {
  // ======= state =======
  String _displayName = 'User';
  String _email = '';
  String? _photoUrl;

  bool _notif = true;
  bool _voiceNav = false;
  bool _highContrast = false;
  bool _reduceMotion = false;

  String _lang = 'id'; // 'id' | 'en'

  bool _autoFollow = true;
  bool _useWalkingRoute = true;
  double _arrivalRadius = 20; // meter

  bool _shareLiveOnSos = true;

  bool _loading = true;
  String? _error;
  StreamSubscription? _remoteSub;

  // ======= keys (SharedPreferences) =======
  static const _kNotif = 'settings_notifications';
  static const _kVoiceNav = 'settings_voice_nav';
  static const _kContrast = 'settings_high_contrast';
  static const _kReduceMotion = 'settings_reduce_motion';
  static const _kLang = 'settings_lang';
  static const _kFollow = 'settings_follow_mode';
  static const _kWalking = 'settings_walking_route';
  static const _kRadius = 'settings_arrival_radius_m';
  static const _kShareSOS = 'settings_share_live_sos';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final u = FirebaseAuth.instance.currentUser;

      _displayName = (u?.displayName ?? '').trim();
      _email = u?.email ?? '';
      _photoUrl = u?.photoURL;
      if (_displayName.isEmpty) {
        _displayName = _email.isNotEmpty ? _email.split('@').first : 'User';
      }

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _notif           = prefs.getBool(_kNotif)        ?? true;
        _voiceNav        = prefs.getBool(_kVoiceNav)     ?? false;
        _highContrast    = prefs.getBool(_kContrast)     ?? false;
        _reduceMotion    = prefs.getBool(_kReduceMotion) ?? false;
        _lang            = prefs.getString(_kLang)       ?? 'id';
        _autoFollow      = prefs.getBool(_kFollow)       ?? true;
        _useWalkingRoute = prefs.getBool(_kWalking)      ?? true;
        _arrivalRadius   = prefs.getDouble(_kRadius)     ?? 20.0;
        _shareLiveOnSos  = prefs.getBool(_kShareSOS)     ?? true;
        _error = null;
      });

      // Sync remote settings bila login
      if (u != null) {
        _remoteSub?.cancel();
        _remoteSub = FirebaseFirestore.instance
            .collection('users').doc(u.uid).snapshots()
            .listen((snap) async {
          final d = snap.data();
          if (d == null) return;
          final s = (d['settings'] as Map?)?.cast<String, dynamic>();
          if (s == null) return;

          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          setState(() {
            if (s.containsKey('notifications')) { _notif = s['notifications'] == true; prefs.setBool(_kNotif, _notif); }
            if (s.containsKey('voice_nav'))     { _voiceNav = s['voice_nav'] == true; prefs.setBool(_kVoiceNav, _voiceNav); }
            if (s.containsKey('high_contrast')) { _highContrast = s['high_contrast'] == true; prefs.setBool(_kContrast, _highContrast); }
            if (s.containsKey('reduce_motion')) { _reduceMotion = s['reduce_motion'] == true; prefs.setBool(_kReduceMotion, _reduceMotion); }
            if (s.containsKey('lang'))          { _lang = (s['lang'] ?? 'id'); prefs.setString(_kLang, _lang); }
            if (s.containsKey('auto_follow'))   { _autoFollow = s['auto_follow'] == true; prefs.setBool(_kFollow, _autoFollow); }
            if (s.containsKey('walking_route')) { _useWalkingRoute = s['walking_route'] == true; prefs.setBool(_kWalking, _useWalkingRoute); }
            if (s.containsKey('arrival_radius_m')) {
              final vv = (s['arrival_radius_m'] as num?)?.toDouble() ?? _arrivalRadius;
              _arrivalRadius = vv.clamp(5, 100).toDouble();
              prefs.setDouble(_kRadius, _arrivalRadius);
            }
            if (s.containsKey('share_live_sos')) { _shareLiveOnSos = s['share_live_sos'] == true; prefs.setBool(_kShareSOS, _shareLiveOnSos); }
          });
        }, onError: (_) {
          if (!mounted) return;
          setState(() => _error = 'Gagal memuat pengaturan dari server.');
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan saat memuat pengaturan.');
    } finally {
      if (mounted) setState(() => _loading = false); // PASTIKAN loading turun
    }
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    super.dispose();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);

    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      final path = FirebaseFirestore.instance.collection('users').doc(u.uid);
      await path.set({
        'settings': {
          if (key == _kNotif)    'notifications': value,
          if (key == _kVoiceNav) 'voice_nav': value,
          if (key == _kContrast) 'high_contrast': value,
          if (key == _kReduceMotion) 'reduce_motion': value,
          if (key == _kLang)     'lang': value,
          if (key == _kFollow)   'auto_follow': value,
          if (key == _kWalking)  'walking_route': value,
          if (key == _kRadius)   'arrival_radius_m': value,
          if (key == _kShareSOS) 'share_live_sos': value,
        }
      }, SetOptions(merge: true));
    }
  }

  Future<void> _openSystemSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka tautan.')),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil keluar.')));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // ======= dynamic scheme berdasar theme (gelap/terang) =======
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor     = isDark ? _cardBlue : Colors.white;
    final onCard        = isDark ? Colors.white : Colors.black87;
    final onCardMuted   = isDark ? Colors.white60 : Colors.black54;
    final dividerColor  = isDark ? Colors.white12 : Colors.black12;
    final chipBg        = isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05);
    final headerBg      = isDark ? Colors.white.withOpacity(.08) : Colors.black.withOpacity(.06);
    final leadingIcon   = isDark ? _accent2 : _accent;

    final avatar = _photoUrl != null && _photoUrl!.isNotEmpty
        ? CircleAvatar(radius: 26, backgroundImage: NetworkImage(_photoUrl!))
        : CircleAvatar(
      radius: 26,
      backgroundColor: isDark ? Colors.white12 : Colors.black12,
      child: Text(
        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
        style: TextStyle(color: onCard, fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );

    return Scaffold(
      // TIDAK pakai backgroundColor agar tembus ke parent
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.black26, // semi transparan, kontras di atas apa pun
        elevation: 0,
        foregroundColor: Colors.white, // aman dibaca di atas black26
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: _accent))
            : (_error != null
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: onCardMuted, size: 42),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: onCardMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _bootstrap();
                },
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ==== PROFILE CARD ==== (solid, bukan overlay transparan)
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
                boxShadow: isDark ? null : [ // biar kebaca di background terang
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName,
                            style: TextStyle(color: onCard, fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(_email.isEmpty ? '—' : _email,
                            style: TextStyle(color: onCardMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: onCard,
                      backgroundColor: chipBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: dividerColor),
                      ),
                    ),
                    child: const Text('Kelola Profil'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==== PREFERENSI ====
            _Section(
              title: 'Preferensi',
              cardColor: cardColor,
              onCard: onCard,
              onCardMuted: onCardMuted,
              headerBg: headerBg,
              dividerColor: dividerColor,
              leadingAccent: leadingIcon,
              children: [
                _SwitchTile(
                  icon: Icons.notifications_active_rounded,
                  label: 'Notifikasi',
                  value: _notif,
                  onChanged: (v) { setState(()=>_notif=v); _saveSetting(_kNotif, v); },
                  trailingActionBuilder: (context, colors) => TextButton(
                    onPressed: _openSystemSettings,
                    style: TextButton.styleFrom(foregroundColor: colors.onCardMuted),
                    child: const Text('Izin Aplikasi'),
                  ),
                ),
                _SwitchTile(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Navigasi Suara',
                  subtitle: 'Panduan suara saat tracking (aksesibilitas).',
                  value: _voiceNav,
                  onChanged: (v) { setState(()=>_voiceNav=v); _saveSetting(_kVoiceNav, v); },
                ),
                _SwitchTile(
                  icon: Icons.contrast_rounded,
                  label: 'Kontras Tinggi',
                  value: _highContrast,
                  onChanged: (v) { setState(()=>_highContrast=v); _saveSetting(_kContrast, v); },
                ),
                _SwitchTile(
                  icon: Icons.animation_rounded,
                  label: 'Kurangi Animasi',
                  value: _reduceMotion,
                  onChanged: (v) { setState(()=>_reduceMotion=v); _saveSetting(_kReduceMotion, v); },
                ),
                _SegmentTile(
                  icon: Icons.language_rounded,
                  label: 'Bahasa',
                  segments: const [
                    MapEntry<String,String>('ID', 'id'),
                    MapEntry<String,String>('EN', 'en'),
                  ],
                  value: _lang,
                  onChanged: (val) { setState(()=>_lang=val); _saveSetting(_kLang, val); },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ==== PETA & TRACKING ====
            _Section(
              title: 'Peta & Pelacakan',
              cardColor: cardColor,
              onCard: onCard,
              onCardMuted: onCardMuted,
              headerBg: headerBg,
              dividerColor: dividerColor,
              leadingAccent: leadingIcon,
              children: [
                _SwitchTile(
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Ikuti Arah Otomatis',
                  value: _autoFollow,
                  onChanged: (v) { setState(()=>_autoFollow=v); _saveSetting(_kFollow, v); },
                ),
                _SwitchTile(
                  icon: Icons.directions_walk_rounded,
                  label: 'Gunakan Rute Pejalan Kaki',
                  value: _useWalkingRoute,
                  onChanged: (v) { setState(()=>_useWalkingRoute=v); _saveSetting(_kWalking, v); },
                ),
                _SliderTile(
                  icon: Icons.my_location_rounded,
                  label: 'Radius “Anggap Sampai”',
                  value: _arrivalRadius,
                  min: 5,
                  max: 100,
                  unit: 'm',
                  onChanged: (v) { setState(()=>_arrivalRadius=v); },
                  onChangeEnd: (v) => _saveSetting(_kRadius, v),
                ),
                const SizedBox(height: 4),
                _HintText(
                  'Catatan: sambungkan nilai ini ke MapsPageScreen untuk mengganti _arrivalRadiusM.',
                  onCardMuted: onCardMuted,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ==== PERANGKAT & SOS ====
            _Section(
              title: 'Perangkat & SOS',
              cardColor: cardColor,
              onCard: onCard,
              onCardMuted: onCardMuted,
              headerBg: headerBg,
              dividerColor: dividerColor,
              leadingAccent: leadingIcon,
              children: [
                _NavTile(
                  icon: Icons.link_rounded,
                  label: 'Hubungkan Perangkat',
                  subtitle: 'Pasangkan perangkat pendamping (IoT).',
                ),
                _SwitchTile(
                  icon: Icons.emergency_share_rounded,
                  label: 'Bagikan Lokasi Saat SOS',
                  value: _shareLiveOnSos,
                  onChanged: (v) { setState(()=>_shareLiveOnSos=v); _saveSetting(_kShareSOS, v); },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ==== DONASI ====
            _Section(
              title: 'Donasi',
              cardColor: cardColor,
              onCard: onCard,
              onCardMuted: onCardMuted,
              headerBg: headerBg,
              dividerColor: dividerColor,
              leadingAccent: leadingIcon,
              children: [
                _NavTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Metode Pembayaran Tersimpan',
                  subtitle: 'Kelola kartu/ewallet yang terhubung.',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ==== TENTANG ====
            _Section(
              title: 'Tentang',
              cardColor: cardColor,
              onCard: onCard,
              onCardMuted: onCardMuted,
              headerBg: headerBg,
              dividerColor: dividerColor,
              leadingAccent: leadingIcon,
              children: [
                _NavTile(
                  icon: Icons.info_rounded,
                  label: 'Versi Aplikasi',
                  trailing: Text('1.0.0', style: TextStyle(color: onCardMuted)),
                ),
                _NavTile(
                  icon: Icons.privacy_tip_rounded,
                  label: 'Kebijakan Privasi',
                  onTap: () => _openUrl('https://example.com/privacy'),
                ),
                _NavTile(
                  icon: Icons.description_rounded,
                  label: 'Syarat & Ketentuan',
                  onTap: () => _openUrl('https://example.com/terms'),
                ),
                _NavTile(
                  icon: Icons.rate_review_rounded,
                  label: 'Beri Masukan',
                  onTap: () => _openUrl('mailto:hello@runara.app'),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ==== SIGN OUT ====
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _signOut,
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
        )),
      ),
    );
  }
}

/// ============ WIDGETS ============

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  // theme-aware props disuntik dari parent
  final Color cardColor;
  final Color onCard;
  final Color onCardMuted;
  final Color headerBg;
  final Color dividerColor;
  final Color leadingAccent;

  const _Section({
    required this.title,
    required this.children,
    required this.cardColor,
    required this.onCard,
    required this.onCardMuted,
    required this.headerBg,
    required this.dividerColor,
    required this.leadingAccent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: onCardMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: .3,
              ),
            ),
          ),
          ..._intersperse(
            children.map((w) {
              // selipkan warna ikon leading ke child yang support
              if (w is _SwitchTile) return _SwitchTile(
                icon: w.icon,
                label: w.label,
                subtitle: w.subtitle,
                value: w.value,
                onChanged: w.onChanged,
                trailingActionBuilder: w.trailingActionBuilder,
              );
              if (w is _SegmentTile) return w;
              if (w is _SliderTile) return w;
              if (w is _NavTile) return _NavTile(
                icon: w.icon, label: w.label, subtitle: w.subtitle,
                trailing: w.trailing, onTap: w.onTap,
              );
              return w;
            }).toList(),
            Divider(height: 1, color: dividerColor),
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget Function(BuildContext, _TileColors)? trailingActionBuilder;

  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.trailingActionBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _TileColors(
      onCard: isDark ? Colors.white : Colors.black87,
      onCardMuted: isDark ? Colors.white54 : Colors.black54,
      divider: isDark ? Colors.white12 : Colors.black12,
      chipBg: isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05),
      leadingAccent: isDark ? _accent2 : _accent,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: _LeadingIcon(icon: icon, bg: colors.chipBg, border: colors.divider, fg: colors.leadingAccent),
        title: Text(label, style: TextStyle(color: colors.onCard, fontWeight: FontWeight.w700)),
        subtitle: subtitle==null ? null : Text(subtitle!, style: TextStyle(color: colors.onCardMuted, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingActionBuilder != null) trailingActionBuilder!(context, colors),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: isDark ? Colors.white : Colors.white,
              activeTrackColor: _accent,
              inactiveThumbColor: isDark ? Colors.white70 : Colors.black45,
              inactiveTrackColor: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<MapEntry<String, String>> segments; // (label -> value)
  final String value;
  final ValueChanged<String> onChanged;
  const _SegmentTile({
    required this.icon, required this.label,
    required this.segments, required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCard = isDark ? Colors.white : Colors.black87;
    final onCardMuted = isDark ? Colors.white54 : Colors.black54;
    final chipBg = isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05);
    final border = isDark ? Colors.white24 : Colors.black12;
    final leadingAccent = isDark ? _accent2 : _accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: _LeadingIcon(icon: icon, bg: chipBg, border: border, fg: leadingAccent),
        title: Text(label, style: TextStyle(color: onCard, fontWeight: FontWeight.w700)),
        subtitle: const SizedBox(height: 6),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: segments.map((s) {
                final sel = s.value == value;
                return Expanded(
                  child: InkWell(
                    onTap: ()=>onChanged(s.value),
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.all(3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.key,
                        style: TextStyle(
                          color: sel ? (isDark ? Colors.black : Colors.white) : onCard,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min, max;
  final String unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _SliderTile({
    required this.icon, required this.label,
    required this.value, required this.min, required this.max,
    required this.unit, required this.onChanged, this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCard = isDark ? Colors.white : Colors.black87;
    final onCardMuted = isDark ? Colors.white70 : Colors.black54;
    final border = isDark ? Colors.white24 : Colors.black12;
    final chipBg = isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05);
    final leadingAccent = isDark ? _accent2 : _accent;

    final double v = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: _LeadingIcon(icon: icon, bg: chipBg, border: border, fg: leadingAccent),
        title: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: onCard, fontWeight: FontWeight.w700))),
            Text('${v.toStringAsFixed(0)} $unit', style: TextStyle(color: onCardMuted)),
          ],
        ),
        subtitle: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: _accent,
            inactiveTrackColor: isDark ? Colors.white24 : Colors.black26,
            thumbColor: isDark ? Colors.white : Colors.black,
          ),
          child: Slider(
            min: min, max: max, value: v,
            onChanged: onChanged, onChangeEnd: onChangeEnd,
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _NavTile({required this.icon, required this.label, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onCard = isDark ? Colors.white : Colors.black87;
    final onCardMuted = isDark ? Colors.white54 : Colors.black54;
    final border = isDark ? Colors.white24 : Colors.black12;
    final chipBg = isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.05);
    final leadingAccent = isDark ? _accent2 : _accent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: _LeadingIcon(icon: icon, bg: chipBg, border: border, fg: leadingAccent),
        title: Text(label, style: TextStyle(color: onCard, fontWeight: FontWeight.w700)),
        subtitle: subtitle==null? null : Text(subtitle!, style: TextStyle(color: onCardMuted, fontSize: 12)),
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color border;
  final Color fg;
  const _LeadingIcon({required this.icon, required this.bg, required this.border, required this.fg});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;
  final Color onCardMuted;
  const _HintText(this.text, {required this.onCardMuted});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: isDark ? Colors.white38 : Colors.black38, size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: onCardMuted, fontSize: 11))),
        ],
      ),
    );
  }
}

class _TileColors {
  final Color onCard;
  final Color onCardMuted;
  final Color divider;
  final Color chipBg;
  final Color leadingAccent;
  _TileColors({
    required this.onCard,
    required this.onCardMuted,
    required this.divider,
    required this.chipBg,
    required this.leadingAccent,
  });
}

/// util untuk menyisipkan Divider antar child
List<Widget> _intersperse(List<Widget> items, Widget separator) {
  if (items.isEmpty) return items;
  final out = <Widget>[];
  for (var i = 0; i < items.length; i++) {
    out.add(items[i]);
    if (i < items.length - 1) out.add(separator);
  }
  return out;
}
