import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/donation_service.dart';
import 'PaymentWebViewScreen.dart';

/* ===== PALETTE ===== */
const _bgBlue   = Color(0xFF0B1446);
const _cardBlue = Color(0xFF152449);
const _stroke   = Color(0xFF2A3C6C);
const _accent   = Color(0xFF7B8AFF);
const _accent2  = Color(0xFF9AA6FF);
const _green    = Color(0xFF22C55E);

/* ===== MODEL KAMPANYE (seed awal; total akan ditambah dari Firestore) ===== */
class DonationCampaign {
  final String id, title, org, category, imageUrl, description;
  final int goal, collected;
  const DonationCampaign({
    required this.id, required this.title, required this.org, required this.category,
    required this.imageUrl, required this.description, required this.goal, required this.collected,
  });
  double get progress => goal == 0 ? 0 : (collected / goal).clamp(0, 1);
}

const _seed = <DonationCampaign>[
  DonationCampaign(
    id: 'c1',
    title: 'Dukungan Peralatan Lari Aksesibel',
    org: 'RUNARA Care',
    category: 'Peralatan',
    imageUrl: 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?q=80&w=1600&auto=format&fit=crop',
    description: 'Tongkat pandu, rompi relawan, sepatu lari untuk kegiatan pendampingan yang aman.',
    goal: 50000000, collected: 24500000,
  ),
  DonationCampaign(
    id: 'c2',
    title: 'Pelatihan Pendamping Tunanetra',
    org: 'Komunitas Lari Inklusif',
    category: 'Pelatihan',
    imageUrl: 'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?q=80&w=1600&auto=format&fit=crop',
    description: 'Workshop teknik sighted guide & keselamatan rute bagi relawan baru.',
    goal: 30000000, collected: 16000000,
  ),
  DonationCampaign(
    id: 'c3',
    title: 'Transport & Konsumsi Sesi Mingguan',
    org: 'RUNARA Community',
    category: 'Operasional',
    imageUrl: 'https://images.unsplash.com/photo-1520975682031-ae4c3aab7b37?q=80&w=1600&auto=format&fit=crop',
    description: 'Biaya transport relawan & snack seusai latihan terjadwal.',
    goal: 20000000, collected: 7200000,
  ),
];

/* ===== AGGREGATE MODEL (amount + donor count) ===== */
class _Agg { final int amount; final int donors; const _Agg(this.amount, this.donors); }

class DonasiPageScreen extends StatefulWidget {
  const DonasiPageScreen({super.key});
  @override
  State<DonasiPageScreen> createState() => _DonasiPageScreenState();
}

class _DonasiPageScreenState extends State<DonasiPageScreen> {
  final _searchC = TextEditingController();
  final _svc = DonationService();

  String _q = '';
  String _cat = 'Semua';
  final _cats = const ['Semua', 'Peralatan', 'Pelatihan', 'Operasional'];

