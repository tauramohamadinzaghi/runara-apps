import 'dart:async';
import 'dart:convert';

import 'package:apps_runara/sos_bus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Nav & Header reusable
import 'widget/runara_header.dart';
import 'widget/runara_thin_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// === RIWAYAT (GANTI PATH JIKA PERLU) ===
import 'AktivitasRiwayatPageScreen.dart';

/* ===================== SOS TRACKING SCREEN ===================== */

class SosTrackingMapScreen extends StatefulWidget {
  final double targetLat;
  final double targetLng;
  final String? targetName;
  final String? targetAddress;

  const SosTrackingMapScreen({
    super.key,
    required this.targetLat,
    required this.targetLng,
    this.targetName,
    this.targetAddress,
  });

  // Helper agar mudah dipanggil dari mana pun dengan SosPayload
  static void open(BuildContext context, SosPayload p) {
    if (p.lat == null || p.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat tujuan tidak tersedia')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosTrackingMapScreen(
          targetLat: p.lat!,
          targetLng: p.lng!,
          targetName: p.name,
          targetAddress: p.address.isEmpty ? null : p.address,
        ),
      ),
    );
  }

  @override
  State<SosTrackingMapScreen> createState() => _SosTrackingMapScreenState();
}

class _SosTrackingMapScreenState extends State<SosTrackingMapScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _posSub;

  // ==== Directions KEY (tanpa --dart-define) ====
  // ⚠️ Batasi key di Google Cloud Console (HTTP referrer / Android & iOS key restriction) ⚠️
  static const String _gmapsKey = 'AIzaSyAJvcttF7c6_0dUOOO0xHQEB9jMpw3EDvo';

  final List<LatLng> _route = []; // rute walking dari Directions
  bool _fetching = false;

  LatLng get _target => LatLng(widget.targetLat, widget.targetLng);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }

    // posisi awal
    try {
      final p = await Geolocator.getCurrentPosition();
      _updateUser(LatLng(p.latitude, p.longitude));
    } catch (_) {}

    // stream posisi (tracking)
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      _updateUser(LatLng(pos.latitude, pos.longitude));
    });
  }

  // ===== Polyline decoder Google =====
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  double _distM(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  Future<List<LatLng>> _fetchRouteWalking(LatLng origin, LatLng dest) async {
    if (_gmapsKey.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directions API key belum diset. Rute digambar lurus.')),
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
      if (res.statusCode != 200) return [origin, dest];

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if ((j['status'] as String?) != 'OK') return [origin, dest];

      final routes = (j['routes'] as List);
      if (routes.isEmpty) return [origin, dest];

      // Pakai overview_polyline (cukup halus untuk UI)
      final overview = routes.first['overview_polyline']?['points'] as String?;
      if (overview == null) return [origin, dest];

      final pts = _decodePolyline(overview);
      if (pts.isNotEmpty && (_distM(pts.first, origin) > 5)) pts.insert(0, origin);
      if (pts.isNotEmpty && (_distM(pts.last, dest) > 5)) pts.add(dest);
      return pts;
    } catch (_) {
      return [origin, dest];
    }
  }

  Future<void> _refreshRouteIfNeeded(LatLng me) async {
    if (_fetching) return;
    // Reroute jika belum ada rute atau menyimpang > 30 m dari titik awal rute
    final need = _route.isEmpty || _distM(_route.first, me) > 30;
    if (!need) return;

    _fetching = true;
    final pts = await _fetchRouteWalking(me, _target);
    if (!mounted) {
      _fetching = false;
      return;
    }

    setState(() {
      _route
        ..clear()
        ..addAll(pts);
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('toTarget'),
          points: List<LatLng>.from(_route),
          width: 6,
          color: Colors.blueAccent,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ));
    });
    _fetching = false;
  }

  void _updateUser(LatLng me) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'me')
        ..add(Marker(
          markerId: const MarkerId('me'),
          position: me,
          infoWindow: const InfoWindow(title: 'Saya'),
        ));

      _markers
        ..removeWhere((m) => m.markerId.value == 'target')
        ..add(Marker(
          markerId: const MarkerId('target'),
          position: _target,
          infoWindow: InfoWindow(
            title: widget.targetName ?? 'Tujuan',
            snippet: widget.targetAddress,
          ),
        ));
    });

    // Minta Directions & gambar rute yang belok-belok
    _refreshRouteIfNeeded(me);

    _fitToBounds(me, _target);
  }

  Future<void> _fitToBounds(LatLng a, LatLng b) async {
    if (_map == null) return;
    final sw = LatLng(
      (a.latitude <= b.latitude) ? a.latitude : b.latitude,
      (a.longitude <= b.longitude) ? a.longitude : b.longitude,
    );
    final ne = LatLng(
      (a.latitude >= b.latitude) ? a.latitude : b.latitude,
      (a.longitude >= b.longitude) ? a.longitude : b.longitude,
    );
    await _map!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _openTurnByTurn() async {
    // Intent Google Maps (pakai colon ':')
    final uri1 = Uri.parse('google.navigation:q=${widget.targetLat},${widget.targetLng}&mode=w');
    if (await canLaunchUrl(uri1)) {
      await launchUrl(uri1, mode: LaunchMode.externalApplication);
      return;
    }
    // fallback ke URL
    final uri2 = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.targetLat},${widget.targetLng}',
    );
    await launchUrl(uri2, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetName ?? 'Arahkan Lokasi'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _target, zoom: 14),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (c) => _map = c,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTurnByTurn,
        icon: const Icon(Icons.navigation),
        label: const Text('Mulai Navigasi'),
      ),
    );
  }
}

