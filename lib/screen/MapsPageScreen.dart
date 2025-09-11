import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  // Google Map
  GoogleMapController? _mapCtrl;
  final LatLng _fallbackCenter = const LatLng(-6.914744, 107.609810); // Bandung
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(curve);
    _opacity = Tween<double>(begin: 0.75, end: 0.0).animate(curve);

    _ensureLocationPermission();
  }

  Future<void> _ensureLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationGranted = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _locationGranted = false);
        return;
      }
      setState(() => _locationGranted = true);
    } catch (_) {
      setState(() => _locationGranted = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // Format angka
  String _fmtKm(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} KM';
  String _fmtSpeed(double v) =>
      '${v.toStringAsFixed(0).replaceAll('.', ',')} km/jam';

  // ==== Parser helper (agar fleksibel dgn struktur Firestore) ====

  /// Ambil center dari field:
  /// - center: {lat, lng}  ATAU {latitude, longitude}  ATAU GeoPoint 'center_geopoint'
  /// - fallback: _fallbackCenter
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

  /// Parse markers dari:
  /// - markers: [ {lat,lng,title?,snippet?} ] atau [ GeoPoint, ... ]
  /// - target_lat / target_lng (single)
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
      // single fallback: target_lat/lng
      final lat = (data['target_lat'] as num?)?.toDouble();
      final lng = (data['target_lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        set.add(Marker(
          markerId: const MarkerId('target'),
          position: LatLng(lat, lng),
          infoWindow: const InfoWindow(title: 'Target'),
        ));
      }
    }

    return set;
  }

  /// Parse polyline dari:
  /// - route: [ {lat,lng}, ... ] atau [ GeoPoint, ... ]
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
        if (lat is double && lng is double) {
          points.add(LatLng(lat, lng));
        }
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
                  padding:
                  EdgeInsets.fromLTRB(16, (topPad > 0 ? 12 : 20), 16, 10),
                  child: _HeaderWithStatus(scale: _scale, opacity: _opacity),
                ),

                // ===== Google Map + overlay Firestore =====
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('live_metrics')
                            .doc('current')
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return const Center(
                                child: Text('Gagal terhubung Firestore',
                                    style: TextStyle(color: Colors.white70)));
                          }

                          final data = snap.data?.data() ?? {};
                          final center = _parseCenter(data);
                          final markers = _parseMarkers(data);
                          final polylines = _parsePolylines(data);

                          final distanceKm =
                              (data['distance_km'] as num?)?.toDouble() ?? 0.0;
                          final speedKmh =
                              (data['speed_kmh'] as num?)?.toDouble() ?? 0.0;
                          final heartBpm =
                              (data['heart_bpm'] as num?)?.toInt() ?? 0;

                          return Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: center,
                                  zoom: 15,
                                ),
                                onMapCreated: (c) async {
                                  _mapCtrl = c;
                                },
                                myLocationEnabled: _locationGranted,
                                myLocationButtonEnabled: true,
                                zoomControlsEnabled: false,
                                markers: markers,
                                polylines: polylines,
                                mapToolbarEnabled: false,
                                compassEnabled: true,
                              ),

                              // Panel info bawah
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 16,
                                child: Center(
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.9,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B1E3D),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 10),
                                      ],
                                    ),
                                    child: DefaultTextStyle(
                                      style:
                                      const TextStyle(color: Colors.white),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          _MetricCol(
                                            label: 'Jarak Ditempuh',
                                            value: _fmtKm(distanceKm),
                                          ),
                                          _MetricCol(
                                            label: 'Kecepatan',
                                            value: _fmtSpeed(speedKmh),
                                          ),
                                          _MetricCol(
                                            label: 'Heart Rate',
                                            value:
                                            '${heartBpm.clamp(0, 300)} BPM',
                                          ),
                                        ],
                                      ),
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
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Teks + badge + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting + emoji
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Selamat malam',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                    SizedBox(width: 6),
                    Text('🌙', style: TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: const [
                    Text(
                      'Hilda Afiah',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.05,
                      ),
                    ),
                    SizedBox(width: 6),
                    _RoleBadge(text: 'Relawan', fontSize: 11),
                  ],
                ),
                const SizedBox(height: 10),

                // Shield + progress + LV
                Row(
                  children: [
                    const Icon(Icons.shield_rounded,
                        size: 16, color: _subtle),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: .60, // 60%
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _chipBlue,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'LV.0',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
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
              const Text('Berjalan',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
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
                                border: Border.all(
                                    color: const Color(0xFF22C55E), width: 2),
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
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
          color: _chipBlue, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1.0),
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
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
  }
}
