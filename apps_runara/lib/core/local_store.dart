import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore._();
  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static String _roleKey(String uid) => 'user_role_$uid';         // 'relawan' / 'tunanetra'
  static String _welcomeKey(String uid) => 'seen_welcome_$uid';   // bool
  static String _xpKey(String uid) => 'xp_$uid';                  // int
  static String _lvlKey(String uid) => 'level_$uid';              // int

  // ROLE
  static Future<void> saveRole(String uid, String role) async {
    final p = await _p; await p.setString(_roleKey(uid), role);
  }
  static Future<String?> getRole(String uid) async {
    final p = await _p; return p.getString(_roleKey(uid));
  }

  // NOTIF WELCOME
  static Future<bool> hasSeenWelcome(String uid) async {
    final p = await _p; return p.getBool(_welcomeKey(uid)) ?? false;
  }
  static Future<void> markWelcomeSeen(String uid) async {
    final p = await _p; await p.setBool(_welcomeKey(uid), true);
  }

  // LEVEL/XP
  static Future<void> saveXpLevel(String uid, {required int xp, required int level}) async {
    final p = await _p;
    await p.setInt(_xpKey(uid), xp);
    await p.setInt(_lvlKey(uid), level);
  }
  static Future<(int xp,int level)> getXpLevel(String uid) async {
    final p = await _p;
    return (p.getInt(_xpKey(uid)) ?? 0, p.getInt(_lvlKey(uid)) ?? 0);
  }
}
