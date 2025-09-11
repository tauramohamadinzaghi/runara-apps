import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import the Markdown package

void main() {
  runApp(MaterialApp(
    home: BantuanPageScreen(),
  ));
}

class BantuanPageScreen extends StatefulWidget {
  const BantuanPageScreen({Key? key}) : super(key: key);

  @override
  _BantuanPageScreenState createState() => _BantuanPageScreenState();
}

class _BantuanPageScreenState extends State<BantuanPageScreen> {
  String userName = ""; // Nama pengguna yang akan diambil dari Firebase
  int _tabIndex = 0; // Initially show 'Hubungi Kami'

  // Colors
  static const _blue500 = Color(0xFF3B82F6);
  static const _headerColor = Color(0xFF152449); // Header color (Blue)

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak bisa membuka ${uri.toString()}')),
      );
    }
  }

  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userName = user.displayName ?? 'Tidak ada nama'; // Ambil nama dari Firebase Authentication
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Ambil nama pengguna setelah login
  }

  Widget _tabs() {
    final baseBtn = ButtonStyle(
      overlayColor: MaterialStateProperty.all(Colors.transparent),
      padding: MaterialStateProperty.all(EdgeInsets.zero),
      elevation: MaterialStateProperty.all(0),
    );

    Widget tabBtn({
      required String text,
      required bool active,
      required VoidCallback onTap,
    }) {
      return TextButton(
        style: baseBtn,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _blue500 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: active ? _blue500 : Colors.white70,
              letterSpacing: .2,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              tabBtn(
                text: 'HUBUNGI KAMI',
                active: _tabIndex == 0,
                onTap: () => setState(() => _tabIndex = 0),
              ),
              const SizedBox(width: 24),
              tabBtn(
                text: 'FAQ',
                active: _tabIndex == 1,
                onTap: () => setState(() => _tabIndex = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _contactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Image.asset(
              'assets/icon_help_center.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const Center(
          child: Text(
            'Siap membantumu kapan pun',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _blue500,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 320,
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  const TextSpan(text: 'Hai, '),
                  TextSpan(
                    text: userName.isEmpty ? 'Tidak ada nama' : userName, // Tampilkan nama pengguna
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const TextSpan(text: '. Silakan hubungi kami kapan saja melalui.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white12),
              bottom: BorderSide(color: Colors.white12),
            ),
          ),
          child: Row(
            children: [
              _ContactItem(
                icon: Icons.phone,
                label: 'Telepon',
                onTap: () => _open(Uri.parse('tel:082112430738')),
              ),
              _DividerY(),
              _ContactItem(
                icon: Icons.chat_bubble,
                label: 'Chat',
                onTap: () => _open(Uri.parse('https://wa.me/6282112430738?text=Halo%20Help%20Center')),
              ),
              _DividerY(),
              _ContactItem(
                icon: Icons.email_outlined,
                label: 'E-mail',
                onTap: () => _open(Uri.parse('mailto:tauramohamadinzaghi@apps.ipb.ac.id')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _LinkRow(
          text: 'Berikan Masukanmu',
          onTap: () => _open(Uri.parse('https://wa.me/6282112430738?text=Halo%20Help%20Center')),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 320,
          child: Text(
            'Kirimkan saran, kritik, atau pertanyaanmu agar kami dapat meningkatkan layanan.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        _LinkRow(
          text: 'Syarat & Ketentuan',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (context) {
                return SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    color: Color(0xFF152449),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Syarat & Ketentuan Penggunaan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        MarkdownBody(
                          data: '''# SYARAT & KETENTUAN PENGGUNAAN (Runara)
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
''',
                          styleSheet: MarkdownStyleSheet(
                            h1: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            p: TextStyle(color: Colors.white70, fontSize: 14),
                            strong: TextStyle(fontWeight: FontWeight.bold),
                            blockquote: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Menutup pop-up saat tombol ditekan
                          },
                          child: Text('Tutup'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 320,
          child: Text(
            'Kenali RUNARA lebih dekat dengan membaca syarat dan ketentuan yang berlaku.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.6, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _headerColor,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_headerColor, _headerColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        'assets/ic_back.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bantuan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tabs(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Temukan info yang kamu butuhkan seputar aplikasi RUNARA',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _tabIndex == 0 ? _contactContent() : Column(
                      children: [
                        const Text(
                          'Topik Populer',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade600),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: List.generate(10, (index) {
                                return ExpansionTile(
                                  backgroundColor: Colors.grey.shade800,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                  title: Text(
                                    _faqTitles[index],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        _faqDescriptions[index],
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Topik Lainnya',
                          style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(4, (index) {
                          return Card(
                            color: const Color(0xFF002A5B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              leading: Icon(
                                _otherTopicsIcons[index],
                                color: Colors.blue.shade400,
                                size: 32,
                              ),
                              title: Text(
                                _otherTopicsTitles[index],
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                _otherTopicsDescriptions[index],
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Kontak Help Center',
                      style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Untuk pertanyaan lainnya, Anda dapat menghubungi Help Center melalui:',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ContactButton(
                          icon: Icons.chat,
                          color: Colors.green.shade400,
                          text: 'WhatsApp',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 16),
                        ContactButton(
                          icon: Icons.phone,
                          color: Colors.blue.shade400,
                          text: 'Phone',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 16),
                        ContactButton(
                          icon: Icons.email,
                          color: Colors.yellow.shade400,
                          text: 'Email',
                          onPressed: () {},
                        ),
                      ],
                    ),
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


class ContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onPressed;

  const ContactButton({
    required this.icon,
    required this.color,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF002A5B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

const _faqTitles = [
  'Tidak Bisa Login',
  'Kesulitan Mendaftar Akun',
  'Pendamping Tidak Tersedia',
  'Tidak Bisa Menghubungi Pendamping',
  'Pengaturan Aplikasi Tidak Berfungsi',
  'Donasi Tidak Terkirim',
  'Permintaan Bantuan Tidak Diproses',
  'Riwayat Aktivitas Tidak Muncul',
  'Jadwal Pendamping Tidak Update',
  'Pesan Tidak Terkirim',
];

const _faqDescriptions = [
  'Jika Anda mengalami kesulitan untuk login...',
  'Pastikan semua data yang Anda masukkan...',
  'Jika Anda kesulitan menemukan pendamping...',
  'Pastikan nomor telepon atau kontak...',
  'Jika pengaturan aplikasi tidak merespon...',
  'Pastikan metode pembayaran yang Anda gunakan...',
  'Pastikan Anda sudah mengisi semua data...',
  'Pastikan Anda sudah login dengan akun...',
  'Pastikan aplikasi Anda terhubung ke internet...',
  'Periksa koneksi internet Anda...',
];

const _otherTopicsTitles = [
  'Cara Menggunakan Fitur Suara',
  'Keamanan Data Pengguna',
  'Notifikasi dan Pengingat',
  'FAQ Tambahan',
];

const _otherTopicsDescriptions = [
  'Fitur suara membantu pengguna tunanetra...',
  'Kami menjaga keamanan data Anda...',
  'Aktifkan notifikasi untuk mendapatkan...',
  'Temukan jawaban atas pertanyaan umum...',
];

const _otherTopicsIcons = [
  Icons.info,
  Icons.shield,
  Icons.notifications,
  Icons.question_answer,
];

// _ContactItem class for contact methods
class _ContactItem extends StatelessWidget {
  const _ContactItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const _gray400 = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 2),
            Icon(icon, size: 20, color: _gray400),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: _gray400,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.bold, // tebal
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _DividerY class to separate contact methods
class _DividerY extends StatelessWidget {
  const _DividerY();

  @override
  Widget build(BuildContext context) {
    Color? _gray;
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 44,
      color: _gray,
    );
  }
}

// _LinkRow class for links like 'Syarat & Ketentuan'
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  static const _blue500 = Color(0xFF3B82F6);
  static const _gray200 = Color(0xFFE5E7EB);
  static const _gray400 = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _gray200), // Garis pemisah di bawah
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: _blue500,
                  fontSize: 15,
                  fontWeight: FontWeight.bold, // Menambahkan font bold
                  height: 1.2,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _gray400),
          ],
        ),
      ),
    );
  }
}
