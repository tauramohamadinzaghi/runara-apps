import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:apps_runara/screen/auth_service.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignInClick; // panggil ini untuk ke /home
  final VoidCallback onSignUpClick; // panggil ini untuk ke /signup

  const SignInScreen({
    Key? key,
    required this.onSignInClick,
    required this.onSignUpClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  appBar: AppBar(title: Text('Sign In')),
  body: Center(
  child: ElevatedButton(
  onPressed: () {
  // Navigate to SignUp page
  Navigator.pushNamed(context, '/signup');
  },
  child: Text('Sign Up'),
  ),
  ),
  );
  }


  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _showPassword = false;
  bool _rememberMe = false;
  bool _busy = false;

  // === Flash banner control ===
  bool _flashShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // tangkap flashMessage dari arguments (kalau ada)
    final args = ModalRoute.of(context)?.settings.arguments;
    final msg = (args is Map) ? args['flashMessage'] as String? : null;

    if (!_flashShown && msg != null && msg.isNotEmpty) {
      _flashShown = true;
      // tampilkan banner setelah frame build
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFlash(msg));
    }
  }

  void _showFlash(String msg) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF16A34A), // hijau sukses
        elevation: 6,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        leading: const Icon(Icons.check_circle, color: Colors.white),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    // auto-dismiss
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _emailSignIn() async {
    setState(() => _busy = true);
    try {
      await AuthService.i.signInWithEmail(_email.text.trim(), _password.text);
      if (!mounted) return;
      widget.onSignInClick(); // ke /home
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _busy = true);
    try {
      await AuthService.i.signInWithGoogle();
      if (!mounted) return;
      widget.onSignInClick();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _facebookSignIn() async {
    setState(() => _busy = true);
    try {
      await AuthService.i.signInWithFacebook();
      if (!mounted) return;
      widget.onSignInClick();
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D1B3D);
    const fieldBg = Color(0xFF3E4C8A);
    const primary = Color(0xFF9AA6FF);

    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg_welcome.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboard),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Image.asset(
                      'assets/img_welcome.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome Back To RUNARA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your email and password to access your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // email
                    _InputField(
                      controller: _email,
                      hint: 'Email or Username',
                      bg: fieldBg,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // password
                    _InputField(
                      controller: _password,
                      hint: 'Password',
                      bg: fieldBg,
                      obscure: !_showPassword,
                      suffix: IconButton(
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              activeColor: primary,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            const Text('Remember Me', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () async {
                            final email = _email.text.trim();
                            if (email.isEmpty) {
                              _toast('Isi email dulu untuk reset password');
                              return;
                            }
                            try {
                              await AuthService.i.sendReset(email);
                              _toast('Cek email untuk reset password');
                            } catch (e) {
                              _toast(e.toString());
                            }
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _emailSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'SIGN IN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Or', style: TextStyle(color: Colors.white)),
                        ),
                        Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // social buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SocButton(
                          icon: FontAwesomeIcons.google,
                          onTap: _busy ? null : _googleSignIn,
                        ),
                        _SocButton(
                          icon: FontAwesomeIcons.facebookF,
                          onTap: _busy ? null : _facebookSignIn,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "DON'T HAVE AN ACCOUNT YET? ",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: widget.onSignUpClick,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'SIGN UP',
                            style: TextStyle(
                              color: Color(0xFF9AA6FF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= Sub Widgets =======================

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color bg;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _InputField({
    Key? key,
    required this.controller,
    required this.hint,
    required this.bg,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBFC3D9)),
        filled: true,
        fillColor: bg.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
      ),
    );
  }
}

class _SocButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SocButton({
    Key? key,
    required this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
