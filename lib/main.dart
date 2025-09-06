import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === Screens ===
import 'screen/WelcomeScreen.dart';
import 'screen/SignInScreen.dart';
import 'screen/SignUpScreen.dart';
import 'screen/HomePageScreen.dart';
import 'screen/ChooseRoleScreen.dart';
import 'screen/onboarding_role_page.dart';      // <-- satu sumber saja
import 'screen/TunanetraPageScreen.dart';       // atau 'screen/tunanetra_page_screen.dart'
import 'screen/MapsPageScreen.dart'; // ⬅️ tambahkan

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(useMaterial3: true, colorScheme: const ColorScheme.dark()),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const _RootGate());

          case '/signin':
            return MaterialPageRoute(
              builder: (_) => SignInScreen(
                onSignInClick: () {
                  navigatorKey.currentState!
                      .pushNamedAndRemoveUntil('/home', (r) => false);
                },
                onSignUpClick: () => navigatorKey.currentState!.pushNamed('/signup'),
              ),
            );

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignUpScreen());

          case '/home':
            return MaterialPageRoute(builder: (_) => const HomePage());

          case '/choose-role':
            return MaterialPageRoute(builder: (_) => const ChooseRoleScreen());

          case '/onboarding-role':
            return MaterialPageRoute(builder: (_) => const OnboardingRolePage());

          case '/tunanetra': // <<< rute untuk TunanetraPageScreen
            return MaterialPageRoute(builder: (_) => const TunanetraPageScreen());

          case '/maps': // ⬅️ rute baru
            return MaterialPageRoute(builder: (_) => const MapsPageScreen());

          default:
          // fallback aman
            return MaterialPageRoute(
              builder: (_) => WelcomeScreen(
                onSignInClick: () => navigatorKey.currentState!.pushNamed('/signin'),
              ),
            );
        }
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// GATE: cek login -> cek role -> arahkan
/// ---------------------------------------------------------------------------
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return WelcomeScreen(
            onSignInClick: () => navigatorKey.currentState!.pushNamed('/signin'),
          );
        }
        return const _RoleGate();
      },
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate();

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) => navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (r) => false),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<String?>(
      future: _loadRole(u.uid),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final role = snap.data;
        if (role == null) {
          // belum pilih role → onboarding role
          return const OnboardingRolePage();
        }
        // sudah ada role → ke home
        return const HomePage();
      },
    );
  }

  Future<String?> _loadRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role_$uid');
  }
}