/* ===================== MAPS PAGE (Dengan Header Status) ===================== */

// ===== Palette =====
const _bgBlue = Color(0xFF0B1B4D);
const _cardBlue = Color(0xFF152449);
const _navBlue = Color(0xFF0E1E44);
const _accent = Color(0xFF9AA6FF);
const _subtle = Color(0xFFBFC3D9);
const _chipBlue = Color(0xFF3A4C86);

class MapsPageScreen extends StatefulWidget {
  // >>> ADDED: optional target info yang bisa dikirim dari SOS/HomePage
  final double? targetLat;
  final double? targetLng;
  final String? targetName;
  final String? targetAddress;

  const MapsPageScreen({
    super.key,
    this.targetLat,
    this.targetLng,
    this.targetName,
    this.targetAddress,
  });

  @override
  State<MapsPageScreen> createState() => _MapsPageScreenState();
}

class _MapsPageScreenState extends State<MapsPageScreen> {
  // (HEADER DATA) — ambil untuk RunaraHeaderSection
  String _name = '—';
  String _roleLabel = 'Relawan';
  int _level = 0;
  double _progress = 0.0;

  bool get _hasUnread => RunaraNotificationCenter.hasUnread;

  // Konversi Position -> LatLng
  LatLng _toLL(Position p) => LatLng(p.latitude, p.longitude);

  // Haversine via Geolocator.distanceBetween
  double _distM(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);

  // ====== Tambahan konstanta ======
  static const _arrivalRadiusM = 20.0; // dianggap sampai tujuan < 20 m

  // ==== Directions KEY (tanpa --dart-define) ====
  // ⚠️ Batasi key di Google Cloud Console (HTTP referrer / Android & iOS key restriction) ⚠️
  static const String _gmapsKey = 'AIzaSyAJvcttF7c6_0dUOOO0xHQEB9jMpw3EDvo';

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
  bool _rerouteInFlight = false;

  // Metrik live
  double _distanceMeters = 0; // total jarak tempuh
  double _speedKmh = 0;
  DateTime? _lastFixAt;
  LatLng? _lastFixLatLng;

  // ====== Sesi & anti duplikat simpan ======
  DateTime? _sessionStartAt;     // waktu mulai tracking
  bool _savedSession = false;    // agar tidak tersimpan dua kali