  List<DonationCampaign> get _filtered {
    Iterable<DonationCampaign> s = _seed;
    if (_cat != 'Semua') s = s.where((e) => e.category == _cat);
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      s = s.where((e) => e.title.toLowerCase().contains(q) || e.org.toLowerCase().contains(q));
    }
    final list = s.toList();
    list.sort((a,b)=>a.progress.compareTo(b.progress)); // yang progress-nya rendah di atas
    return list;
  }

  // Sum semua donasi sukses per campaignId (amount + donor count)
  Stream<Map<String,_Agg>> _successAggsStream() {
    final q = FirebaseFirestore.instance
        .collection('donations')
        .where('status', whereIn: ['success','settlement','capture']);
    return q.snapshots().map((snap) {
      final m = <String,_Agg>{};
      for (final d in snap.docs) {
        final data = d.data();
        final cid = (data['campaignId'] ?? '').toString();
        final amt = (data['amount'] as num?)?.toInt() ?? 0;
        if (cid.isEmpty || amt <= 0) continue;
        final cur = m[cid];
        if (cur == null) {
          m[cid] = _Agg(amt, 1);
        } else {
          m[cid] = _Agg(cur.amount + amt, cur.donors + 1);
        }
      }
      return m;
    });
  }

  void _handleBack() { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }
  @override void dispose() { _searchC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            /* ===== TOP BAR ala Kitabisa ===== */
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              child: Row(
                children: [
                  InkWell(
                    onTap: _handleBack,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white10, borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Image.asset('assets/ic_back.png', width: 18, height: 18,
                          errorBuilder: (_, __, ___)=>const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Donasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                        SizedBox(height: 2),
                        Text('Bersama wujudkan lari yang inklusif', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /* ===== SEARCH FIELD ===== */
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  border: Border.all(color: _stroke),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchC,
                        onChanged: (v)=>setState(()=>_q=v.trim()),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Cari kampanye, organisasi…',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_q.isNotEmpty)
                      GestureDetector(
                        onTap: () { _searchC.clear(); setState(()=>_q=''); },
                        child: const Icon(Icons.close, color: Colors.white54, size: 18),
                      )
                  ],
                ),
              ),
            ),

            /* ===== CATEGORY TABS (segmented style) ===== */
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: _cats.map((c){
                    final sel = c == _cat;
                    return Expanded(
                      child: InkWell(
                        onTap: ()=>setState(()=>_cat=c),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: sel? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(4),
                          child: Text(c,
                            style: TextStyle(
                                color: sel? Colors.black : Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            /* ===== LIST + IMPACT REALTIME ===== */
            Expanded(
              child: StreamBuilder<Map<String,_Agg>>(
                stream: _successAggsStream(),
                builder: (context, snap) {
                  final aggs = snap.data ?? const <String,_Agg>{};
                  final items = _filtered;

                  // ringkasan kecil ala Kitabisa
                  final totalAll = aggs.values.fold<int>(0, (p, a)=>p+a.amount);
                  final donorsAll = aggs.values.fold<int>(0, (p, a)=>p+a.donors);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0x22152449), Color(0x113A4C86)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ImpactPill(title: 'Terkumpul', value: _idr(totalAll)),
                              const VerticalDivider(color: Colors.white12, thickness: 1, width: 1, indent: 14, endIndent: 14),
                              _ImpactPill(title: 'Donatur', value: _fmtInt(donorsAll)),
                              const VerticalDivider(color: Colors.white12, thickness: 1, width: 1, indent: 14, endIndent: 14),
                              _ImpactPill(title: 'Kampanye', value: '${items.length}'),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('Kampanye tidak ditemukan.', style: TextStyle(color: Colors.white70)))
                            : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __)=>const SizedBox(height: 12),
                          itemBuilder: (_, i){
                            final base = items[i];
                            final agg  = aggs[base.id];
                            final collected = base.collected + (agg?.amount ?? 0);
                            final donors    = (agg?.donors ?? 0);
                            final progress  = base.goal==0? 0.0 : (collected / base.goal).clamp(0.0, 1.0);
                            return _CampaignCard(
                              c: base,
                              collected: collected,
                              progress: progress,
                              donors: donors,
                              onDonate: ()=>_openDonateSheet(base),
                              onTap: ()=>_openDetail(base, collected, progress, donors),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(DonationCampaign c, int collected, double progress, int donors) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=> SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16,14,16,16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width:44, height:5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height:12),

              // HERO with overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16/9,
                      child: Image.network(
                        c.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___)=> Container(
                          color: Colors.white12, alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(.4)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12, right: 12, bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(c.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2)),
                        ),
                        const SizedBox(width: 8),
                        _CategoryPill(text: c.category),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _ProgressBar(progress: progress, collected: collected, goal: c.goal),
              const SizedBox(height: 8),

              Row(
                children: [
                  _TinyBadge(icon: Icons.verified_rounded, text: c.org),
                  const SizedBox(width: 8),
                  _TinyBadge(icon: Icons.people_alt_rounded, text: '${_fmtInt(donors)} donatur'),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  child: Text(c.description, style: const TextStyle(color: Colors.white70, height: 1.5)),
                ),
              ),
              const SizedBox(height: 12),

              // payment icons (dummy)
              Row(
                children: [
                  _PayIcon('QRIS'), const SizedBox(width: 8),
                  _PayIcon('OVO'), const SizedBox(width: 8),
                  _PayIcon('GoPay'), const SizedBox(width: 8),
                  _PayIcon('ShopeePay'), const Spacer(),
                  Text('Metode bayar', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _openDonateSheet(c); },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.transparent,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_accent, _accent2]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Donasi Sekarang', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDonateSheet(DonationCampaign c) async {
    final result = await showModalBottomSheet<_DonateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=> _DonateSheet(campaign: c),
    );
    if (result == null) return;

    // MOCK back-end: buat order (status pending) -> PaymentWebViewScreen men-set success → UI auto naik karena Stream
    final init = await _svc.startDonation(
      amount: result.amount,
      donorName: 'Anonim',
      message: 'Donasi untuk ${c.title}',
      campaignId: c.id,
      channel: 'mock',
      extra: {'campaignTitle': c.title, 'method': result.method},
    );

    final orderId = (init['orderId'] ?? '').toString();
    final redirectUrl = (init['redirectUrl'] ?? 'about:blank').toString();

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_)=> PaymentWebViewScreen(orderId: orderId, redirectUrl: redirectUrl),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;
    if (ok == true) {
      _toast('Terima kasih! Donasi kamu tercatat.');
    } else {
      _toast('Kamu bisa melanjutkan pembayaran kapan saja.');
    }
  }

  void _toast(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ===== SUBWIDGETS ===== */

class _ImpactPill extends StatelessWidget {
  final String title, value;
  const _ImpactPill({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final DonationCampaign c;
  final int collected;
  final double progress;
  final int donors;
  final VoidCallback onTap;
  final VoidCallback onDonate;
  const _CampaignCard({
    required this.c,
    required this.collected,
    required this.progress,
    required this.donors,
    required this.onTap,
    required this.onDonate,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // banner with overlay + category
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16/9,
                    child: Image.network(
                      c.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___)=> Container(color: Colors.white12, alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, color: Colors.white54)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(.35)],
                      ),
                    ),
                  ),
                ),
                Positioned(left: 10, top: 10, child: _CategoryPill(text: c.category)),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.25)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.verified_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(c.org, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),

                  // progress
                  _ProgressBar(progress: progress, collected: collected, goal: c.goal),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(child: Text('Terkumpul ${_idr(collected)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text('${_fmtInt(donors)} donatur', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _green.withOpacity(.4)),
                        ),
                        child: Text('$percent%',
                            style: const TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 12)),
                      )
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onDonate,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.transparent,
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_accent, _accent2]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Donasi', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
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
}

class _ProgressBar extends StatelessWidget {
  final double progress; final int collected; final int goal;
  const _ProgressBar({required this.progress, required this.collected, required this.goal});
  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        Container(height: 10,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20))),
        FractionallySizedBox(
          widthFactor: p,
          child: Container(height: 10, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accent2]),
              borderRadius: BorderRadius.circular(20))),
        ),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Target ${_idr(goal)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    ]);
  }
}

