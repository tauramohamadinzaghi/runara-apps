import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/local_store.dart';

class OnboardingRolePage extends StatefulWidget {
  const OnboardingRolePage({super.key});
  @override
  State<OnboardingRolePage> createState() => _OnboardingRolePageState();
}

class _OnboardingRolePageState extends State<OnboardingRolePage> {
  String? _selected; // 'relawan' atau 'tunanetra'

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selected == null) return;
    await LocalStore.saveRole(uid, _selected!);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home'); // langsung ke Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text('Kamu sebagai apa?',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _roleTile('Relawan', 'relawan'),
              const SizedBox(height: 10),
              _roleTile('Tunanetra', 'tunanetra'),
              const Spacer(),
              ElevatedButton(
                onPressed: _selected == null ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9AA6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: const Color(0xFF243153),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Lanjut', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleTile(String title, String value) {
    final selected = _selected == value;
    return InkWell(
      onTap: () => setState(() => _selected = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF22315E) : const Color(0xFF152449),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF9AA6FF) : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              value == 'relawan' ? Icons.volunteer_activism : Icons.accessibility_new,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
            if (selected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
