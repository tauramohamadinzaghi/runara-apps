import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/* ===== PALETTE ===== */
const _bgBlue   = Color(0xFF0B1446);
const _cardBlue = Color(0xFF152449);
const _stroke   = Color(0xFF2A3C6C);
const _accent   = Color(0xFF7B8AFF);
const _accent2  = Color(0xFF9AA6FF);
const _green    = Color(0xFF22C55E);
const _orange   = Color(0xFFFF9B2F);
const _cyan     = Color(0xFF38BDF8);

/* ===== MODEL ===== */
class Activity {
  final String id;
  final String type; // 'guide' | 'run' | 'walk' | lainnya
  final String title;
  final String location;
  final DateTime date;
  final double distanceM;
  final int durationS;
  final int calories;
  final List<LatLng> route;
  final String? notes;

  Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.location,
    required this.date,
    required this.distanceM,
    required this.durationS,
    required this.calories,
    required this.route,
    this.notes,
  });

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['date'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.tryParse('${d['date']}') ?? DateTime.now();

    // route bisa berupa List<GeoPoint> atau List<Map>{lat,lng}
    final raw = d['route'];
    final route = <LatLng>[];
    if (raw is List) {
      for (final it in raw) {
        if (it is GeoPoint) {
          route.add(LatLng(it.latitude, it.longitude));
        } else if (it is Map) {
          final lat = (it['lat'] ?? it['latitude']);
          final lng = (it['lng'] ?? it['longitude']);
          if (lat is num && lng is num) route.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    final distM = (d['distance_m'] as num?)?.toDouble() ?? 0;
    final durS  = (d['duration_s'] as num?)?.toInt() ?? 0;
    int cal     = (d['calories'] as num?)?.toInt() ?? 0;
    if (cal == 0 && distM > 0) {
      // fallback estimasi ≈60 kkal/km
      cal = (distM / 1000.0 * 60).round();
    }

    return Activity(
      id: doc.id,
      type: (d['type'] ?? 'run').toString(),
      title: (d['title'] ?? '').toString().isEmpty
          ? _defaultTitle((d['type'] ?? 'run').toString())
          : (d['title'] as String),
      location: (d['location'] ?? '').toString(),
      date: date,
      distanceM: distM,
      durationS: durS,
      calories: cal,
      route: route,
      notes: (d['notes'] as String?),
    );
  }

  static String _defaultTitle(String t) {
    switch (t) {
      case 'guide': return 'Pendampingan Lari';
      case 'walk':  return 'Jalan';
      default:      return 'Lari';
    }
  }

  double get distanceKm => distanceM / 1000.0;
  String get paceText {
    if (distanceM <= 0 || durationS <= 0) return '-';
    final secPerKm = durationS / (distanceM / 1000.0);
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm.round() % 60).toString().padLeft(2, '0');
    return '$m:$s /km';
  }
}

/* ===== PAGE ===== */
class RiwayatAktivitasPageScreen extends StatefulWidget {
  const RiwayatAktivitasPageScreen({super.key});

  @override
  State<RiwayatAktivitasPageScreen> createState() => _RiwayatAktivitasPageScreenState();
}

enum _Period { week, month, all }

class _RiwayatAktivitasPageScreenState extends State<RiwayatAktivitasPageScreen> {
  final _searchC = TextEditingController();
  String _q = '';
  String _type = 'Semua'; // Semua / Pendampingan / Lari / Jalan
  _Period _period = _Period.month;

  DateTime? _rangeStart(_Period p) {
    final now = DateTime.now();
    if (p == _Period.week) {
      final monday = now.subtract(Duration(days: (now.weekday - 1)));
      return DateTime(monday.year, monday.month, monday.day);
    }
    if (p == _Period.month) {
      return DateTime(now.year, now.month, 1);
    }
    return null;
  }

  Stream<List<Activity>> _streamActivities() {
    final start = _rangeStart(_period);
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('activities')
        .orderBy('date', descending: true);
    if (start != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    // type difilter client-side supaya tidak butuh index gabungan
    return q.snapshots().map((snap) {
      final all = snap.docs.map(Activity.fromDoc).toList();
      Iterable<Activity> list = all;
      if (_type != 'Semua') {
        final key = _type == 'Pendampingan' ? 'guide' : _type == 'Lari' ? 'run' : 'walk';
        list = list.where((a) => a.type == key);
      }
      if (_q.isNotEmpty) {
        final qq = _q.toLowerCase();
        list = list.where((a) =>
        a.title.toLowerCase().contains(qq) ||
            a.location.toLowerCase().contains(qq));
      }
      return list.toList();
    });
  }

  @override
  void dispose() { _searchC.dispose(); super.dispose(); }

  void _back() { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar: back + title
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: _back,
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
                  const Text('Riwayat Aktivitas',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
                          hintText: 'Cari judul / lokasi…',
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

            // Filters: Period segmented + Type chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  _Segmented(
                    value: _period,
                    onChanged: (v)=>setState(()=>_period=v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TypeChips(
                      value: _type,
                      onChanged: (v)=>setState(()=>_type=v),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: StreamBuilder<List<Activity>>(
                stream: _streamActivities(),
                builder: (context, snap) {
                  final list = snap.data ?? const <Activity>[];

                  // summary
                  final totalDist = list.fold<double>(0, (p, a)=>p + a.distanceM);
                  final totalDur  = list.fold<int>(0, (p, a)=>p + a.durationS);
                  final totalCal  = list.fold<int>(0, (p, a)=>p + a.calories);

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _SummaryRow(
                          distanceKm: totalDist / 1000.0,
                          durationS: totalDur,
                          calories: totalCal,
                        ),
                      ),
                      Expanded(
                        child: list.isEmpty
                            ? const Center(
                            child: Text('Belum ada aktivitas untuk periode ini.',
                                style: TextStyle(color: Colors.white70)))
                            : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: list.length,
                          separatorBuilder: (_, __)=>const SizedBox(height: 10),
                          itemBuilder: (_, i){
                            final a = list[i];
                            return _ActivityCard(
                              a: a,
                              onTap: ()=>_openDetail(a),
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

  Future<void> _openDetail(Activity a) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBlue,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=> SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _ActivityDetail(a: a),
        ),
      ),
    );
  }
}

/* ===== WIDGETS ===== */

class _Segmented extends StatelessWidget {
  final _Period value;
  final ValueChanged<_Period> onChanged;
  const _Segmented({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    Widget item(String label, _Period v) {
      final sel = value == v;
      return Expanded(
        child: InkWell(
          onTap: ()=>onChanged(v),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(color: sel ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
      );
    }

    return Container(
      height: 36,
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          item('Minggu', _Period.week),
          item('Bulan',  _Period.month),
          item('Semua',  _Period.all),
        ],
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeChips({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final items = ['Semua','Pendampingan','Lari','Jalan'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __)=>const SizedBox(width: 6),
        itemBuilder: (_, i){
          final v = items[i];
          final sel = v == value;
          Color pillColor;
          if (v == 'Pendampingan') pillColor = _cyan;
          else if (v == 'Lari') pillColor = _green;
          else if (v == 'Jalan') pillColor = _orange;
          else pillColor = Colors.white70;

          return ChoiceChip(
            label: Text(v, style: TextStyle(
                color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            selected: sel,
            selectedColor: pillColor,
            backgroundColor: Colors.white10,
            shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
            onSelected: (_)=>onChanged(v),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double distanceKm; final int durationS; final int calories;
  const _SummaryRow({required this.distanceKm, required this.durationS, required this.calories});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x22152449), Color(0x113A4C86)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryTile(icon: Icons.route, label: 'Jarak', value: _fmtKm(distanceKm)),
          _DividerV(),
          _SummaryTile(icon: Icons.timer_rounded, label: 'Durasi', value: _fmtDur(durationS)),
          _DividerV(),
          _SummaryTile(icon: Icons.local_fire_department, label: 'Kalori', value: _fmtKcal(calories)),
        ],
      ),
    );
  }
}

class _DividerV extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: VerticalDivider(color: Colors.white12, width: 1, thickness: 1),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _SummaryTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Activity a;
  final VoidCallback onTap;
  const _ActivityCard({required this.a, required this.onTap});

  Color get _tagColor {
    switch (a.type) {
      case 'guide': return _cyan;
      case 'walk':  return _orange;
      default:      return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _fmtDate(a.date);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // tag warna
            Container(width: 6, height: 88,
              decoration: BoxDecoration(
                color: _tagColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            const SizedBox(width: 10),
            // konten
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // judul + tanggal
                    Row(
                      children: [
                        Expanded(
                          child: Text(a.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        Text(dateText, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (a.location.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.place, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Expanded(child: Text(a.location,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // metrik
                    Row(
                      children: [
                        _ChipMetric(icon: Icons.directions_run, text: _fmtKm(a.distanceKm)),
                        const SizedBox(width: 6),
                        _ChipMetric(icon: Icons.timer, text: _fmtDur(a.durationS)),
                        const SizedBox(width: 6),
                        _ChipMetric(icon: Icons.speed, text: a.paceText),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipMetric extends StatelessWidget {
  final IconData icon; final String text;
  const _ChipMetric({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/* ===== DETAIL SHEET ===== */

class _ActivityDetail extends StatefulWidget {
  final Activity a;
  const _ActivityDetail({required this.a});
  @override
  State<_ActivityDetail> createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<_ActivityDetail> {
  GoogleMapController? _map;
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final start = a.route.isNotEmpty ? a.route.first : null;
    final end   = a.route.isNotEmpty ? a.route.last  : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width:44, height:5,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: Text(a.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(width: 8),
            _TypeBadge(type: a.type),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.event, color: Colors.white60, size: 16), const SizedBox(width: 6),
            Text(_fmtDateLong(a.date), style: const TextStyle(color: Colors.white70)),
            const Spacer(),
            if (a.location.isNotEmpty)
              Row(children: [
                const Icon(Icons.place, color: Colors.white60, size: 16), const SizedBox(width: 4),
                Text(a.location, style: const TextStyle(color: Colors.white70)),
              ]),
          ],
        ),
        const SizedBox(height: 12),

        // Map preview
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 200,
            child: a.route.length >= 2
                ? GoogleMap(
              initialCameraPosition: CameraPosition(target: a.route.first, zoom: 15),
              onMapCreated: (c) async {
                _map = c;
                // Fit bounds
                final latitudes = a.route.map((e) => e.latitude).toList()..sort();
                final longitudes = a.route.map((e) => e.longitude).toList()..sort();
                final sw = LatLng(latitudes.first, longitudes.first);
                final ne = LatLng(latitudes.last, longitudes.last);
                await _map!.animateCamera(
                  CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 36),
                );
              },
              markers: {
                if (start != null) Marker(markerId: const MarkerId('start'), position: start,
                    infoWindow: const InfoWindow(title: 'Mulai'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
                if (end != null) Marker(markerId: const MarkerId('end'), position: end,
                    infoWindow: const InfoWindow(title: 'Selesai'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: a.route,
                  width: 5,
                  color: Colors.lightBlueAccent,
                  startCap: Cap.roundCap, endCap: Cap.roundCap, jointType: JointType.round,
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: true,
            )
                : Container(
              color: Colors.white10,
              alignment: Alignment.center,
              child: const Text('Rute tidak tersedia', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Metrics grid
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricTile(big: _fmtKm(a.distanceKm), label: 'Jarak'),
              _MetricTile(big: _fmtDur(a.durationS), label: 'Durasi'),
              _MetricTile(big: a.paceText, label: 'Pace'),
              _MetricTile(big: _fmtKcal(a.calories), label: 'Kalori'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if ((a.notes ?? '').isNotEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Catatan',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(a.notes!, style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    String label; Color bg;
    switch (type) {
      case 'guide': label = 'Pendampingan'; bg = _cyan; break;
      case 'walk':  label = 'Jalan';        bg = _orange; break;
      default:      label = 'Lari';         bg = _green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String big; final String label;
  const _MetricTile({required this.big, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(big, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

/* ===== HELPERS ===== */

String _fmtKm(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} km';
String _fmtKcal(int k)  => '${k.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m)=>'${m[1]}.')} kkal';

String _fmtDur(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  if (h > 0) {
    return '${h}j ${m.toString().padLeft(2,'0')}m';
  } else {
    return '${m}m ${ss.toString().padLeft(2,'0')}d';
  }
}

String _fmtDate(DateTime d) {
  const hari = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];
  final w = hari[(d.weekday - 1) % 7];
  final dd = d.day.toString().padLeft(2,'0');
  final mm = d.month.toString().padLeft(2,'0');
  return '$w, $dd/$mm';
}
String _fmtDateLong(DateTime d) {
  const bulan = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
  final dd = d.day.toString().padLeft(2,'0');
  final b = bulan[d.month-1];
  final yy = d.year;
  final hh = d.hour.toString().padLeft(2,'0');
  final mm = d.minute.toString().padLeft(2,'0');
  return '$dd $b $yy • $hh:$mm';
}