  // ===== Polyline decoder Google =====
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ===== Ambil rute jalan kaki dari Directions API (bukan garis lurus) =====
  Future<List<LatLng>> _fetchRouteWalking(LatLng origin, LatLng dest) async {
    if (_gmapsKey.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Directions API key belum diset. Rute digambar lurus.')),
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
      if (res.statusCode != 200) return [origin, dest];

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final status = (j['status'] as String?) ?? 'UNKNOWN';
      if (status != 'OK') return [origin, dest];

      final routes = (j['routes'] as List);
      final overview = routes.first['overview_polyline']?['points'] as String?;
      if (overview == null) return [origin, dest];

      final pts = _decodePolyline(overview);
      if (pts.isNotEmpty && (_distM(pts.first, origin) > 5)) pts.insert(0, origin);
      if (pts.isNotEmpty && (_distM(pts.last, dest) > 5)) pts.add(dest);
      return pts;
    } catch (_) {
      return [origin, dest];
    }
  }

  // ==== Reroute bila keluar jalur > 25 m ====
  Future<void> _maybeReroute() async {
    if (_rerouteInFlight || _current == null || _destination == null) return;
    if (_routeToDest.isEmpty) {
      _rerouteInFlight = true;
      final pts = await _fetchRouteWalking(_current!, _destination!);
      if (mounted) setState(() => _routeToDest = pts);
      _rerouteInFlight = false;
      return;
    }

    // cari jarak terdekat dari posisi ke polyline
    double minDist = double.infinity;
    for (final p in _routeToDest) {
      final d = _distM(_current!, p);
      if (d < minDist) minDist = d;
    }
    if (minDist > 25) {
      _rerouteInFlight = true;
      final pts = await _fetchRouteWalking(_current!, _destination!);
      if (mounted) setState(() => _routeToDest = pts);
      _rerouteInFlight = false;
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

    // === START SESSION ===
    _sessionStartAt = DateTime.now();
    _savedSession   = false;

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

  // ===== Simpan aktivitas ke Firestore & siap untuk dilihat di Riwayat =====
  Future<void> _persistActivity() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final km = _distanceMeters / 1000.0;
      final durSec = _sessionStartAt == null
          ? 0
          : DateTime.now().difference(_sessionStartAt!).inSeconds;
      final cal = (km * _kcalPerKm).round();

      final route = _trail.map((p) => GeoPoint(p.latitude, p.longitude)).toList();

      // relawan => "guide", lainnya "walk"
      final type = _roleLabel.toLowerCase() == 'relawan' ? 'guide' : 'walk';
      final title = type == 'guide' ? 'Pendampingan' : 'Jalan';

      final data = {
        'ownerUid'  : uid,
        'type'      : type,
        'title'     : title,
        'location'  : _destination != null
            ? '${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}'
            : '',
        'date'      : Timestamp.now(),
        'distance_m': _distanceMeters.round(),
        'duration_s': durSec,
        'calories'  : cal,
        'route'     : route,
        'notes'     : null,
      };

      await FirebaseFirestore.instance.collection('activities').add(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan riwayat: $e')),
        );
      }
    }
  }

  void _stopTracking({bool arrived = false}) {
    // Jika benar-benar sampai, simpan sekali & buka Riwayat
    if (!_savedSession) {
      _savedSession = true;
      _persistActivity().then((_) async {
        if (!mounted) return;

        // (Opsional) reset state agar sesi berikutnya bersih
        _distanceMeters = 0;
        _speedKmh = 0;
        _sessionStartAt = null;
        _destination = null;
        _routeToDest.clear();
        _trail.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sudah sampai tujuan ✅ — disimpan ke riwayat')),
        );

        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RiwayatAktivitasPageScreen()),
        );
      });
    }

    _navigating = false;
    _posSub?.cancel();
    _posSub = null;
    if (mounted) {
      if (!arrived) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking dihentikan.')),
        );
      }
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
      // cek reroute (tanpa await agar tidak blok UI)
      _maybeReroute();

      // sampai tujuan?
      final remain = _remainingOnRouteMeters();
      if (remain <= _arrivalRadiusM) _stopTracking(arrived: true);
    }

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
      if (d < best) {
        best = d;
        nearest = i;
      }
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
    _ensureLocationPermission();
    _initHeaderData(); // <-- ambil nama/role untuk header
    // >>> ADDED: auto-mulai tracking bila ada target dari constructor
    if (widget.targetLat != null && widget.targetLng != null) {
      Future.microtask(
            () => _startTrackingTo(LatLng(widget.targetLat!, widget.targetLng!)),
      );
    }
  }

  Future<void> _initHeaderData() async {
    final u = FirebaseAuth.instance.currentUser;
    var name = (u?.displayName ?? '').trim();
    if (name.isEmpty) {
      final email = (u?.email ?? '').trim();
      name = email.isNotEmpty ? email.split('@').first : 'User';
    }

    final prefs = await SharedPreferences.getInstance();
    final roleKey = 'user_role_${u?.uid ?? 'local'}';
    final roleStr = prefs.getString(roleKey) ?? 'relawan';

    if (!mounted) return;
    setState(() {
      _name = name;
      _roleLabel = roleStr == 'tunanetra' ? 'Tunanetra' : 'Relawan';
      _level = 0;
      _progress = 0;
    });
  }

  Future<void> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationGranted = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
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
    _posSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // Format angka
  String _fmtKm(double v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} KM';
  String _fmtSpeed(double v) => '${v.toStringAsFixed(0).replaceAll('.', ',')} km/jam';
  String _fmtKcal(double v) => '${v.toStringAsFixed(0).replaceAll('.', ',')} kkal';

  // English formatters
  String _fmtKmEN(double v) => '${v.toStringAsFixed(1)} km';
  String _fmtSpeedEN(double v) => '${v.toStringAsFixed(0)} km/h';
  String _fmtKcalEN(double v) => '${v.toStringAsFixed(0)} kcal';

  // Hard stop that also clears state
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

  final u = FirebaseAuth.instance.currentUser;

  Future<void> _openNotifications() async {
    await RunaraNotificationCenter.open(context);
    if (mounted) setState(() {}); // refresh badge
  }

  @override
  Widget build(BuildContext context) {
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
                // ===== Header reusable: ganti bell dengan status berjalan/tidak berjalan
                RunaraHeaderSection(
                  greeting: runaraGreetingIndo(DateTime.now()),
                  emoji: runaraGreetingEmoji(DateTime.now()),
                  userName: _name,
                  roleLabel: _roleLabel,
                  level: _level,
                  progress: _progress,
                  hasUnread: _hasUnread,
                  onTapBell: () {}, // trailing menggantikan bell
                  photoUrl: u?.photoURL, // ⬅️ foto sesuai akun
                  trailing: _StatusPill(
                    running: _navigating,
                    onTap: () {
                      if (_navigating) {
                        _stopTrackingHard();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih lokasi di peta untuk mulai.')),
                        );
                      }
                    },
                  ),
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
                                width: 6,
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
                                onMapCreated: (c) async {
                                  _mapCtrl = c;
                                  // >>> ADDED: jika ada target dari constructor dan belum mulai, mulai tracking
                                  if (widget.targetLat != null && widget.targetLng != null && !_navigating) {
                                    await _startTrackingTo(LatLng(widget.targetLat!, widget.targetLng!));
                                  }
                                },
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

                              // >>> Optional: Stop button kiri
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

// Metric with leading icon (English panel) — jika suatu saat dibutuhkan
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

/* ===================== Header Trailing: Status Pill ===================== */

class _StatusPill extends StatelessWidget {
  final bool running;
  final VoidCallback? onTap;
  const _StatusPill({required this.running, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = running ? const Color(0xFF22C55E) : Colors.white10;
    final border = running ? Colors.transparent : Colors.white24;
    final label = running ? 'Run' : 'Not Run';
    final icon = running ? Icons.directions_walk : Icons.pause_circle_outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: running ? Colors.white : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: running ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
