import 'dart:async';
import 'dart:convert';
import 'package:cityride/models/ride_model.dart';
import 'package:cityride/screens/driver_active_ride.dart';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/services/authservice.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:cityride/utils/format.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final AuthService _authService = AuthService();
  final RideService _rideService = RideService();

  // Dynamic State
  String _firstName = "";
  bool _isOnline = true;
  Timer? _rideRequestTimer;
  Timer? _locationTimer;
  bool _isShowingRide = false;

  String _period = 'week';
  Map<String, dynamic>? _earnings;
  List<Ride> _recentTrips = [];
  bool _isLoadingEarnings = true;

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
    _syncAvailability(_isOnline);
    if (_isOnline) _goOnline();
    _loadEarnings();
  }

  @override
  void dispose() {
    _rideRequestTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncAvailability(bool isAvailable) async {
    try {
      await _rideService.setAvailability(isAvailable);
    } catch (e) {
      debugPrint("Set Availability Error: $e");
    }
  }

  void _goOnline() {
    _startRideRequestPolling();
    _startLocationReporting();
  }

  void _goOffline() {
    _stopRideRequestPolling();
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _handleLogout() async {
    _goOffline();
    try {
      await _rideService.setAvailability(false);
    } catch (e) {
      debugPrint("Logout Availability Error: $e");
    }
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  void _startRideRequestPolling() {
    _rideRequestTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkForRideRequest(),
    );
  }

  void _stopRideRequestPolling() {
    _rideRequestTimer?.cancel();
    _rideRequestTimer = null;
  }

  void _startLocationReporting() {
    _pushCurrentLocation();
    _locationTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushCurrentLocation(),
    );
  }

  Future<void> _pushCurrentLocation() async {
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }
      final position = await geo.Geolocator.getCurrentPosition();
      await _rideService.updateDriverLocation(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint("Push Location Error: $e");
    }
  }

  Future<void> _checkForRideRequest() async {
    if (_isShowingRide || !_isOnline) return;
    try {
      final response = await _rideService.getIncomingRideRequests();
      if (response.statusCode != 200) return;
      final Map<String, dynamic> decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded['rides'] ?? [];
      if (data.isEmpty) return;

      _isShowingRide = true;
      final ride = Ride.fromJson(data[0]);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DriverActiveRideScreen(ride: ride)),
      );
      _isShowingRide = false;
    } catch (e) {
      debugPrint("Ride request check error: $e");
      _isShowingRide = false;
    }
  }

  Future<void> _loadEarnings() async {
    setState(() => _isLoadingEarnings = true);
    try {
      final earningsResponse = await _rideService.getDriverEarnings(
        period: _period,
      );
      final ridesResponse = await _rideService.getDriverRides(limit: 10);

      Map<String, dynamic>? earnings;
      if (earningsResponse.statusCode == 200) {
        earnings = jsonDecode(earningsResponse.body);
      }

      List<Ride> trips = [];
      if (ridesResponse.statusCode == 200) {
        final decoded = jsonDecode(ridesResponse.body);
        final List<dynamic> data = decoded['rides'] ?? [];
        trips = data.map((r) => Ride.fromJson(r)).toList();
      }

      if (!mounted) return;
      setState(() {
        _earnings = earnings;
        _recentTrips = trips;
      });
    } catch (e) {
      debugPrint("Load Earnings Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingEarnings = false);
    }
  }

  void _changePeriod(String period) {
    setState(() => _period = period);
    _loadEarnings();
  }

  /// Fetching the name from the same API as the Rider side
  Future<void> _fetchDriverProfile() async {
    try {
      final response = await _authService.getCurrentProfile();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _firstName = data['user']['firstName'] ?? "Driver";
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackgroundGray,
      body: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPeriodSelector(),
              const SizedBox(height: 16),
              _buildEarningsCard(),
              const SizedBox(height: 20),
              _buildTripHistory(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. TOP HEADER (Flat brand block + Dynamic Name + Toggle)
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        60,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Driver mode",
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _firstName.isEmpty ? "Hi, Driver" : "Hi, $_firstName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _headerIconBtn(Icons.notifications_none, () {}),
                  const SizedBox(width: AppSpacing.sm),
                  _headerIconBtn(Icons.logout, _handleLogout),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Online Toggle Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi,
                    color: _isOnline ? AppColors.darkBackground : Colors.white70,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You're",
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      Text(
                        _isOnline ? "Online" : "Offline",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: _isOnline,
                  activeTrackColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() => _isOnline = val);
                    _syncAvailability(val);
                    if (val) {
                      _goOnline();
                    } else {
                      _goOffline();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    const periods = [
      {'value': 'day', 'label': 'Today'},
      {'value': 'week', 'label': 'Week'},
      {'value': 'month', 'label': 'Month'},
      {'value': 'all', 'label': 'All time'},
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: periods.map((p) {
          final bool isSelected = _period == p['value'];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(p['label']!),
              selected: isSelected,
              onSelected: (_) => _changePeriod(p['value']!),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkText,
                fontWeight: FontWeight.w600,
              ),
              elevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEarningsCard() {
    if (_isLoadingEarnings) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final totals = _earnings?['totals'] as Map<String, dynamic>?;
    final int rides = totals?['rides'] ?? 0;
    final dynamic earnings = totals?['earnings'] ?? 0;
    final dynamic distance = totals?['distanceKm'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Total earnings", style: AppText.caption),
            const SizedBox(height: 4),
            Text(
              formatNaira(earnings),
              style: AppText.h1.copyWith(fontSize: 30),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _statChip(Icons.local_taxi_outlined, "$rides trips"),
                const SizedBox(width: AppSpacing.sm),
                _statChip(Icons.route_outlined, "$distance km"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption.copyWith(color: AppColors.darkText)),
        ],
      ),
    );
  }

  Widget _buildTripHistory() {
    if (_isLoadingEarnings) return const SizedBox.shrink();

    if (_recentTrips.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: const Column(
            children: [
              Icon(Icons.inbox_outlined, size: 44, color: AppColors.muted),
              SizedBox(height: 14),
              Text("No rides yet", style: AppText.h2),
              SizedBox(height: 6),
              Text(
                "Your completed trips will appear here",
                style: AppText.bodyMuted,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text("Recent trips", style: AppText.h2),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (int i = 0; i < _recentTrips.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _tripItem(_recentTrips[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tripItem(Ride ride) {
    final rider = ride.rider;
    final String riderName = rider == null
        ? "Rider"
        : "${rider['firstName'] ?? ''} ${rider['lastName'] ?? ''}".trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.cardFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName.isEmpty ? "Rider" : riderName,
                  style: AppText.body.copyWith(fontSize: 13),
                ),
                Text(
                  ride.destinationAddress,
                  style: AppText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            ride.fareEstimate != null ? formatNaira(ride.fareEstimate) : "",
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
