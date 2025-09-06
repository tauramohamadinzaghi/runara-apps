// lib/screen/ChooseRoleScreen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/role_prefs.dart';

const _bgBlue = Color(0xFF0D1B3D);
const _cardBlue = Color(0xFF152449);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);

class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}
class RolePrefs {
  static Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final u = FirebaseAuth.instance.currentUser;
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    await prefs.setString(roleKey, role);
  }
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  String? _choice; // 'relawan' atau 'tunanetra'
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillIfAny();
  }

  Future<void> _prefillIfAny() async {
    final sp = await SharedPreferences.getInstance();
    final u = FirebaseAuth.instance.currentUser;
    final key = 'user_role_${u?.uid ?? 'local'}';
    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${user.uid}';
    final roleStr = prefs.getString(roleKey);
    final exist = sp.getString(key);
    if (exist != null) {
      setState(() => _choice = exist); // pre-select jika sudah pernah milih
    }
  }

  Future<void> _saveAndGo() async {
    if (_choice == null || _saving) return;
    setState(() => _saving = true);
    await RolePrefs.setRole(_choice!);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final name = (FirebaseAuth.instance.currentUser?.displayName ?? '')
        .trim()
        .isEmpty
        ? (FirebaseAuth.instance.currentUser?.email ?? 'Pengguna').split('@').first
        : FirebaseAuth.instance.currentUser!.displayName!;
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text('Halo, $name 👋',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22)),
                  const SizedBox(height: 6),
                  const Text(
                    'Pilih peranmu di RUNARA. Kamu bisa mengubahnya nanti di Pengaturan.',
                    style: TextStyle(color: _subtle),
                  ),
                  const SizedBox(height: 20),
                  _RoleCard(
                    title: 'Relawan',
                    desc:
                    'Mendampingi pelari tunanetra saat berlari. Membantu navigasi & keselamatan.',
                    icon: Icons.volunteer_activism_rounded,
                    selected: _choice == 'relawan',
                    onTap: () => setState(() => _choice = 'relawan'),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    title: 'Tunanetra',
                    desc:
                    'Pelari tunanetra yang mencari relawan pendamping untuk beraktivitas lari.',
                    icon: Icons.accessibility_new_rounded,
                    selected: _choice == 'tunanetra',
                    onTap: () => setState(() => _choice = 'tunanetra'),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _choice == null || _saving ? null : _saveAndGo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        disabledBackgroundColor: const Color(0xFF243153),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(_saving ? 'Menyimpan...' : 'Lanjut'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class user {
  static var uid;
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBlue.withOpacity(.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _accent : Colors.white10,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: _accent, size: 18),
                      ]
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(color: _subtle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
