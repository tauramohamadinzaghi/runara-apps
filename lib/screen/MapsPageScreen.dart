import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';


// ⬇️ Import RunaraThinNav & AppTab (ganti path sesuai struktur proyekmu)
import 'widget/runara_thin_nav.dart';

// ===== Palette =====
const _bgBlue = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue = Color(0xFF0E1E44);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF3A4C86);

class MapsPageScreen extends StatefulWidget {
  const MapsPageScreen({super.key});

  @override
  State<MapsPageScreen> createState() => _MapsPageScreenState();
}

class _MapsPageScreenState extends State<MapsPageScreen>
    with SingleTickerProviderStateMixin {
  // Animasi “pulse” untuk indikator status di header
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  // Konversi Position -> LatLng
  LatLng _toLL(Position p) => LatLng(p.latitude, p.longitude);

  // Haversine via Geolocator.distanceBetween
  double _distM(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  // ====== Tambahan konstanta ======
  static const _arrivalRadiusM = 20.0; // dianggap sampai tujuan < 20 m
  static const _gmapsKey = 'AIzaSyAJvcttF7c6_0dUOOO0xHQEB9jMpw3EDvo'; // TODO: restrict/rotate sesuai proyekmu
  static const double _kcalPerKm = 60.0; // ≈50–70 kkal/km → pakai 60 default

  // Stream lokasi & state navigasi
  StreamSubscription<Position>? _posSub;
  GoogleMapController? _mapCtrl;
  final LatLng _fallbackCenter = const LatLng(-6.914744, 107.609810); // Bandung
  bool _locationGranted = false;
  LatLng? _current;
  LatLng? _destination;
  bool _navigating = false;

  // Jejak pergerakan & rute
  final List<LatLng> _trail = [];      // jejak pengguna (garis hijau)
  List<LatLng> _routeToDest = [];      // rute walking dari Directions API

  // Metrik live
  double _distanceMeters = 0; // total jarak tempuh
  double _speedKmh = 0;
  DateTime? _lastFixAt;
  LatLng? _lastFixLatLng;

  // ===== Polyline decoder Google =====
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ===== Ambil rute jalan kaki dari Directions API (bukan garis lurus) =====
  Future<List<LatLng>> _fetchRouteWalking(LatLng origin, LatLng dest) async {
    if (_gmapsKey == 'YOUR_API_KEY' || _gmapsKey.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directions API key belum diset / tidak valid. Rute digambar lurus sementara.')),
        );
      }
      return [origin, dest];
    }
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${dest.latitude},${dest.longitude}'
          '&mode=walking&units=metric&key=$_gmapsKey',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Directions gagal (${res.statusCode}). Rute digambar lurus.')),
          );
        }
        return [origin, dest];
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (j['status'] as String?) ?? 'UNKNOWN';
      if (status != 'OK') {
        if (mounted) {
          final msg = j['error_message']?.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Directions: $status${msg != null ? " – $msg" : ""}. Rute digambar lurus.')),
          );
        }
        return [origin, dest];
      }

      final routes = (j['routes'] as List);
      final overview = routes.first['overview_polyline']?['points'] as String?;
      if (overview == null) return [origin, dest];

      final pts = _decodePolyline(overview);
      if (pts.isNotEmpty && (_distM(pts.first, origin) > 5)) pts.insert(0, origin);
      if (pts.isNotEmpty && (_distM(pts.last, dest) > 5)) pts.add(dest);
      return pts;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa mengambil Directions. Rute digambar lurus.')),
        );
      }
      return [origin, dest];
    }
  }

  // ===== Mulai tracking ke tujuan =====
  Future<void> _startTrackingTo(LatLng dest) async {
    if (!_locationGranted) {
      await _ensureLocationPermission();
      if (!_locationGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi diperlukan.')),
          );
        }
        return;
      }
    }

    _destination = dest;
    _navigating = true;
    _distanceMeters = 0;
    _speedKmh = 0;
    _trail.clear();
    _routeToDest = [];

    final first = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    _current = _toLL(first);
    _lastFixLatLng = _current;
    _lastFixAt = DateTime.now();
    _trail.add(_current!);

    try {
      _routeToDest = await _fetchRouteWalking(_current!, _destination!);
    } catch (_) {
      _routeToDest = [_current!, _destination!];
    }

    await _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_current!, 16));

    await _posSub?.cancel();
    final settings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition, onError: (_) {});

    if (mounted) setState(() {});
  }

  void _stopTracking({bool arrived = false}) {
    _navigating = false;
    _posSub?.cancel();
    _posSub = null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(arrived ? 'Sudah sampai tujuan ✅' : 'Tracking dihentikan.')),
      );
      setState(() {});
    }
  }

  void _onPosition(Position p) {
    final now = DateTime.now();
    final here = _toLL(p);
    _current = here;

    if (_lastFixLatLng != null) {
      final step = _distM(_lastFixLatLng!, here);
      if (step.isFinite && step >= 0) _distanceMeters += step;
    }
    if (p.speed.isFinite && p.speed >= 0) {
      _speedKmh = p.speed * 3.6;
    } else if (_lastFixAt != null && _lastFixLatLng != null) {
      final dt = now.difference(_lastFixAt!).inMilliseconds / 1000.0;
      if (dt > 0) _speedKmh = (_distM(_lastFixLatLng!, here) / dt) * 3.6;
    }

    _lastFixAt = now;
    _lastFixLatLng = here;
    _trail.add(here);

    _mapCtrl?.animateCamera(CameraUpdate.newLatLng(here));

    if (_navigating && _destination != null) {
      final remain = _remainingOnRouteMeters();
      if (remain <= _arrivalRadiusM) _stopTracking(arrived: true);
    }

    // OPTIONAL sinkron Firestore (throttle bila perlu)
    // FirebaseFirestore.instance.collection('live_metrics').doc('current').set({...});

    if (mounted) setState(() {});
  }

  // ===== Sisa jarak sepanjang rute (bukan garis lurus) =====
  double _remainingOnRouteMeters() {
    if (_destination == null || _current == null) return 0;
    if (_routeToDest.length < 2) {
      return _distM(_current!, _destination!);
    }
    // Cari titik rute terdekat dari posisi sekarang
    int nearest = 0;
    double best = double.infinity;
    for (int i = 0; i < _routeToDest.length; i++) {
      final d = _distM(_current!, _routeToDest[i]);
      if (d < best) { best = d; nearest = i; }
    }
    double remain = _distM(_current!, _routeToDest[nearest]);
    for (int i = nearest; i < _routeToDest.length - 1; i++) {
      remain += _distM(_routeToDest[i], _routeToDest[i + 1]);
    }
    return remain;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(curve);
    _opacity = Tween<double>(begin: 0.75, end: 0.0).animate(curve);
    _ensureLocationPermission();
  }

  Future<void> _ensureLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _locationGranted = false); return; }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() => _locationGranted = false); return;
      }
      setState(() => _locationGranted = true);
    } catch (_) { setState(() => _locationGranted = false); }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // Format angka
  String _fmtKm(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} KM';
  String _fmtSpeed(double v) => '${v.toStringAsFixed(0).replaceAll('.', ',')} km/jam';
  String _fmtKcal(double v) => '${v.toStringAsFixed(0).replaceAll('.', ',')} kkal';

  // >>> ADDED: English formatters (tidak mengubah yang lama)
  String _fmtKmEN(double v) => '${v.toStringAsFixed(1)} km';
  String _fmtSpeedEN(double v) => '${v.toStringAsFixed(0)} km/h';
  String _fmtKcalEN(double v) => '${v.toStringAsFixed(0)} kcal';

  // >>> ADDED: Hard stop that also clears state & uses English snackbar
  void _stopTrackingHard() {
    _posSub?.cancel();
    _posSub = null;
    _navigating = false;
    _destination = null;
    _routeToDest.clear();
    _trail.clear();
    _distanceMeters = 0;
    _speedKmh = 0;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking stopped.')),
      );
      setState(() {});
    }
  }

  // ==== Parser helper (agar fleksibel dgn struktur Firestore) ====

  LatLng _parseCenter(Map<String, dynamic> data) {
    final c = data['center'];
    if (c is Map) {
      final lat = (c['lat'] ?? c['latitude'])?.toDouble();
      final lng = (c['lng'] ?? c['longitude'])?.toDouble();
      if (lat is double && lng is double) return LatLng(lat, lng);
    }
    final gp = data['center_geopoint'];
    if (gp is GeoPoint) return LatLng(gp.latitude, gp.longitude);
    final lat = (data['center_lat'] as num?)?.toDouble();
    final lng = (data['center_lng'] as num?)?.toDouble();
    if (lat != null && lng != null) return LatLng(lat, lng);
    return _fallbackCenter;
  }

  Set<Marker> _parseMarkers(Map<String, dynamic> data) {
    final set = <Marker>{};
    final m = data['markers'];
    if (m is List) {
      for (int i = 0; i < m.length; i++) {
        final it = m[i];
        LatLng? p;
        String? title, snippet;
        if (it is GeoPoint) {
          p = LatLng(it.latitude, it.longitude);
        } else if (it is Map) {
          final lat = (it['lat'] ?? it['latitude'])?.toDouble();
          final lng = (it['lng'] ?? it['longitude'])?.toDouble();
          if (lat is double && lng is double) {
            p = LatLng(lat, lng);
            title = it['title']?.toString();
            snippet = it['snippet']?.toString();
          }
        }
        if (p != null) {
          set.add(Marker(
            markerId: MarkerId('m$i'),
            position: p,
            infoWindow: InfoWindow(title: title, snippet: snippet),
          ));
        }
      }
    } else {
      final lat = (data['target_lat'] as num?)?.toDouble();
      final lng = (data['target_lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        set.add(const Marker(
          markerId: MarkerId('target'),
          position: LatLng(0, 0), // akan di-override di builder kalau ada
          infoWindow: InfoWindow(title: 'Target'),
        ));
        set.removeWhere((m) => m.markerId.value == 'target');
        set.add(Marker(
          markerId: const MarkerId('target'),
          position: LatLng(lat, lng),
          infoWindow: const InfoWindow(title: 'Target'),
        ));
      }
    }
    return set;
  }

  Set<Polyline> _parsePolylines(Map<String, dynamic> data) {
    final r = data['route'];
    if (r is! List) return {};
    final points = <LatLng>[];
    for (final it in r) {
      if (it is GeoPoint) {
        points.add(LatLng(it.latitude, it.longitude));
      } else if (it is Map) {
        final lat = (it['lat'] ?? it['latitude'])?.toDouble();
        final lng = (it['lng'] ?? it['longitude'])?.toDouble();
        if (lat is double && lng is double) points.add(LatLng(lat, lng));
      }
    }
    if (points.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 5,
        color: Colors.blueAccent,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bgBlue,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/bg_space.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ===== Header (punya animasi status) =====
                Padding(
                  padding: EdgeInsets.fromLTRB(16, (topPad > 0 ? 12 : 20), 16, 10),
                  child: _HeaderWithStatus(scale: _scale, opacity: _opacity),
                ),

                // ===== Google Map + overlay Firestore =====
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('live_metrics')
                            .doc('current')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const Center(
                              child: Text('Gagal terhubung Firestore', style: TextStyle(color: Colors.white70)),
                            );
                          }

                          final data = snap.data?.data() ?? {};
                          final center = _current ?? _parseCenter(data);
                          final markers = _parseMarkers(data);
                          final polylines = _parsePolylines(data);

                          // === Overlay lokal: tujuan, rute, jejak ===
                          final localMarkers = <Marker>{};
                          if (_destination != null) {
                            localMarkers.add(Marker(
                              markerId: const MarkerId('dest'),
                              position: _destination!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                              infoWindow: const InfoWindow(title: 'Tujuan'),
                            ));
                          }
                          if (_current != null) {
                            localMarkers.add(Marker(
                              markerId: const MarkerId('me'),
                              position: _current!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                              infoWindow: const InfoWindow(title: 'Posisi Kamu'),
                            ));
                          }

                          final localPolylines = <Polyline>{
                            if (_trail.length >= 2)
                              Polyline(
                                polylineId: const PolylineId('trail'),
                                points: List<LatLng>.from(_trail),
                                width: 5,
                                color: Colors.greenAccent,
                                startCap: Cap.roundCap,
                                endCap: Cap.roundCap,
                                jointType: JointType.round,
                              ),
                            if (_routeToDest.length >= 2)
                              Polyline(
                                polylineId: const PolylineId('route_to_dest'),
                                points: List<LatLng>.from(_routeToDest),
                                width: 5,
                                color: Colors.blueAccent,
                                startCap: Cap.roundCap,
                                endCap: Cap.roundCap,
                                jointType: JointType.round,
                              ),
                          };

                          // ===== METRIK LOKAL (4 kolom) =====
                          final distanceKmLocal = _distanceMeters / 1000.0;
                          final remainKm = _destination != null && _current != null
                              ? _remainingOnRouteMeters() / 1000.0
                              : 0.0;
                          final speedKmhLocal = _speedKmh;
                          final kcal = distanceKmLocal * _kcalPerKm;

                          return Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: center,
                                  zoom: 15,
                                ),
                                onMapCreated: (c) async { _mapCtrl = c; },
                                myLocationEnabled: _locationGranted,
                                myLocationButtonEnabled: true,
                                zoomControlsEnabled: false,

                                // Gabungkan overlay Firestore + lokal
                                markers: {...markers, ...localMarkers},
                                polylines: {...polylines, ...localPolylines},
                                mapToolbarEnabled: false,
                                compassEnabled: true,

                                // Pilih tujuan dengan tap
                                onTap: (latLng) async {
                                  if (_navigating) _stopTracking();
                                  await _startTrackingTo(latLng);
                                },
                              ),

                              // ===== Panel info bawah (4 metrik) =====
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 16,
                                child: Center(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.9,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1E3D),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                                    ),
                                    child: DefaultTextStyle(
                                      style: const TextStyle(color: Colors.white),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _MetricCol(label: 'Jarak Ditempuh', value: _fmtKm(distanceKmLocal)),
                                          _MetricCol(
                                            label: 'Sisa ke Tujuan',
                                            value: _fmtKm(remainKm.isFinite && remainKm >= 0 ? remainKm : 0),
                                          ),
                                          _MetricCol(
                                            label: 'Kecepatan',
                                            value: _fmtSpeed(speedKmhLocal.isFinite ? speedKmhLocal : 0),
                                          ),
                                          _MetricCol(label: 'Kalori', value: _fmtKcal(kcal.isFinite ? kcal : 0)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // >>> ADDED: Stop button on the LEFT (works + clears state)
                              if (_navigating)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: SafeArea(
                                    bottom: false,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      onPressed: _stopTrackingHard,
                                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                      label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),

                              // >>> ADDED: Block clicks on the old right Stop (visual tetap, tapi tidak bisa ditekan)
                              if (_navigating)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: AbsorbPointer(
                                    absorbing: true,
                                    child: SizedBox(width: 140, height: 52),
                                  ),
                                ),

                              // >>> ADDED: English metrics panel with icons (overlaying above the old panel)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 16,
                                child: Center(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width * 0.9,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1E3D).withOpacity(0.96),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _MetricIconCol(
                                          icon: Icons.directions_walk,
                                          label: 'Distance',
                                          value: _fmtKmEN(distanceKmLocal),
                                        ),
                                        _MetricIconCol(
                                          icon: Icons.route,
                                          label: 'Remaining',
                                          value: _fmtKmEN(remainKm.isFinite && remainKm >= 0 ? remainKm : 0),
                                        ),
                                        _MetricIconCol(
                                          icon: Icons.speed,
                                          label: 'Speed',
                                          value: _fmtSpeedEN(speedKmhLocal.isFinite ? speedKmhLocal : 0),
                                        ),
                                        _MetricIconCol(
                                          icon: Icons.local_fire_department,
                                          label: 'Calories',
                                          value: _fmtKcalEN(kcal.isFinite ? kcal : 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ===== Bottom nav pakai RunaraThinNav =====
      bottomNavigationBar: const RunaraThinNav(current: AppTab.maps),
    );
  }
}

