import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* =========================== PALETTE =========================== */
const _bgBlue   = Color(0xFF0B1446);
const _cardBlue = Color(0xFF152449);
const _stroke   = Color(0xFF2A3C6C);
const _accent   = Color(0xFF7B8AFF);
const _accent2  = Color(0xFF9AA6FF);

/* ====================== MODEL & SEED DATA ====================== */

class TipItem {
  final int id;
  final String title;
  final String snippet;
  final String body;
  final String category; // 'Lari Aman' | 'Navigasi' | 'Nutrisi' | 'Peralatan'
  final int minutes;     // waktu baca
  final IconData icon;

  const TipItem({
    required this.id,
    required this.title,
    required this.snippet,
    required this.body,
    required this.category,
    required this.minutes,
    required this.icon,
  });
}

const List<TipItem> _tipsSeed = [
  TipItem(
    id: 1,
    title: 'Pemanasan 5 Menit Sebelum Lari',
    snippet: 'Kurangi risiko cedera dengan peregangan dinamis.',
    body:
    'Mulai dengan jalan cepat 1–2 menit, lanjutkan leg swing (10x per kaki), '
        'ankle circles (10x), hip rotation, dan high-knees 30 detik. '
        'Tujuannya menaikkan suhu tubuh & aktivasi otot sebelum intensitas meningkat.',
    category: 'Lari Aman',
    minutes: 2,
    icon: Icons.directions_run_rounded,
  ),
  TipItem(
    id: 2,
    title: 'Teknik Pendampingan Tunanetra',
    snippet: 'Gunakan “Sighted Guide Technique” yang benar.',
    body:
    'Tawarkan siku bagian luar, biarkan tangan penerima bantuan menggenggam '
        'di atas siku. Jalan setengah langkah di depan, narasikan rintangan, '
        'dan gunakan kata spesifik (mis. “tangga 3 anak turun”). Jaga ritme stabil.',
    category: 'Navigasi',
    minutes: 3,
    icon: Icons.volunteer_activism_rounded,
  ),
  TipItem(
    id: 3,
    title: 'Hidrasi dan Asupan Sederhana',
    snippet: 'Minum 200–300 ml 20 menit sebelum lari.',
    body:
    'Jangan menunggu haus. Untuk lari ≤60 menit, air putih cukup. '
        'Jika lebih lama/berkeringat deras, pertimbangkan minuman elektrolit. '
        'Setelah lari, rehidrasi dan konsumsi karbo + protein ringan.',
    category: 'Nutrisi',
    minutes: 2,
    icon: Icons.local_drink_rounded,
  ),
  TipItem(
    id: 4,
    title: 'Sepatu & Tongkat yang Nyaman',
    snippet: 'Pilih sepatu dengan cushioning sedang & grip baik.',
    body:
    'Pastikan ukuran sesuai, ada ruang 1 jari di depan. Periksa outsole tidak licin. '
        'Untuk pengguna tongkat, cek ujung/ferrule tidak aus agar feedback permukaan tetap jelas.',
    category: 'Peralatan',
    minutes: 2,
    icon: Icons.hiking_rounded,
  ),
  TipItem(
    id: 5,
    title: 'Narasi Lingkungan Saat Berlari',
    snippet: 'Bantu orientasi dengan deskripsi ringkas namun spesifik.',
    body:
    'Sebutkan perubahan tekstur jalan, belokan, kontur naik/turun, dan keramaian. '
        'Gunakan istilah konsisten, mis. “3 langkah lagi ke trotoar naik”. '
        'Komunikasi dua arah, konfirmasi jika perlu lebih lambat/lebih jelas.',
    category: 'Navigasi',
    minutes: 3,
    icon: Icons.record_voice_over_rounded,
  ),
];

/* ========================= MAIN WIDGET ========================= */

class TipsPageScreen extends StatefulWidget {
  const TipsPageScreen({super.key});

  @override
  State<TipsPageScreen> createState() => _TipsPageScreenState();
}

class _TipsPageScreenState extends State<TipsPageScreen> {
  // Search & filter
  final _searchC = TextEditingController();
  String _query = '';
  String _category = 'Semua';
  bool _showSavedOnly = false;

  // Saved/bookmarks
  static const _prefsKey = 'tips_bookmarks';
  final Set<int> _saved = <int>{};

  List<String> get _categories => const [
    'Semua',
    'Lari Aman',
    'Navigasi',
    'Nutrisi',
    'Peralatan',
  ];

