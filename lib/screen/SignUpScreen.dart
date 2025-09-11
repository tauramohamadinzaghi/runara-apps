// lib/screen/SignUpScreen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'; // teks bisa diklik (terms/privacy)
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'auth_service.dart';

/* ===== Palet ===== */
const _bgBlue = Color(0xFF0D1B3D);
const _fieldFill = Color(0xFFFFFFFF);
const _textDark = Color(0xFF1F2937);
const _placeholder = Color(0xFF6B7280);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _errorRed = Color(0xFFFF4D4F);
const _amber = Color(0xFFFFC107);
const _green = Color(0xFF22C55E);
const _btnDisabled = Color(0xFF243153);

/* ===== Password strength ===== */
enum _PwdStrength { weak, medium, strong }

_PwdStrength _measureStrength(String p) {
  var score = 0;
  if (p.length >= 8) score++;
  if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
  if (score <= 1) return _PwdStrength.weak;
  if (score == 2) return _PwdStrength.medium;
  return _PwdStrength.strong;
}

Color _strengthColor(_PwdStrength s) =>
    s == _PwdStrength.weak ? _errorRed : s == _PwdStrength.medium ? _amber : _green;

/* ===== Formatter DOB dd/MM/yyyy ===== */
class _DobFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(digits[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/* ===== Formatter Nomor HP lokal: 811-1234-5678 (setelah +62) ===== */
class IndoPhoneFormatter extends TextInputFormatter {
  String _fmt(String d) {
    d = d.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = d.substring(1);
    final maxLen = d.length > 12 ? 12 : d.length;
    d = d.substring(0, maxLen);
    final parts = <String>[];
    if (d.length <= 3) {
      parts.add(d);
    } else if (d.length <= 7) {
      parts..add(d.substring(0, 3))..add(d.substring(3));
    } else if (d.length <= 11) {
      parts..add(d.substring(0, 3))..add(d.substring(3, 7))..add(d.substring(7));
    } else {
      parts..add(d.substring(0, 3))..add(d.substring(3, 7))..add(d.substring(7, 11))..add(d.substring(11));
    }
    return parts.where((e) => e.isNotEmpty).join('-');
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = _fmt(newValue.text);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }

  static String toE164(String formattedLocal) {
    final digits = formattedLocal.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return '+62$local';
  }
}

/* ===== Policy enum (top-level) ===== */
enum _Policy { terms, privacy }

/* ===== Widget ===== */
class SignUpScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onGoSignIn;
  const SignUpScreen({super.key, this.onBack, this.onGoSignIn});

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  appBar: AppBar(title: Text('Sign Up')),
  body: Center(
  child: ElevatedButton(
  onPressed: () {
  // Once user signs up, you might want to navigate to HomePage or main screen
  Navigator.pushNamed(context, '/home');
  },
  child: Text('Create Account'),
  ),
  ),
  );
  }

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Controllers
  final _nameC = TextEditingController();
  final _userBodyC = TextEditingController(); // hanya badan username (tanpa '@')
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _dobC = TextEditingController();
  final _pwC = TextEditingController();
  final _rePwC = TextEditingController();

  // Focus
  final _nameF = FocusNode();
  final _userF = FocusNode();
  final _emailF = FocusNode();
  final _phoneF = FocusNode();
  final _dobF = FocusNode();
  final _pwF = FocusNode();
  final _rePwF = FocusNode();

  bool _agree = false;
  bool _showPw = false;
  bool _attempted = false;

  // Terms & privacy recognizers
  late TapGestureRecognizer _termsTap;
  late TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameC, _userBodyC, _emailC, _phoneC, _dobC, _pwC, _rePwC]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _termsTap = TapGestureRecognizer()..onTap = () => _openPolicy(_Policy.terms);
    _privacyTap = TapGestureRecognizer()..onTap = () => _openPolicy(_Policy.privacy);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _nameC.dispose(); _userBodyC.dispose(); _emailC.dispose();
    _phoneC.dispose(); _dobC.dispose(); _pwC.dispose(); _rePwC.dispose();
    _nameF.dispose(); _userF.dispose(); _emailF.dispose();
    _phoneF.dispose(); _dobF.dispose(); _pwF.dispose(); _rePwF.dispose();
    super.dispose();
  }

  /* ===== Validasi ===== */
  bool get _nameOk => _nameC.text.trim().length >= 3;

  String get _usernameSanitized {
    final bodyRaw = _userBodyC.text.replaceAll(RegExp(r'\s'), '');
    final body = bodyRaw.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
    return '@$body';
  }

  bool get _usernameOk {
    final body = _usernameSanitized.substring(1);
    const taken = {'admin','user','demo'};
    return body.length >= 3 && !taken.contains(body.toLowerCase());
  }

  bool get _emailOk => RegExp(r'^[\w.\-+%]+@gmail\.com$').hasMatch(_emailC.text.trim());

  bool get _phoneOk {
    final digits = _phoneC.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0'), '');
    return digits.length >= 9 && digits.length <= 12;
  }

  bool get _dobOk => _dobC.text.length == 10;

  bool get _pwOk {
    final p = _pwC.text;
    return p.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p);
  }

  bool get _reOk => _rePwC.text.isNotEmpty && _rePwC.text == _pwC.text;

  bool get _formOk => _nameOk && _usernameOk && _emailOk && _phoneOk && _dobOk && _pwOk && _reOk && _agree;

  /* ===== Flow Verifikasi ===== */
  bool _busyChoice = false;

  Future<void> _startEmailFlow() async {
    if (_busyChoice) return;
    setState(() => _busyChoice = true);
    try {
      // 1) Buat akun email+password
      final email = _emailC.text.trim();
      final pass  = _pwC.text;
      final cred = await AuthService.i.registerWithEmail(email, pass);

      // opsional: simpan nama
      await cred.user?.updateDisplayName(_nameC.text.trim());

      // 2) Kirim email verifikasi
      await cred.user?.sendEmailVerification();

      // 3) Pindah ke layar verifikasi link
      if (!mounted) return;
      Navigator.pushNamed(context, '/verify-email', arguments: {'email': email});
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } finally {
      if (mounted) setState(() => _busyChoice = false);
    }
  }

  Future<void> _startPhoneFlow() async {
    if (_busyChoice) return;
    setState(() => _busyChoice = true);
    try {
      final phone = IndoPhoneFormatter.toE164(_phoneC.text);

      // ⬇️ Langsung buka VerifyPhoneScreen. Tidak perlu AuthService.startPhoneAuth
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/verify-phone',
        arguments: {
          'phoneE164': phone,
          'linkEmail': _emailC.text.trim(),   // opsional: tautkan email
          'linkPassword': _pwC.text,          // opsional: tautkan password
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyChoice = false);
    }
  }


  void _next(FocusNode next) => FocusScope.of(context).requestFocus(next);

  void _pickDob() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (res != null) {
      final txt = '${res.day.toString().padLeft(2, '0')}/${res.month.toString().padLeft(2, '0')}/${res.year.toString().padLeft(4, '0')}';
      _dobC.text = txt;
    }
  }

  void _onSubmit() {
    setState(() => _attempted = true);
    if (!_formOk) return;
    FocusScope.of(context).unfocus();     // ⬅️ tutup keyboard
    _showVerifyChoices();
  }

  void _showVerifyChoices() {
    final email = _emailC.text.trim();
    final phoneE164 = IndoPhoneFormatter.toE164(_phoneC.text);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilih Metode Verifikasi',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),

              // Email
              VerifyTile(
                title: 'Verifikasi via Email',
                subtitle: email.isEmpty ? '-' : email,
                icon: Icons.mail_outline,
                  // di onTap VerifyTile (Email)
                  onTap: () {
                    Navigator.pop(ctx);
                    FocusScope.of(context).unfocus();     // ⬅️ tutup keyboard
                    _startEmailFlow();
                  },
              ),
              const SizedBox(height: 10),

              // Phone
              VerifyTile(
                title: 'Verifikasi via Nomor HP',
                subtitle: phoneE164.isEmpty ? '-' : phoneE164,
                icon: Icons.sms,
                  onTap: () {
                    Navigator.pop(ctx);
                    FocusScope.of(context).unfocus();     // ⬅️ tutup keyboard
                    _startPhoneFlow();
                  },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ===== Pop-out Terms & Conditions / Privacy ===== */
  void _openPolicy(_Policy policy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final title = policy == _Policy.terms ? 'Terms & Conditions' : 'Privacy Policy';
        final body  = policyText(policy);

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 42, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: Markdown(
                    data: body,
                    selectable: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: Colors.white.withOpacity(0.92), height: 1.5, fontSize: 14),
                      h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      blockquoteDecoration: const BoxDecoration(
                        color: Colors.white12,
                        border: Border(left: BorderSide(color: Colors.white38, width: 3)),
                      ),
                      horizontalRuleDecoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white24, width: 1)),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.white10, borderRadius: BorderRadius.circular(8),
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w700),
                      em: const TextStyle(fontStyle: FontStyle.italic),
                      a: const TextStyle(decoration: TextDecoration.underline),
                      listBullet: TextStyle(color: Colors.white.withOpacity(0.92)),
                      tableHead: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      tableBody: TextStyle(color: Colors.white.withOpacity(0.92)),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) launchUrlString(href);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () { setState(() => _agree = false); Navigator.pop(ctx); },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Tidak setuju', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { setState(() => _agree = true); Navigator.pop(ctx); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Setuju', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tidy/clean version

