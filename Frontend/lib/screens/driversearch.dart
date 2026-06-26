import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';

class DriverSearchScreen extends StatefulWidget {
  final LatLng pickupLocation;
  final String vehicleType;
  final String? rideId;

  const DriverSearchScreen({
    super.key,
    required this.pickupLocation,
    required this.vehicleType,
    this.rideId,
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
  bool _isCancelling = false;

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

      final Set<Marker> markers = {};
      for (final d in drivers) {
        final double? lat = (d['lastLatitude'] as num?)?.toDouble();
        final double? lng = (d['lastLongitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final String name = d['user']?['firstName'] ?? 'Driver';
        markers.add(
          Marker(
            markerId: MarkerId(d['id'].toString()),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(title: name),
          ),
        );
      }

      setState(() {
        _driversFoundCount = drivers.length;
        _driverMarkers = markers;
      });
    } catch (e) {
      debugPrint("Error polling drivers: $e");
    }
  }

  Future<void> _handleCancel() async {
    if (widget.rideId == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isCancelling = true);
    try {
      await _rideService.cancelRide(widget.rideId!);
    } catch (e) {
      debugPrint("Cancel Ride Error: $e");
    } finally {
      if (mounted) Navigator.pop(context);
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.subtle,
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
              fontWeight: FontWeight.w700,
              fontSize: 14,
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
                color: AppColors.primary,
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
        color: AppColors.primary.withValues(alpha: opacity.clamp(0.0, 1.0)),
      ),
    );
  }

  Widget _buildInfoSheet() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vehicle Visual
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.cardFill,
              child: Icon(
                widget.vehicleType == "Keke"
                    ? Icons.electric_rickshaw
                    : Icons.directions_car_filled,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text("Finding a driver…", style: AppText.h1),
            const SizedBox(height: 6),
            Text(
              "Checking $_driversFoundCount ${widget.vehicleType} drivers near you",
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live Wait Time Row
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Estimated wait time", style: AppText.caption),
                        Text("2 - 4 minutes", style: AppText.h2),
                      ],
                    ),
                  ),
                  const Text(
                    "LIVE",
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Manual Cancel Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _handleCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
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
        height: 46,
        width: 46,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.subtle,
        ),
        child: Icon(icon, color: AppColors.darkText),
      ),
    );
  }
}