  List<TipItem> get _filtered {
    Iterable<TipItem> src = _tipsSeed;
    if (_category != 'Semua') {
      src = src.where((t) => t.category == _category);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      src = src.where((t) =>
      t.title.toLowerCase().contains(q) ||
          t.snippet.toLowerCase().contains(q) ||
          t.body.toLowerCase().contains(q));
    }
    if (_showSavedOnly) {
      src = src.where((t) => _saved.contains(t.id));
    }
    return src.toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? const [];
    setState(() {
      _saved
        ..clear()
        ..addAll(ids.map(int.parse));
    });
  }

  Future<void> _persistSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _saved.map((e) => e.toString()).toList(),
    );
  }

  void _toggleSave(TipItem t) async {
    setState(() {
      if (_saved.contains(t.id)) {
        _saved.remove(t.id);
      } else {
        _saved.add(t.id);
      }
    });
    await _persistSaved();
  }

  Future<void> _openTip(TipItem t) async {
    final saved = _saved.contains(t.id);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, scroll) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryIcon(icon: t.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TipCategoryPill(text: t.category),
                              const SizedBox(height: 6),
                              Text(
                                t.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 14, color: Colors.white60),
                                  const SizedBox(width: 6),
                                  Text('${t.minutes} menit',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _toggleSave(t);
                          },
                          icon: Icon(
                            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: saved ? _accent : Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scroll,
                        child: Text(
                          t.body,
                          style: const TextStyle(color: Colors.white, height: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tip “${t.title}” diselesaikan. 👍'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Selesai Dibaca'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (mounted) setState(() {});
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // Ganti '/home' sesuai route home kamu
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap kosong menutup keyboard
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _bgBlue,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ========== TOP BAR KUSTOM ==========
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  children: [
                    // Back icon (pakai asset ic_back.png)
                    InkWell(
                      onTap: _handleBack,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/ic_back.png',
                          width: 18,
                          height: 18,
                          // fallback kalau asset belum tersedia
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tips & Edukasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    // Toggle "Tersimpan"
                    FilterChip(
                      selected: _showSavedOnly,
                      onSelected: (v) => setState(() => _showSavedOnly = v),
                      backgroundColor: Colors.white10,
                      selectedColor: _accent.withOpacity(.25),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showSavedOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text('Tersimpan', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                      shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
                    ),
                  ],
                ),
              ),

              // ========== SEARCH ==========
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.05),
                    border: Border.all(color: _stroke),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchC,
                          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Cari tip…',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchC.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.close, color: Colors.white54, size: 18),
                        ),
                    ],
                  ),
                ),
              ),

              // ========== CATEGORY FILTER ==========
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _categories[i];
                    final sel = c == _category;
                    return InkWell(
                      onTap: () => setState(() => _category = c),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: sel ? Colors.white : Colors.white.withOpacity(.06),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c,
                          style: TextStyle(
                            color: sel ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // ========== LIST TIPS ==========
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _filtered.isEmpty
                      ? const Center(
                    child: Text('Tidak ada tip.', style: TextStyle(color: Colors.white70)),
                  )
                      : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final t = _filtered[i];
                      final saved = _saved.contains(t.id);
                      return _TipCard(
                        tip: t,
                        saved: saved,
                        onTap: () => _openTip(t),
                        onToggleSave: () => _toggleSave(t),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ========================= SUB WIDGETS ========================= */

class _TipCard extends StatelessWidget {
  final TipItem tip;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _TipCard({
    required this.tip,
    required this.saved,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryIcon(icon: tip.icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TipCategoryPill(text: tip.category),
                  const SizedBox(height: 6),
                  Text(
                    tip.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Colors.white60),
                      const SizedBox(width: 6),
                      Text('${tip.minutes} menit',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onToggleSave,
              icon: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? _accent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  const _CategoryIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: _accent2),
    );
  }
}

class _TipCategoryPill extends StatelessWidget {
  final String text;
  const _TipCategoryPill({required this.text});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (text) {
      case 'Lari Aman':
        bg = const Color(0xFFFF9B2F);
        break;
      case 'Navigasi':
        bg = const Color(0xFF7B8AFF);
        break;
      case 'Nutrisi':
        bg = const Color(0xFF22C55E);
        break;
      case 'Peralatan':
        bg = const Color(0xFF38BDF8);
        break;
      default:
        bg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          height: 1.0,
        ),
      ),
    );
  }
}