// enum _Policy { terms, privacy } // (opsional) jika belum didefinisikan.

  String policyText(_Policy p) {
    switch (p) {
      case _Policy.terms:
        return _termsAndConditions;
      case _Policy.privacy:
      default:
        return _privacyPolicy;
    }
  }

  final String _termsAndConditions = r'''
# SYARAT & KETENTUAN PENGGUNAAN (Runara)
**Tanggal berlaku:** 31 Agustus 2025

*Dokumen ini merupakan perjanjian yang mengikat secara hukum antara Anda (“Anda”/“Pengguna”) dan Runara (“Runara”, “Kami”). Dengan membuat akun, mengunduh, mengakses, atau menggunakan aplikasi/layanan Runara ("Layanan"), Anda menyatakan telah membaca, memahami, dan menyetujui Syarat & Ketentuan ini beserta setiap kebijakan tambahan yang Kami publikasikan ("Kebijakan Tambahan"), termasuk Kebijakan Privasi Runara.*

> **Catatan penting:** Dokumen ini adalah templat profesional bergaya platform besar. Untuk kepastian hukum, pertimbangkan untuk menunjuk entitas hukum pengelola Runara dan/atau meminta nasihat hukum independen.

---

## 1. Penerimaan & Perubahan
1.1 **Penerimaan.** Dengan menggunakan Layanan, Anda setuju untuk terikat pada Syarat & Ketentuan ini ("S\&K"). Jika Anda tidak setuju, mohon hentikan penggunaan Layanan.  
1.2 **Perubahan.** Kami dapat memperbarui S\&K dari waktu ke waktu. Jika ada perubahan material, Kami akan memberikan pemberitahuan yang wajar (misalnya melalui notifikasi dalam aplikasi atau email). Penggunaan berkelanjutan setelah pemberitahuan berarti Anda menerima S\&K yang diperbarui.

---

## 2. Kelayakan & Akun
2.1 **Usia minimum.** Anda harus berusia minimal **13 tahun** (atau usia minimum yang berlaku di yurisdiksi Anda). Fitur tertentu (mis. pembayaran) mungkin memerlukan usia minimum lebih tinggi.  
2.2 **Pendaftaran.** Anda wajib memberikan data yang akurat dan memperbaruinya bila terjadi perubahan.  
2.3 **Keamanan akun.** Jaga kerahasiaan kredensial. Semua aktivitas pada akun Anda menjadi tanggung jawab Anda. Beritahu Kami segera jika ada penggunaan tanpa izin.  
2.4 **Penangguhan/Penutupan.** Kami dapat membatasi, menangguhkan, atau menutup akun yang melanggar S\&K/hukum atau membahayakan pengguna lain/Layanan.

---

## 3. Hak & Lisensi atas Konten Pengguna
3.1 **Kepemilikan.** Anda tetap pemilik konten yang Anda unggah, kirim, atau tampilkan melalui Layanan ("Konten Pengguna").  
3.2 **Lisensi kepada Runara.** Dengan mengirimkan Konten Pengguna, Anda memberi Runara lisensi global, non-eksklusif, dapat dipindahtangankan, dapat disublisensikan, bebas royalti untuk menggunakan, mereproduksi, memodifikasi, menerbitkan, menayangkan, menerjemahkan, mendistribusikan, dan menampilkan Konten Pengguna untuk mengoperasikan, mempromosikan, dan meningkatkan Layanan.  
3.3 **Tanggung jawab Anda.** Anda bertanggung jawab memperoleh semua izin yang diperlukan (mis. hak cipta, merek, privasi), serta memastikan Konten Pengguna mematuhi S\&K dan hukum yang berlaku.  
3.4 **Moderasi.** Kami dapat menghapus/ membatasi konten yang melanggar S\&K/hukum atau mengganggu keselamatan pengguna/komunitas. Proses banding internal dapat tersedia.

---

## 4. Perilaku Terlarang
Tanpa batasan, Anda setuju **tidak** akan:
* Melanggar hukum atau hak pihak ketiga;
* Menyebarkan spam, penipuan, skema piramida, atau manipulasi peringkat;
* Mengunggah konten ilegal: pelanggaran hak cipta, eksploitasi seksual anak, kebencian, terorisme, kekerasan ekstrem, atau pelanggaran privasi;
* Meretas, menyalahgunakan API, merekayasa balik, mengakali batasan, atau mengganggu keamanan/kinerja Layanan;
* Mengumpulkan/menambang data pengguna tanpa persetujuan yang sah;
* Meniru identitas, menyalahgunakan lencana/verifikasi, atau melakukan misrepresentasi;
* Mengunggah malware, bot berbahaya, atau melakukan aktivitas yang mengganggu operasional jaringan/perangkat lunak;
* Menggunakan Layanan untuk aktivitas berisiko tinggi tanpa kontrol keselamatan yang memadai.

---

## 5. Kekayaan Intelektual Runara
Layanan, perangkat lunak, antarmuka, desain, dan merek terkait dilindungi hukum. Kecuali diizinkan secara tegas, tidak ada hak yang dialihkan kepada Anda.

---

## 6. Fitur AI & Konten yang Dihasilkan AI (jika ada)
6.1 **Sifat generatif.** Keluaran AI dapat mengandung kesalahan. Tinjau sebelum mengandalkannya.  
6.2 **Lisensi keluaran.** Kecuali dinyatakan lain, Anda dapat menggunakan keluaran AI sesuai S\&K ini dan hukum yang berlaku.  
6.3 **Pembatasan.** Jangan gunakan AI untuk membuat konten ilegal, menipu, menyesatkan, atau yang melanggar hak pihak ketiga.

---

## 7. Pembayaran, Langganan, & Pengembalian Dana
7.1 **Harga & pajak.** Harga dapat berubah; pajak mungkin berlaku.  
7.2 **Perpanjangan otomatis.** Langganan diperpanjang otomatis kecuali Anda membatalkan sebelum periode berikutnya.  
7.3 **Pembatalan.** Batalkan melalui pengaturan akun atau toko aplikasi terkait.  
7.4 **Pengembalian dana.** Tunduk pada hukum setempat dan/atau kebijakan toko aplikasi (untuk pembelian melalui App Store/Play Store).

---

## 8. Layanan Pihak Ketiga & Perangkat
8.1 **Integrasi.** Layanan dapat terhubung dengan layanan pihak ketiga (mis. pembayaran, autentikasi). Penggunaan Anda tunduk pada syarat pihak ketiga tersebut.  
8.2 **Perangkat & jaringan.** Anda bertanggung jawab atas koneksi internet dan kompatibilitas perangkat. Pembaruan perangkat lunak mungkin diperlukan.

---

## 9. Privasi
Kami memproses data sesuai **Kebijakan Privasi Runara**. Dengan menggunakan Layanan, Anda menyetujui pemrosesan tersebut, termasuk transfer lintas batas sesuai hukum yang berlaku.

---

## 10. Pemberitahuan Pelanggaran Hak (Hak Cipta, Merek, dsb.)
Jika Anda yakin hak Anda dilanggar, kirim pemberitahuan melalui kanal dukungan dalam aplikasi dengan informasi: (a) identifikasi karya/ hak yang dilanggar; (b) materi yang dilaporkan melanggar dan lokasinya; (c) informasi kontak; (d) pernyataan itikad baik; dan (e) pernyataan keakuratan di bawah sumpah. Kami dapat memberi tahu pihak pengunggah dan memfasilitasi kontra-pemberitahuan sesuai hukum.

---

## 11. Perubahan Layanan
Kami dapat menambah, mengubah, atau menghentikan fitur kapan pun. Jika perubahan berdampak material, Kami akan memberikan pemberitahuan wajar.

---

## 12. Penangguhan & Pengakhiran
Kami dapat menangguhkan atau mengakhiri akses Anda bila diperlukan untuk keselamatan pengguna/komunitas, kepatuhan hukum, atau pelanggaran S\&K. Anda dapat mengakhiri kapan saja dengan berhenti menggunakan Layanan dan/atau menutup akun.

---

## 13. Penafian
Layanan disediakan “sebagaimana adanya” tanpa jaminan tersurat/tersirat, termasuk kelayakan untuk tujuan tertentu. Kami tidak menjamin Layanan bebas gangguan, bebas kesalahan, atau sepenuhnya aman.

---

## 14. Batas Tanggung Jawab
Sejauh diizinkan hukum, Runara tidak bertanggung jawab atas kerugian tidak langsung, insidental, khusus, konsekuensial, kehilangan keuntungan, data, atau reputasi. Tanggung jawab agregat Kami dibatasi pada jumlah yang Anda bayarkan kepada Runara dalam 12 bulan terakhir.

---

## 15. Ganti Rugi
Anda setuju untuk mengganti rugi dan membebaskan Runara dari klaim pihak ketiga yang timbul dari pelanggaran S\&K oleh Anda, kecuali sejauh disebabkan oleh kelalaian atau kesengajaan Kami.

---

## 16. Hukum yang Mengatur & Penyelesaian Sengketa
S\&K ini diatur oleh **hukum Republik Indonesia** tanpa memperhatikan pertentangan kaidah hukum. Sengketa diselesaikan secara **individual** melalui arbitrase rahasia sesuai peraturan lembaga arbitrase yang diakui di Indonesia; tempat arbitrase **Jakarta**. Jika arbitrase tidak berlaku, Pengadilan Negeri Jakarta Pusat memiliki yurisdiksi eksklusif.

---

## 17. Ketentuan Lain
* **Keterpisahan.** Jika suatu ketentuan tidak sah, ketentuan lainnya tetap berlaku.
* **Tidak ada pengesampingan.** Kegagalan menegakkan hak tidak berarti pengesampingan.
* **Pengalihan.** Anda tidak boleh mengalihkan S\&K tanpa persetujuan Kami; Runara dapat mengalihkan sebagai bagian dari reorganisasi/merger/akuisisi.
* **Keseluruhan perjanjian.** S\&K ini, bersama Kebijakan Tambahan yang relevan, merupakan keseluruhan perjanjian antara Anda dan Runara terkait Layanan.
* **Bahasa.** Jika terjadi perbedaan terjemahan, versi Bahasa Indonesia dan Inggris sama-sama disediakan; interpretasi mengikuti konteks yang paling mendekati maksud asli.

---

# TERMS & CONDITIONS (Runara)
**Effective date:** 31 August 2025

*This document is a legally binding agreement between you ("you"/"User") and Runara ("Runara", "we"). By creating an account, downloading, accessing, or using the Runara application/service (the "Service"), you acknowledge that you have read, understood, and agreed to these Terms & Conditions (the "Terms") and any additional policies we publish (the "Supplemental Policies"), including the Runara Privacy Policy.*

> **Important:** For legal certainty, consider appointing a specific legal entity operating Runara and obtaining independent legal advice.

---

## 1. Acceptance & Changes
1.1 **Acceptance.** By using the Service, you agree to be bound by these Terms. If you do not agree, please discontinue use.  
1.2 **Changes.** We may update the Terms from time to time. For material changes, we will provide reasonable notice (e.g., in-app or email). Continued use after notice constitutes acceptance.

---

## 2. Eligibility & Accounts
2.1 **Minimum age.** You must be at least **13 years old** (or the minimum age in your jurisdiction). Certain features (e.g., payments) may require a higher age.  
2.2 **Registration.** You must provide accurate information and keep it updated.  
2.3 **Account security.** Keep your credentials confidential. You are responsible for activities under your account. Notify us of any unauthorized use.  
2.4 **Restriction/Termination.** We may restrict, suspend, or terminate accounts that violate the Terms/law or endanger users/the Service.

---

## 3. User Content Rights & License
3.1 **Ownership.** You retain ownership of content you upload, post, or display ("User Content").  
3.2 **License to Runara.** By submitting User Content, you grant Runara a worldwide, non-exclusive, transferable, sublicensable, royalty-free license to use, reproduce, modify, publish, perform, translate, distribute, and display such content to operate, promote, and improve the Service.  
3.3 **Your responsibility.** You are solely responsible for obtaining necessary rights/permissions and ensuring compliance with law and these Terms.  
3.4 **Moderation.** We may remove/restrict content that violates the Terms/law or harms user/community safety. An internal appeals process may be available.

---

## 4. Prohibited Conduct
Without limitation, you agree **not** to:
* Violate law or third-party rights;
* Send spam, fraud, pyramid schemes, or manipulate rankings;
* Post illegal content: copyright infringement, child sexual abuse material, hate, terrorism, extreme violence, or privacy violations;
* Hack, abuse APIs, reverse engineer, circumvent limits, or interfere with security/performance;
* Harvest/mine user data without lawful consent;
* Impersonate, misuse badges/verification, or otherwise misrepresent identity;
* Upload malware or engage in activities disrupting networks/software;
* Use the Service for high-risk activities without adequate safety controls.

---

## 5. Runara Intellectual Property
The Service, software, interfaces, designs, and marks are protected. Except as expressly permitted, no rights are transferred to you.

---

## 6. AI Features & AI-Generated Content (if any)
6.1 **Generative nature.** Outputs may contain errors. Review before reliance.  
6.2 **Output license.** Unless stated otherwise, you may use AI outputs subject to these Terms and applicable law.  
6.3 **Restrictions.** Do not use AI to produce unlawful, deceptive, or rights-infringing content.

---

## 7. Payments, Subscriptions, & Refunds
7.1 **Pricing & taxes.** Prices may change; taxes may apply.  
7.2 **Auto-renewal.** Subscriptions renew automatically unless canceled before the next term.  
7.3 **Cancellation.** Cancel via account settings or the relevant app store.  
7.4 **Refunds.** Subject to local law and/or applicable app store policy (for store-processed purchases).

---

## 8. Third-Party Services & Devices
8.1 **Integrations.** The Service may integrate third-party services (e.g., payments, authentication). Your use is subject to those third parties’ terms.  
8.2 **Devices & networks.** You are responsible for connectivity and compatible devices. Software updates may be required.

---

## 9. Privacy
We process data per the **Runara Privacy Policy**. By using the Service, you consent to such processing, including cross-border transfers as permitted by law.

---

## 10. Notice of Alleged Infringement (Copyright, Trademark, etc.)
If you believe your rights are infringed, submit a notice through the in-app support channel including: (a) identification of the protected work/right; (b) the allegedly infringing material and its location; (c) contact information; (d) a good-faith statement; and (e) a statement of accuracy under penalty of perjury. We may notify the uploader and accept counter-notifications as required by law.

---

## 11. Changes to the Service
We may add, modify, or discontinue features at any time. For material changes, we will provide reasonable notice.

---

## 12. Suspension & Termination
We may suspend or terminate your access as needed for user/community safety, legal compliance, or violations of the Terms. You may terminate at any time by ceasing use and/or closing your account.

---

## 13. Disclaimers
The Service is provided "as is" without express or implied warranties, including merchantability or fitness for a particular purpose. We do not warrant the Service will be uninterrupted, error-free, or entirely secure.

---

## 14. Limitation of Liability
To the maximum extent permitted by law, Runara will not be liable for indirect, incidental, special, consequential, or exemplary damages, or loss of profits, data, or goodwill. Our aggregate liability is limited to amounts you paid to Runara in the 12 months preceding the claim.

---

## 15. Indemnification
You agree to indemnify and hold Runara harmless from third-party claims arising from your breach of these Terms, except to the extent caused by our negligence or willful misconduct.

---

## 16. Governing Law & Dispute Resolution
These Terms are governed by the **laws of the Republic of Indonesia**, excluding conflict-of-laws rules. Disputes shall be resolved on an **individual** basis by confidential arbitration under the rules of a recognized arbitration body in Indonesia; seat of arbitration **Jakarta**. If arbitration is unavailable, the state courts of **Central Jakarta** shall have exclusive jurisdiction.

---

## 17. Miscellaneous
* **Severability.** If any provision is unlawful or unenforceable, the remainder remains in effect.
* **No waiver.** Failure to enforce any right is not a waiver.
* **Assignment.** You may not assign these Terms without our consent; Runara may assign as part of a reorganization/merger/acquisition.
* **Entire agreement.** These Terms, with the applicable Supplemental Policies, constitute the entire agreement between you and Runara regarding the Service.
* **Language.** The Indonesian and English versions are provided; interpretations should follow the context closest to the original intent.
''';

  String _privacyPolicy = r'''
# KEBIJAKAN PRIVASI (Runara)
**Tanggal berlaku:** 31 Agustus 2025

*Dokumen ini menjelaskan bagaimana Runara ("Runara", "kami") mengumpulkan, menggunakan, membagikan, menyimpan, dan melindungi data pribadi Anda saat Anda membuat akun, mengakses, atau menggunakan aplikasi/layanan Runara ("Layanan"). Dengan menggunakan Layanan, Anda menyetujui praktik yang dijelaskan di sini.*

> **Catatan:** Kebijakan ini disusun bergaya platform besar dan menyesuaikan praktik terbaik industri. Untuk kepastian hukum, pertimbangkan untuk menunjuk entitas hukum pengelola Runara dan/atau berkonsultasi dengan penasihat hukum.

---

## 1. Ruang Lingkup & Dasar Hukum
* Kebijakan ini berlaku untuk semua pengguna Layanan di Indonesia dan global.
* Runara mematuhi **UU No. 27 Tahun 2022 tentang Perlindungan Data Pribadi ("UU PDP")**, **PP 71/2019** tentang Penyelenggaraan Sistem dan Transaksi Elektronik, serta peraturan pelaksananya.
* Dasar pemrosesan (legal basis) meliputi: **persetujuan**, **pelaksanaan perjanjian** (memberi Layanan), **kepatuhan hukum**, **kepentingan vital**, **tugas kepentingan umum**, dan **kepentingan yang sah** (dengan uji keseimbangan).

---

## 2. Definisi Singkat
* **Data Pribadi:** setiap data tentang seseorang yang teridentifikasi/ dapat diidentifikasi.
* **Pemrosesan:** setiap operasi atas data (pengumpulan, perekaman, penyimpanan, penggunaan, pengungkapan, penghapusan, dsb.).
* **Pengendali Data:** Runara saat menentukan tujuan & cara pemrosesan.
* **Prosesor:** pihak yang memproses atas nama Runara (mis. penyedia cloud, analitik, pembayaran).

---

## 3. Data yang Kami Kumpulkan
Kami dapat mengumpulkan kategori berikut:
1. **Identitas & Kontak:** nama tampilan, username, foto profil, email, nomor telepon (jika Anda memberikannya), identitas pemerintah bila diwajibkan hukum atau untuk fitur tertentu.
2. **Kredensial:** hash kata sandi, token autentikasi (kami tidak menyimpan kata sandi dalam teks jelas).
3. **Data Penggunaan:** interaksi dalam aplikasi, log perangkat & diagnostik, preferensi, pengaturan, konten yang Anda buat/unggah.
4. **Data Perangkat & Teknis:** model perangkat, OS, pengenal iklan/perangkat, alamat IP, bahasa, zona waktu, parameter jaringan, crash logs.
5. **Lokasi:** perkiraan lokasi (berdasarkan IP/izin OS). Lokasi presisi hanya jika Anda mengaktifkannya.
6. **Pembayaran & Transaksi:** token pembayaran dari penyedia pembayaran, riwayat transaksi, status langganan (kami tidak menyimpan nomor kartu lengkap).
7. **Kontak & Komunikasi:** pesan dukungan, laporan, umpan balik, korespondensi.
8. **Cookie/SDK Serupa:** cookie, local storage, dan SDK untuk otentikasi, keamanan, preferensi, analitik, dan iklan (jika diaktifkan).

Kami dapat menggabungkan informasi dari berbagai sumber (akun Anda, perangkat, dan mitra) sesuai hukum yang berlaku.

---

## 4. Cara Kami Menggunakan Data
Kami memproses data untuk:
* **Menyediakan Layanan**: membuat & mengelola akun, menayangkan konten, menjaga fungsionalitas inti.
* **Keamanan & Integritas**: pencegahan penipuan/penyalahgunaan/spam, deteksi intrusi, moderasi konten, dan verifikasi yang diperlukan.
* **Peningkatan Produk**: analitik, pengujian, riset, dan pengembangan fitur baru.
* **Komunikasi**: notifikasi layanan, pembaruan, dukungan teknis.
* **Pemasaran** (opsional): rekomendasi & promosi yang dipersonalisasi (Anda dapat menolak/menonaktifkan).
* **Kepatuhan**: memenuhi kewajiban hukum dan penegakan S\&K.

---

## 5. Berbagi Data
Kami dapat membagikan data dengan:
* **Penyedia layanan/prosesor**: komputasi awan, pengiriman email/push, analitik, pencegahan penipuan, pembayaran.
* **Mitra fitur pihak ketiga**: jika Anda mengaktifkan integrasi tertentu.
* **Penegak hukum/otoritas**: jika diwajibkan secara sah atau untuk melindungi hak, keselamatan pengguna, atau integritas Layanan.
* **Transaksi korporasi**: sehubungan dengan merger, akuisisi, atau restrukturisasi (data akan dialihkan sesuai kebijakan ini).

Kami tidak menjual data pribadi dalam pengertian menjadikannya komoditas; jika undang-undang setempat mendefinisikan "jual", kami akan menghormati hak opt-out yang relevan.

---

## 6. Transfer Internasional
Jika data dipindahkan ke luar Indonesia, kami menerapkan **perlindungan yang memadai**, termasuk perjanjian perlindungan data, evaluasi dampak transfer, dan standar kontraktual yang sesuai.

---

## 7. Retensi (Penyimpanan)
Kami menyimpan data selama diperlukan untuk tujuan pada Bagian 4, termasuk untuk memenuhi kewajiban hukum & akuntansi. Kriteria retensi mencakup: masa aktif akun, kewajiban hukum, dan kebutuhan pembuktian. Setelah itu, data akan dihapus atau dianonimkan.

---

## 8. Keamanan
Kami menerapkan kontrol teknis & organisasi yang wajar (enkripsi transit & saat disimpan, kontrol akses, audit, backup). Tidak ada sistem yang sepenuhnya aman; segera beri tahu kami jika Anda mencurigai pelanggaran.

---

## 9. Hak Anda
Berdasarkan UU PDP, Anda memiliki hak untuk:
* **Akses** atas data pribadi Anda;
* **Perbaikan/Perbarui** data yang tidak akurat/ tidak lengkap;
* **Penghapusan** data tertentu sesuai syarat UU PDP;
* **Pembatasan** pemrosesan dalam kondisi tertentu;
* **Portabilitas data** (bila berlaku secara teknis & hukum);
* **Menarik persetujuan** kapan pun (tanpa memengaruhi pemrosesan yang telah terjadi);
* **Keberatan** terhadap pemrosesan berbasis kepentingan sah;
* **Tidak tunduk hanya pada keputusan otomatis** yang menimbulkan akibat hukum signifikan, kecuali dengan perlindungan yang layak;
* **Mengajukan pengaduan** ke otoritas berwenang.

Untuk menggunakan hak, gunakan **Pusat Bantuan** dalam aplikasi.

---

## 10. Anak-Anak
Layanan tidak ditujukan untuk anak di bawah **13 tahun**. Kami tidak dengan sengaja mengumpulkan data dari anak di bawah usia tersebut tanpa persetujuan orang tua/wali yang sah. Jika Anda adalah orang tua/wali dan yakin anak Anda memberikan data kepada kami, hubungi melalui Pusat Bantuan untuk menghapusnya.

---

## 11. Cookie & Teknologi Serupa
Kami menggunakan cookie/SDK untuk fungsi inti, keamanan, analitik, dan (opsional) personalisasi/iklan. Anda dapat mengelola preferensi cookie melalui pengaturan perangkat dan/atau dalam aplikasi.

---

## 12. Komunikasi Pemasaran
Jika Anda mendaftar untuk menerima promosi/newsletter, Anda dapat **berhenti berlangganan** kapan saja melalui tautan unsubscribe atau pengaturan akun. Kami tetap dapat mengirim notifikasi transaksional/layanan.

---

## 13. Pengambilan Keputusan Otomatis
Kami dapat menggunakan model otomatis/moderasi untuk menjaga keselamatan & integritas. Jika keputusan otomatis berdampak signifikan, Anda dapat meminta peninjauan manusia (bila berlaku).

---

## 14. Perubahan Kebijakan
Kami dapat memperbarui kebijakan ini dari waktu ke waktu. Jika ada perubahan material, kami akan memberi pemberitahuan yang wajar. Tanggal berlaku tercantum di bagian atas kebijakan ini.

---

## 15. Cara Menghubungi Kami
Gunakan **Pusat Bantuan di aplikasi Runara** untuk pertanyaan atau permintaan hak subjek data. Jika tersedia, kami juga dapat menyediakan alamat email dukungan khusus di dalam aplikasi.

---

# PRIVACY POLICY (Runara)
**Effective date:** 31 August 2025

*This policy explains how Runara ("Runara", "we") collects, uses, shares, stores, and protects your personal data when you create an account, access, or use the Runara app/service (the "Service"). By using the Service, you agree to the practices described here.*

---

## 1. Scope & Legal Bases
* This policy applies to all users in Indonesia and globally.
* Runara complies with **Indonesia’s Personal Data Protection Law (Law No. 27/2022)**, **GR 71/2019** on Electronic Systems and Transactions, and their implementing regulations.
* Legal bases include: **consent**, **contract performance**, **legal obligation**, **vital interests**, **public interest**, and **legitimate interests** (subject to balancing test).

---

## 2. Key Definitions
* **Personal Data:** any data about an identified or identifiable individual.
* **Processing:** any operation on data (collecting, recording, storing, using, disclosing, deleting, etc.).
* **Controller:** Runara when determining purposes & means of processing.
* **Processor:** parties processing on Runara’s behalf (e.g., cloud, analytics, payments).

---

## 3. Data We Collect
1. **Identity & Contact:** display name, username, profile photo, email, phone number (if provided), government ID when required by law or for certain features.  
2. **Credentials:** password hashes, authentication tokens (we do not store plain text passwords).  
3. **Usage Data:** in-app interactions, device logs & diagnostics, preferences, settings, content you create/upload.  
4. **Device & Technical Data:** device model, OS, advertising/device identifiers, IP address, language, time zone, network parameters, crash logs.  
5. **Location:** approximate (IP/OS permissions). Precise location only if enabled by you.  
6. **Payments & Transactions:** payment tokens from payment providers, transaction history, subscription status (we do not store full card numbers).  
7. **Contacts & Communications:** support messages, reports, feedback, correspondence.  
8. **Cookies/SDKs:** cookies, local storage, SDKs for authentication, security, preferences, analytics, and ads (if enabled).

We may combine information across sources (your account, devices, and partners) as permitted by law.

---

## 4. How We Use Data
* **Provide the Service**: account creation/management, content delivery, core features.  
* **Security & Integrity**: fraud/abuse/spam prevention, intrusion detection, moderation, and necessary verification.  
* **Product Improvement**: analytics, testing, research, feature development.  
* **Communications**: service notifications, updates, and support.  
* **Marketing** (optional): personalized recommendations & promotions (you may opt out/disable).  
* **Compliance**: meet legal obligations and enforce the Terms.

---

## 5. Sharing Data
We may share data with:
* **Service providers/processors**: cloud computing, email/push delivery, analytics, fraud prevention, payments.  
* **Third-party feature partners**: if you enable certain integrations.  
* **Law enforcement/authorities**: where legally required or to protect rights, user safety, or Service integrity.  
* **Corporate transactions**: in connection with mergers, acquisitions, or reorganizations (data will follow this policy).

We do not sell personal data as a commodity; where local law defines “sale,” we will honor applicable opt-out rights.

---

## 6. International Transfers
Where data is transferred outside Indonesia, we implement **adequate safeguards**, including data protection agreements, transfer impact assessments, and appropriate contractual standards.

---

## 7. Retention
We retain data as necessary for the purposes in Section 4, including legal and accounting obligations. Criteria include account activity, legal requirements, and evidentiary needs. Thereafter, data will be deleted or anonymized.

---

## 8. Security
We apply reasonable technical and organizational measures (encryption in transit/at rest, access controls, audits, backups). No system is perfectly secure; notify us promptly of suspected breaches.

---

## 9. Your Rights
Subject to Law No. 27/2022, you may:
* **Access** your personal data;
* **Rectify/Update** inaccurate or incomplete data;
* **Delete** certain data as permitted by law;
* **Restrict** processing in certain circumstances;
* **Port** data (where technically & legally feasible);
* **Withdraw consent** at any time (without affecting prior processing);
* **Object** to processing based on legitimate interests;
* **Not be subject solely to automated decisions** with significant legal effects, except with appropriate safeguards;
* **Lodge a complaint** with the relevant authority.

Use the **in-app Help Center** to exercise your rights.

---

## 10. Children
The Service is not directed to children under **13**. We do not knowingly collect data from such children without verifiable parental consent. Parents/guardians may contact us via the Help Center to request deletion.

---

## 11. Cookies & Similar Technologies
We use cookies/SDKs for core functions, security, analytics, and (optional) personalization/ads. Manage preferences via device settings and/or in-app controls.

---

## 12. Marketing Communications
If you opt-in to promotions/newsletters, you can **unsubscribe** any time via the unsubscribe link or account settings. We may still send transactional/service notices.

---

## 13. Automated Decision-Making
We may use automated models/moderation to protect safety & integrity. If a decision has significant effects, you may request human review where applicable.

---

## 14. Changes to this Policy
We may update this policy from time to time. For material changes, we will provide reasonable notice. The effective date appears at the top of this policy.

---

## 15. Contact Us
Use the **Runara in-app Help Center** for privacy questions or data subject requests. If available, we may also provide a dedicated support email inside the app.
''';


  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bgBlue,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: _bgBlue,
          padding: const EdgeInsets.only(left: 4, right: 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                  icon: Image.asset('assets/ic_back.png', width: 36, height: 36),
                ),
                const SizedBox(width: 4),
                const Text(
                  'SIGN UP',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg_space.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _bgBlue),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: keyboard) + const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Image.asset(
                    'assets/img_welcome2.png',
                    height: 210,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 210),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign Up To RUNARA',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Buat akun untuk mulai menghubungkan pelari tunanetra dengan relawan di sekitar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _subtle, fontSize: 15),
                  ),
                  const SizedBox(height: 24),

                  _FieldWhite(
                    label: 'Nama Lengkap',
                    controller: _nameC,
                    hint: 'Masukkan Nama lengkap',
                    error: _attempted && !_nameOk ? 'Mohon isi Nama Lengkap' : null,
                    focus: _nameF,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _next(_userF),
                  ),
                  const SizedBox(height: 20),

                  _UsernameField(
                    controller: _userBodyC,
                    error: _attempted && !_usernameOk
                        ? (_usernameSanitized.length <= 1
                        ? 'Mohon isi Username'
                        : 'Minimal 3 karakter setelah @ atau tidak tersedia')
                        : null,
                    focus: _userF,
                    onSubmitted: (_) => _next(_emailF),
                  ),
                  const SizedBox(height: 20),

                  _FieldWhite(
                    label: 'Email',
                    controller: _emailC,
                    hint: 'name@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                    error: _attempted && !_emailOk ? 'Hanya menerima email @gmail.com' : null,
                    focus: _emailF,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _next(_phoneF),
                  ),
                  const SizedBox(height: 20),

                  _PhoneField(
                    controller: _phoneC,
                    focus: _phoneF,
                    error: _attempted && !_phoneOk ? 'Nomor kurang valid' : null,
                    onSubmitted: (_) => _next(_dobF),
                  ),
                  const SizedBox(height: 20),

                  _DobField(
                    controller: _dobC,
                    focus: _dobF,
                    error: _attempted && !_dobOk ? 'Mohon isi Tanggal Lahir (dd/MM/yyyy)' : null,
                    onTapCalendar: _pickDob,
                    onSubmitted: (_) => _next(_pwF),
                  ),
                  const SizedBox(height: 20),

                  _PasswordField(
                    label: 'Kata Sandi',
                    controller: _pwC,
                    show: _showPw,
                    onToggleShow: () => setState(() => _showPw = !_showPw),
                    showVisibility: true,
                    error: _attempted && !_pwOk ? 'Password belum memenuhi ketentuan' : null,
                    focus: _pwF,
                    onSubmitted: (_) => _next(_rePwF),
                  ),
                  _PasswordStrengthBar(password: _pwC.text),
                  _PasswordMinCapsules4(password: _pwC.text),
                  const SizedBox(height: 20),

                  _PasswordField(
                    label: 'Konfirmasi Sandi',
                    controller: _rePwC,
                    show: _showPw,
                    onToggleShow: () {},
                    showVisibility: false,
                    error: _attempted && !_reOk ? 'Password tidak sama' : null,
                    focus: _rePwF,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _onSubmit(),
                    trailingCheck: _rePwC.text.isEmpty ? null : _reOk,
                  ),

                  const SizedBox(height: 10),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: Checkbox(
                          value: _agree,
                          onChanged: (v) => setState(() => _agree = v ?? false),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: _subtle, fontSize: 14),
                            children: [
                              const TextSpan(text: 'By signing up you agree to our '),
                              TextSpan(
                                text: 'terms & conditions',
                                style: const TextStyle(color: _accent, fontWeight: FontWeight.w600),
                                recognizer: _termsTap,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'privacy policy',
                                style: const TextStyle(color: _accent, fontWeight: FontWeight.w600),
                                recognizer: _privacyTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_attempted && !_agree)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Anda harus menyetujui S&K dan Kebijakan Privasi',
                        style: TextStyle(color: _errorRed),
                      ),
                    ),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _formOk ? _accent : _btnDisabled,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Have an Account? ', style: TextStyle(color: _subtle)),
                      InkWell(
                        onTap: widget.onGoSignIn ?? () => Navigator.pop(context),
                        child: const Text('Sign In',
                            style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ===== Sub-widgets ===== */
class _FieldWhite extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? error;
  final FocusNode? focus;
  final TextInputAction textInputAction;
  final Function(String)? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FieldWhite({
    required this.label,
    required this.controller,
    required this.hint,
    this.error,
    this.focus,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      SizedBox(
        height: 54,
        child: TextField(
          controller: controller,
          focusNode: focus,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _placeholder),
            filled: true, fillColor: _fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(error!, style: const TextStyle(color: _errorRed))
      ]
    ]);
  }
}

