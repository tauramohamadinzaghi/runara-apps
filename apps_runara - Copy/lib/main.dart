import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// === screens kamu ===
import 'screen/WelcomeScreen.dart';
import 'screen/SignInScreen.dart';
import 'screen/SignUpScreen.dart';
import 'screen/HomePageScreen.dart'; // berisi class HomePage
import 'screen/onboarding_role_page.dart';
import 'core/local_store.dart';
import 'screen/ChooseRoleScreen.dart';
import 'screen/TunanetraPageScreen.dart'; // Import the TunanetraPageScreen

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
      // HANYA pakai onGenerateRoute agar tidak bentrok
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const _RootGate());

          case '/signin':
            return MaterialPageRoute(
              builder: (_) => SignInScreen(
                onSignInClick: () {
                  // fallback bila callback dipanggil (tidak wajib, kita juga push langsung dari SignIn)
                  navigatorKey.currentState!
                      .pushNamedAndRemoveUntil('/home', (r) => false);
                },
                onSignUpClick: () => navigatorKey.currentState!.pushNamed('/signup'),
              ),
            );

          case '/signup':
            return MaterialPageRoute(builder: (_) => const SignUpScreen());

          case '/home':
          // PENTING: pakai kelas HomePage (bukan HomePageScreen dummy)
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/profile':
          case '/settings':
          case '/choose-role':
            return MaterialPageRoute(builder: (_) => const ChooseRoleScreen());
          case '/onboarding-role':
            return MaterialPageRoute(builder: (_) => const OnboardingRolePage());
        }
      },
    );
  }
}

/// Belum login → Welcome; sudah login → _RoleGate
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
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

/// Cek role; kalau belum ada → onboarding. Jika sudah → langsung ke HomePage (file kamu).
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
      future: LocalStore.getRole(u.uid),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final role = snap.data;
        if (role == null) {
          return const OnboardingRolePage();
        }
        // LANGSUNG pakai HomePage dari file HomePageScreen.dart
        return const HomePage();
      },
    );
  }
}
