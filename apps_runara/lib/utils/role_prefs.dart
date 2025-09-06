// lib/utils/role_prefs.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RolePrefs {
  static const _keyPrefix = 'user_role_';

  static String _userKey(User? u) => '$_keyPrefix${u?.uid ?? 'local'}';

  /// Ambil role tersimpan ('relawan' / 'tunanetra'), null jika belum ada.
  static Future<String?> getRole([User? user]) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_userKey(user ?? FirebaseAuth.instance.currentUser));
  }

  /// Simpan role ('relawan' / 'tunanetra').
  static Future<void> setRole(String role, [User? user]) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_userKey(user ?? FirebaseAuth.instance.currentUser), role);
  }

  /// Panggil setelah sign-in sukses:
  /// - kalau role belum ada -> ke '/choose-role'
  /// - kalau sudah ada -> ke '/home'
  static Future<void> goAfterLogin(GlobalKey<NavigatorState> navKey) async {
    final role = await getRole();
    if (navKey.currentState == null) return;
    if (role == null) {
      navKey.currentState!.pushReplacementNamed('/choose-role');
    } else {
      navKey.currentState!.pushReplacementNamed('/home');
    }
  }
}
