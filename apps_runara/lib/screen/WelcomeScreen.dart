import 'package:flutter/material.dart';
import 'SignInScreen.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onSignInClick;

  const WelcomeScreen({super.key, required this.onSignInClick});

  @override
  Widget build(BuildContext context) {
    // Preload assets so transitions are smooth (push & back)
    precacheImage(const AssetImage('assets/bg_welcome.png'), context);
    precacheImage(const AssetImage('assets/img_welcome.png'), context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B3D),
        ),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/bg_welcome.png',
                fit: BoxFit.cover,
              ),
            ),

            // Title & Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  SizedBox(height: 100.0),
                  Text(
                    'Welcome To RUNARA',
                    style: TextStyle(
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Menghubungkan pelari tunanetra dengan relawan di sekitar untuk pengalaman lari yang aman dan menyenangkan.',
                    style: TextStyle(
                      fontSize: 17.0,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Mascot
            Positioned(
              bottom: 120.0,
              left: 10.0,
              right: 10.0,
              child: Image.asset(
                'assets/img_welcome.png',
                fit: BoxFit.contain,
                height: 500.0,
              ),
            ),

            // GET STARTED Button
            Positioned(
              bottom: 125.0,
              left: 24.0,
              right: 24.0,
              child: SizedBox(
                height: 55.0,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(_fadeSlideRoute(
                      SignInScreen(
                        onSignInClick: () => Navigator.of(context).pushReplacementNamed('/home'),
                        onSignUpClick: () => Navigator.of(context).pushNamed('/signup'),
                      ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9AA6FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    'GET STARTED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Custom transition: fade + slide up (symmetric for push & back)
  Route _fadeSlideRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
