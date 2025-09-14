import 'package:flutter/material.dart';

class CariPendampingPageScreen extends StatefulWidget {
  const CariPendampingPageScreen({Key? key}) : super(key: key);

  @override
  State<CariPendampingPageScreen> createState() => _CariPendampingPageScreenState();
}

/* ========================= MODEL & DUMMY DATA ========================= */

class _Profile {
  final String name;
  final String role; // 'Tunanetra' | 'Relawan'
  final String city;
  final String imageUrl;

  const _Profile({
    required this.name,
    required this.role,
    required this.city,
    required this.imageUrl,
  });
}

const _profilesSeed = <_Profile>[
  _Profile(
    name: 'Aldy Giovani',
    role: 'Tunanetra',
    city: 'Bandung',
    imageUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=300',
  ),
  _Profile(
    name: 'Sinta Dewi',
    role: 'Tunanetra',
    city: 'Bandung',
    imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=300',
  ),
  _Profile(
    name: 'Bima Pratama',
    role: 'Relawan',
    city: 'Jakarta',
    imageUrl: 'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?q=80&w=300',
  ),
  _Profile(
    name: 'Laras Sekar',
    role: 'Relawan',
    city: 'Bandung',
    imageUrl: 'https://images.unsplash.com/photo-1524502397800-2eeaad7c3fe5?q=80&w=300',
  ),
];

/* ================================ UI ================================ */

class _CariPendampingPageScreenState extends State<CariPendampingPageScreen> {
  // palette
  static const _bg = Color(0xFF0B1446);
  static const _card = Color(0xFF1A2A6C);
  static const _stroke = Color(0xFF4B5B9E);
  static const _accent = Color(0xFF7B8AFF);
  static const _accentSoft = Color(0xFF9AA6FF);

  final TextEditingController _searchC = TextEditingController();
  String _selectedCity = 'Bandung';
  String _query = '';
  String _roleFilter = 'Semua'; // Semua | Tunanetra | Relawan

  List<String> get _cities {
    final set = _profilesSeed.map((e) => e.city).toSet().toList()..sort();
    return set;
  }

  List<_Profile> get _filtered {
    return _profilesSeed.where((p) {
      final hitCity = p.city == _selectedCity;
      final hitQuery = _query.isEmpty || p.name.toLowerCase().contains(_query);
      final hitRole = _roleFilter == 'Semua' || p.role == _roleFilter;
      return hitCity && hitQuery && hitRole;
    }).toList();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _openProfileSheet(_Profile p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF152449),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 44, height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 16),

                // ⬇️ Bagian ini juga bisa diklik untuk masuk ke detail
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PendampingDetailPage(profile: p),
                    ));
                  },
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          p.imageUrl,
                          width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64, height: 64, color: Colors.white10,
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RolePill(role: p.role),
                            const SizedBox(height: 6),
                            Text(p.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.white60),
                                const SizedBox(width: 4),
                                Text(p.city, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  'Deskripsi singkat calon pendamping / tunanetra. Kamu bisa melihat riwayat sesi, preferensi, dan jam ketersediaan.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PendampingDetailPage(profile: p),
                          ));
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Detail'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Permintaan terhubung dikirim ke ${p.name}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Hubungkan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ==== Header: back (pakai ic_back.png) + title ====
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  _BackButton(
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Cari Pendamping',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),

            // ==== Search + City ====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.04),
                        border: Border.all(color: _stroke),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchC,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                              decoration: const InputDecoration(
                                hintText: 'Cari nama…',
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
                  const SizedBox(width: 10),
                  // City dropdown
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.04),
                      border: Border.all(color: _stroke),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        dropdownColor: const Color(0xFF0F1C55),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        style: const TextStyle(color: Colors.white),
                        items: _cities
                            .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _selectedCity = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Role filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _roleFilter == 'Semua',
                    onTap: () => setState(() => _roleFilter = 'Semua'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Tunanetra',
                    selected: _roleFilter == 'Tunanetra',
                    onTap: () => setState(() => _roleFilter = 'Tunanetra'),
                    color: const Color(0xFFFF7A00),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Relawan',
                    selected: _roleFilter == 'Relawan',
                    onTap: () => setState(() => _roleFilter = 'Relawan'),
                    color: _accentSoft,
                  ),
                ],
              ),
            ),

            // ==== Grid ====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _filtered.isEmpty
                    ? const Center(
                  child: Text(
                    'Tidak ada hasil.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
                    : GridView.builder(
                  itemCount: _filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: .74,
                  ),
                  itemBuilder: (context, i) {
                    final p = _filtered[i];
                    return _ProfileCard(
                      profile: p,
                      onTap: () => _openProfileSheet(p),
                      onConnectTap: () => _openProfileSheet(p),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ======================== REUSABLE WIDGETS ======================== */

class _BackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _BackButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Image.asset(
          'assets/ic_back.png',
          width: 18,
          height: 18,
          // kalau asset belum ada/ gagal, fallback ke icon bawaan
          errorBuilder: (_, __, ___) => const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : Colors.white70;
    final bg = selected ? (color ?? Colors.white) : Colors.white.withOpacity(.05);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final _Profile profile;
  final VoidCallback onTap;
  final VoidCallback onConnectTap;

  const _ProfileCard({
    Key? key,
    required this.profile,
    required this.onTap,
    required this.onConnectTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const stroke = Color(0xFF4B5B9E);
    const card = Color(0xFF1A2A6C);
    const accent = Color(0xFF7B8AFF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stroke, width: 1.8),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                profile.imageUrl,
                height: 86, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 86, color: Colors.white10,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person, color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _RolePill(role: profile.role),
            const SizedBox(height: 6),
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.white60),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    profile.city,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: onConnectTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Hubungkan',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final isTunanetra = role == 'Tunanetra';
    final bg = isTunanetra ? const Color(0xFFFF7A00) : const Color(0xFF9AA6FF);
    final fg = isTunanetra ? Colors.black : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        role,
        style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 11, height: 1.0),
      ),
    );
  }
}

/* ===================== DETAIL PAGE ===================== */

class PendampingDetailPage extends StatelessWidget {
  final _Profile profile;
  const PendampingDetailPage({Key? key, required this.profile}) : super(key: key);

  static const _bg = Color(0xFF0B1446);
  static const _card = Color(0xFF152449);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header dengan ic_back.png
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/ic_back.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Detail Pendamping',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      profile.imageUrl,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.white10,
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, size: 40, color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _RolePill(role: profile.role),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 16, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(profile.city, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(14),
                    child: const Text(
                      'Bio singkat / preferensi / pengalaman mendampingi / kebutuhan khusus. '
                          'Tambahkan informasi jadwal tersedia atau jarak ideal bertemu.',
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _StatBox(label: 'Sesi', value: '12'),
                        _StatBox(label: 'Rating', value: '4.9'),
                        _StatBox(label: 'Jarak', value: '≤ 5 km'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Permintaan terhubung dikirim ke ${profile.name}')),
                        );
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Hubungkan Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF7B8AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