class _CategoryPill extends StatelessWidget {
  final String text; const _CategoryPill({required this.text});
  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (text) {
      case 'Peralatan': bg = const Color(0xFF38BDF8); break;
      case 'Pelatihan': bg = const Color(0xFF22C55E); break;
      case 'Operasional': bg = const Color(0xFFFF9B2F); break;
      default: bg = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)]),
      child: Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11, height: 1.0)),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final IconData icon; final String text;
  const _TinyBadge({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

class _PayIcon extends StatelessWidget {
  final String label;
  const _PayIcon(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

/* ===== DONATE SHEET (pilih nominal + metode) ===== */

class _DonateResult { final int amount; final String method;
_DonateResult(this.amount, this.method); }

class _DonateSheet extends StatefulWidget {
  final DonationCampaign campaign;
  const _DonateSheet({required this.campaign});
  @override
  State<_DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<_DonateSheet> {
  final _customC = TextEditingController();
  final _presets = const [10000, 25000, 50000, 100000, 250000, 500000];
  int? _amount; String? _method;

  @override void dispose(){ _customC.dispose(); super.dispose(); }

  void _pick(int v){ setState((){ _amount=v; _customC.clear(); }); }
  void _onCustom(String v){
    final d = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
    setState(()=> _amount = (d==null || d<=0) ? null : d);
  }

  void _submit(){
    final a = _amount ?? 0;
    if (a<=0) { _toast('Isi nominal donasi.'); return; }
    if (_method == null) { _toast('Pilih metode pembayaran.'); return; }
    Navigator.pop(context, _DonateResult(a, _method!));
  }
  void _toast(String m)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: .78, minChildSize: .5, maxChildSize: .95,
        builder: (_, scroll)=> Container(
          decoration: const BoxDecoration(
            color: _cardBlue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16,14,16,16),
            child: Column(children: [
              Container(width:44, height:5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text('Donasi untuk\n${c.title}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2))),
                _CategoryPill(text: c.category),
              ]),
              const SizedBox(height: 12),

              Expanded(child: SingleChildScrollView(
                controller: scroll,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pilih nominal cepat', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: _presets.map((v){
                    final sel=_amount==v;
                    return ChoiceChip(
                      selected: sel,
                      label: Text(_idr(v), style: TextStyle(color: sel? Colors.black: Colors.white, fontWeight: FontWeight.w800)),
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white10,
                      shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
                      onSelected: (_)=>_pick(v),
                    );
                  }).toList()),
                  const SizedBox(height: 10),

                  const Text('Nominal lain', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Container(
                    height: 50,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.05),
                        border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      const Text('Rp', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: _customC, keyboardType: TextInputType.number, onChanged: _onCustom,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Contoh: 150000', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
                      )),
                    ]),
                  ),

                  const SizedBox(height: 18),
                  const Text('Metode Pembayaran', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in const ['qris','gopay','ovo','shopeepay','bca','bni','bri'])
                      ChoiceChip(
                        selected: _method==m,
                        label: Text(m.toUpperCase(), style: TextStyle(color: _method==m? Colors.black: Colors.white, fontWeight: FontWeight.w800)),
                        selectedColor: Colors.white,
                        backgroundColor: Colors.white10,
                        shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
                        onSelected: (_)=> setState(()=>_method=m),
                      ),
                  ]),

                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.04),
                        borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Ringkasan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Nominal: ${_amount!=null? _idr(_amount!) : '-'}', style: const TextStyle(color: Colors.white70)),
                        Text('Metode: ${_method?.toUpperCase() ?? '-'}', style: const TextStyle(color: Colors.white70)),
                      ])),
                    ]),
                  ),
                ]),
              )),
              const SizedBox(height: 12),

              SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.transparent,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_accent, _accent2]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('Konfirmasi & Bayar', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

/* ===== Helpers ===== */
String _idr(int v){
  final s = v.toString(); final buf = StringBuffer(); int c=0;
  for (int i=s.length-1;i>=0;i--){ buf.write(s[i]); c++; if (c==3 && i!=0){ buf.write('.'); c=0; } }
  return 'Rp ${buf.toString().split('').reversed.join()}';
}

String _fmtInt(int v){
  if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}jt';
  if (v >= 1000) return '${(v/1000).toStringAsFixed(0)}rb';
  return v.toString();
}
