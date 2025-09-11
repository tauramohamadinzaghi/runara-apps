import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget/runara_thin_nav.dart';
import 'widget/runara_header.dart'; // RunaraHeaderSection, RunaraNotificationSheet, AppNotification

/// ===== Colors =====
const _bgBlue = Color(0xFF0B1B4D);
const _navBlue = Color(0xFF001A4D);
const _chipBlue = Color(0xFF4B5B9E);
const _barTrack = Color(0xFF2B3B7A);
const _barFill = Color(0xFF4B5E9D);
const _gold = Color(0xFFFFB800);

class ProfilePageScreen extends StatefulWidget {
  const ProfilePageScreen({super.key});

  @override
  State<ProfilePageScreen> createState() => _ProfilePageScreenState();
}

class _ProfilePageScreenState extends State<ProfilePageScreen> with SingleTickerProviderStateMixin {  // Pastikan menambahkan `with SingleTickerProviderStateMixin`
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  String _name = '—';
  String _roleLabel = 'Relawan';
  int _level = 0;
  double _progress = 0;
  final List<AppNotification> _notifs = [];

  bool get _hasUnread => _notifs.any((n) => !n.read);

  bool _isEditing = false;

  // Controllers for text fields
  TextEditingController _nameController = TextEditingController();
  TextEditingController _ageController = TextEditingController();
  TextEditingController _jobController = TextEditingController();
  TextEditingController _hobbyController = TextEditingController();
  TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Animation for small status
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);  // `vsync: this` is valid now
    final curve = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: .8, end: 1.4).animate(curve);
    _opacity = Tween<double>(begin: .75, end: 0).animate(curve);

    _initHeaderData();
    _seedDemoNotifications();
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _jobController.dispose();
    _hobbyController.dispose();
    _locationController.dispose();
    super.dispose();
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
      _progress = 0;
      _nameController.text = _name;
      _ageController.text = '22 Tahun';
      _jobController.text = 'Seniman';
      _hobbyController.text = 'Bermusik';
      _locationController.text = 'Kota Bandung';
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
            child: SingleChildScrollView(  // Pastikan konten dapat digulir
              child: Column(
                children: [
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
                  // ===== DATA DIRI
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Data Diri', style: TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 14)),
                          TextButton(
                            onPressed: () {
                              _toggleEditMode();  // Fungsi untuk mengubah mode edit
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _gold,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            child: const Text('Ubah'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.9,
                        shrinkWrap: true,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 10,
                        children: [
                          _InfoItem(
                            title: 'Nama Lengkap',
                            value: _editableField(_nameController, fontSize: 12),
                          ),
                          _InfoItem(
                            title: 'Umur',
                            value: _editableField(_ageController, fontSize: 12),
                          ),
                          _InfoItem(
                            title: 'Bergabung',
                            value: Text(
                              '02/04/2025',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Move "Pekerjaan", "Hobby", and "Lokasi" Down
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.9,
                        shrinkWrap: true,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 5,
                        children: [
                          _InfoItem(
                            title: 'Pekerjaan',
                            value: _editableField(_jobController, fontSize: 14),
                          ),
                          _InfoItem(
                            title: 'Hobby',
                            value: _editableField(_hobbyController, fontSize: 14),
                          ),
                          _InfoItem(
                            title: 'Lokasi',
                            value: _editableField(_locationController, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const RunaraThinNav(current: AppTab.profile),
    );
  }

  Widget _editableField(TextEditingController controller, {required int fontSize}) {
    return _isEditing
        ? TextField(
      controller: controller,
      style: TextStyle(color: Colors.white, fontSize: fontSize.toDouble()),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.only(top: 0, bottom: 0),  // Menyesuaikan padding
        hintText: controller.text,
        hintStyle: TextStyle(color: Colors.white, fontSize: fontSize.toDouble()),
        border: InputBorder.none,  // Tidak ada border saat mode edit
        enabledBorder: InputBorder.none,  // Tidak ada border saat tidak fokus
        focusedBorder: InputBorder.none,  // Tidak ada border saat fokus
      ),
    )
        : Text(
      controller.text,
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: fontSize.toDouble()),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final Widget value;

  const _InfoItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _gold, fontWeight: FontWeight.w600, fontSize: 12)),
        value,  // Display the widget (editable field or text)
      ],
    );
  }
}
