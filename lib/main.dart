import 'package:apps_runara/screen/HubungkanPageScreen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:apps_runara/sos_bus.dart';

// === Auth Service (untuk init Google Sign-In) ===
import 'screen/auth_service.dart';

// === Screens ===
import 'screen/WelcomeScreen.dart';
import 'screen/SignInScreen.dart';
import 'screen/SignUpScreen.dart';
import 'screen/HomePageScreen.dart';
import 'screen/ChooseRoleScreen.dart';
import 'screen/onboarding_role_page.dart';      // <-- satu sumber saja
import 'screen/TunanetraPageScreen.dart';       // atau 'screen/tunanetra_page_screen.dart'
import 'screen/MapsPageScreen.dart';
import 'screen/ProfilePageScreen.dart';
import 'screen/CariPendampingPageScreen.dart';
import 'screen/verifyphonescreen.dart';
import 'push_setup.dart'; // <<< ADD
import 'dart:async';                 // << TAMBAH
import 'screen/HubungkanPageScreen.dart';



final navigatorKey = GlobalKey<NavigatorState>();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // DEV cepat: debug token
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // ganti PlayIntegrity untuk release
    appleProvider: AppleProvider.debug,
  );
  await initPush(); // <<< ADD

  // ===== W A J I B untuk google_sign_in v7 =====
  // Ganti dengan Web Client ID (OAuth 2.0) dari Firebase/GCP.
  await AuthService.initGoogleSignIn(
    serverClientId: '638926623166-uqu6balvin3muvch9gqvv2uil28osl7n.apps.googleusercontent.com',
    );

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

          case '/tunanetra':
            return MaterialPageRoute(builder: (_) => const TunanetraPageScreen());

          case '/maps':
            return MaterialPageRoute(builder: (_) => const MapsPageScreen());

          case '/hubungkan':
            return MaterialPageRoute(builder: (_) => const HubungkanPageScreen());

          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfilePageScreen());

          case '/Cari':
            return MaterialPageRoute(builder: (context) => const CariPendampingPageScreen());
// di onGenerateRoute:
          case '/verify-phone':
            return MaterialPageRoute(
              builder: (_) => VerifyPhoneScreen.fromRouteArgs(settings),
              settings: settings,
            );

          default:
          // Fallback aman
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

void setupSosListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage m) {
    final d = m.data;
    SosPayload p = SosPayload(
      name: d['name'] ?? '',
      role: d['role'] ?? 'Tunanetra',
      address: d['address'] ?? '',
      lat: (d['lat'] != null) ? double.tryParse('${d['lat']}') : null,
      lng: (d['lng'] != null) ? double.tryParse('${d['lng']}') : null,
    );
    // kirim ke in-app stream → hanya Relawan yang sudah subscribe akan menampilkan sheet
    SosBus.emit(p);
  });
}