class _UsernameField extends StatelessWidget {
  final TextEditingController controller; // hanya body
  final String? error;
  final FocusNode? focus;
  final Function(String)? onSubmitted;

  const _UsernameField({
    required this.controller,
    this.error,
    this.focus,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Username', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        height: 54,
        decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const SizedBox(width: 16),
          const Text('@', style: TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 6),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE7E7E7)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._]'))],
              style: const TextStyle(color: _textDark),
              decoration: const InputDecoration(
                hintText: 'username',
                hintStyle: TextStyle(color: _placeholder),
                border: InputBorder.none,
              ),
            ),
          ),
        ]),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(error!, style: const TextStyle(color: _errorRed))
      ]
    ]);
  }
}

class _DobField extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final VoidCallback onTapCalendar;
  final FocusNode? focus;
  final Function(String)? onSubmitted;

  const _DobField({
    required this.controller,
    required this.error,
    required this.onTapCalendar,
    this.focus,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tanggal Lahir', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      SizedBox(
        height: 54,
        child: TextField(
          controller: controller,
          focusNode: focus,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.number,
          inputFormatters: [_DobFormatter()],
          style: const TextStyle(color: _textDark),
          decoration: InputDecoration(
            hintText: 'dd/MM/yyyy',
            hintStyle: const TextStyle(color: _placeholder),
            suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, color: _textDark), onPressed: onTapCalendar),
            filled: true, fillColor: _fieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(error!, style: const TextStyle(color: _errorRed))
      ]
    ]);
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final FocusNode? focus;
  final Function(String)? onSubmitted;

  const _PhoneField({
    required this.controller,
    required this.error,
    this.focus,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Nomor HP', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        height: 54,
        decoration: BoxDecoration(color: _fieldFill, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const SizedBox(width: 10),
          Container(
            width: 22, height: 14,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.black12)),
            child: Column(children: [
              Expanded(child: Container(color: Colors.red)),
              Expanded(child: Container(color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 8),
          const Text('+62', style: TextStyle(color: _textDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE7E7E7)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              inputFormatters: [IndoPhoneFormatter()],
              style: const TextStyle(color: _textDark),
              decoration: const InputDecoration(
                hintText: '811-1234-5678',
                hintStyle: TextStyle(color: _placeholder),
                border: InputBorder.none,
              ),
            ),
          ),
        ]),
      ),
      if (error != null) ...[
        const SizedBox(height: 4),
        Text(error!, style: const TextStyle(color: _errorRed))
      ]
    ]);
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;                 // true = terlihat, false = disembunyikan
  final VoidCallback onToggleShow; // dipakai hanya jika showVisibility = true
  final String? error;
  final FocusNode? focus;
  final TextInputAction textInputAction;
  final Function(String)? onSubmitted;
  final bool? trailingCheck;
  final bool showVisibility;       // hanya mengatur tampil/tidaknya ikon visibility

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.show,
    required this.onToggleShow,
    this.error,
    this.focus,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.trailingCheck,
    this.showVisibility = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 54,
          child: TextField(
            controller: controller,
            focusNode: focus,
            onSubmitted: onSubmitted,
            textInputAction: textInputAction,
            obscureText: !show,
            keyboardType: TextInputType.visiblePassword,
            style: const TextStyle(color: _textDark),
            decoration: InputDecoration(
              hintText: 'Masukkan kata sandi',
              hintStyle: const TextStyle(color: _placeholder),
              filled: true,
              fillColor: _fieldFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              // trailingCheck prioritas; kalau null & showVisibility true, tampilkan tombol eye
              suffixIcon: trailingCheck != null
                  ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  trailingCheck! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 26,
                  color: trailingCheck! ? _green : _errorRed,
                ),
              )
                  : (showVisibility
                  ? IconButton(
                onPressed: onToggleShow,
                icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: _textDark),
              )
                  : null),
            ),
            enableSuggestions: false,
            autocorrect: false,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(color: _errorRed)),
        ],
      ],
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final String password;
  const _PasswordStrengthBar({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = _measureStrength(password);
    final level = s == _PwdStrength.weak ? 1 : s == _PwdStrength.medium ? 2 : 3;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i < level;
          return Expanded(
            child: Container(
              height: 10,
              margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
              decoration: BoxDecoration(
                color: active ? _strengthColor(s) : const Color(0x335C6B7A),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PasswordMinCapsules4 extends StatelessWidget {
  final String password;
  const _PasswordMinCapsules4({required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLen = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    Widget cap(String text, bool ok) => Expanded(
      child: Container(
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ok ? _green : const Color(0x335C6B7A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          cap('≥ 8', hasLen),
          const SizedBox(width: 8),
          cap('Huruf', hasLetter),
          const SizedBox(width: 8),
          cap('Angka', hasDigit),
          const SizedBox(width: 8),
          cap('Simbol', hasSymbol),
        ],
      ),
    );
  }
}

/* ===== VerifyTile (widget publik, dipakai di bottom-sheet) ===== */
class VerifyTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const VerifyTile({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        onTap: enabled ? onTap : null,
        tileColor: const Color(0xFF22315E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2F4175),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: _subtle),
        ),
      ),
    );
  }
}