/* ================== Header dengan status (animasi) ================== */

class _HeaderWithStatus extends StatelessWidget {
  final Animation<double> scale;
  final Animation<double> opacity;

  const _HeaderWithStatus({required this.scale, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBlue.withOpacity(.72),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar "H"
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2B3B7A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: const Text(
              'H',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Teks + badge + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Selamat malam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    SizedBox(width: 6),
                    Text('🌙', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Text('Hilda Afiah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, height: 1.05)),
                    SizedBox(width: 6),
                    _RoleBadge(text: 'Relawan', fontSize: 11),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 16, color: _subtle),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                          ),
                          FractionallySizedBox(
                            widthFactor: .60,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(color: _chipBlue, borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('LV.0', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Status: “Berjalan” + pulse ring
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Berjalan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 6),
              SizedBox(
                width: 20,
                height: 20,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBuilder(
                      animation: scale,
                      builder: (context, _) {
                        return Opacity(
                          opacity: opacity.value,
                          child: Transform.scale(
                            scale: scale.value,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF22C55E), width: 2),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String text;
  final double fontSize;
  const _RoleBadge({required this.text, this.fontSize = 11});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: _chipBlue, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w800, height: 1.0),
      ),
    );
  }
}

/* ===================== Metric Column ===================== */

class _MetricCol extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}

// >>> ADDED: Metric with leading icon (English panel)
class _MetricIconCol extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricIconCol({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ],
    );
  }
}
