import 'package:cityride/services/rideservice.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class DriverSearchScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String vehicleType;

  const DriverSearchScreen({
    super.key,
    required this.pickupLocation,
    required this.vehicleType,
  });

  @override
  State<DriverSearchScreen> createState() => _DriverSearchScreenState();
}

class _DriverSearchScreenState extends State<DriverSearchScreen>
    with TickerProviderStateMixin {
  final RideService _rideService = RideService();
  late AnimationController _radarController;

  GoogleMapController? _mapController;
  Set<Marker> _driverMarkers = {};
  Timer? _pollingTimer;
  Timer? _timeoutTimer; // Automatic cancel timer
  int _driversFoundCount = 0;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Radar Animation
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 2. Start fetching drivers immediately and every 4 seconds
    _fetchDrivers();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _fetchDrivers();
    });

    // 3. Set Search Timeout (60 Seconds)
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      _handleSearchTimeout();
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  // Logic to handle auto-cancel after 1 minute
  void _handleSearchTimeout() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No drivers found nearby. Please try again later."),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _fetchDrivers() async {
    try {
      // API call: GET /drivers/nearby
      final drivers = await _rideService.getNearbyDrivers(
        widget.pickupLocation.latitude,
        widget.pickupLocation.longitude,
      );

      if (!mounted) return;

      setState(() {
        _driversFoundCount = drivers.length;
        _driverMarkers = drivers.map((d) {
          // Backend format for coordinates: [longitude, latitude]
          final coords = d['location']['coordinates'];
          return Marker(
            markerId: MarkerId(d['_id'] ?? d['id'].toString()),
            position: LatLng(coords[1], coords[0]),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(title: "${d['firstName'] ?? 'Driver'}"),
          );
        }).toSet();
      });
    } catch (e) {
      debugPrint("Error polling drivers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Google Map Background
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickupLocation,
              zoom: 15.5,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _driverMarkers,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // 2. Pulse Radar Animation Overlay
          Center(child: _buildRadarPulse()),

          // 3. Top Header Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Row(
                children: [
                  _iconBtn(Icons.arrow_back, () => Navigator.pop(context)),
                  const SizedBox(width: 15),
                  _buildStatusPill(),
                ],
              ),
            ),
          ),

          // 4. Bottom Information Sheet
          _buildInfoSheet(),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF147D44),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, color: Colors.white, size: 8),
          SizedBox(width: 10),
          Text(
            "Searching nearby",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarPulse() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _pulseCircle(
              150 * _radarController.value,
              1 - _radarController.value,
            ),
            _pulseCircle(
              280 * _radarController.value,
              0.4 * (1 - _radarController.value),
            ),
            _pulseCircle(
              400 * _radarController.value,
              0.1 * (1 - _radarController.value),
            ),
            // Central User Hub
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF147D44),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pulseCircle(double radius, double opacity) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF147D44).withOpacity(opacity.clamp(0.0, 1.0)),
      ),
    );
  }

  Widget _buildInfoSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vehicle Visual
            CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFFE9F2EE),
              child: Icon(
                widget.vehicleType == "Keke"
                    ? Icons.motorcycle
                    : Icons.directions_car,
                color: const Color(0xFF147D44),
                size: 35,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Finding a driver.....",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              "Checking $_driversFoundCount ${widget.vehicleType} drivers near you",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 30),

            // Live Wait Time Row
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F2EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Color(0xFF147D44),
                    size: 28,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Estimated wait time",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          "2 - 4 minutes",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Color(0xFF147D44),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Manual Cancel Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }
}
