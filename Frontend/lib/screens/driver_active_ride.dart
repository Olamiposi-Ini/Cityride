import 'dart:async';
import 'dart:convert';
import 'package:cityride/models/ride_model.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';

/// Full ride lifecycle screen for drivers: shown once a ride is assigned.
/// Covers accept/decline of the incoming request, then walks the driver
/// through DRIVER_EN_ROUTE -> DRIVER_ARRIVED -> IN_PROGRESS -> COMPLETED.
class DriverActiveRideScreen extends StatefulWidget {
  final Ride ride;

  const DriverActiveRideScreen({super.key, required this.ride});

  @override
  State<DriverActiveRideScreen> createState() =>
      _DriverActiveRideScreenState();
}

class _DriverActiveRideScreenState extends State<DriverActiveRideScreen> {
  final RideService _rideService = RideService();

  static const List<String> _statusFlow = [
    'DRIVER_EN_ROUTE',
    'DRIVER_ARRIVED',
    'IN_PROGRESS',
    'COMPLETED',
  ];

  static const Map<String, String> _statusTitles = {
    'DRIVER_EN_ROUTE': "Heading to pickup",
    'DRIVER_ARRIVED': "You've arrived",
    'IN_PROGRESS': "Trip in progress",
    'COMPLETED': "Trip completed",
  };

  static const Map<String, String> _nextActionLabels = {
    'DRIVER_EN_ROUTE': "I've Arrived",
    'DRIVER_ARRIVED': "Start Trip",
    'IN_PROGRESS': "Complete Trip",
  };

  late Ride _ride;
  late String _status;
  bool _isProcessing = false;
  bool _locallyAccepted = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _status = _ride.status;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _isPending => !_ride.isAccepted && !_locallyAccepted;

  Future<void> _refresh() async {
    try {
      final response = await _rideService.getRideById(_ride.id);
      if (response.statusCode == 404) {
        _exitWithMessage("This ride is no longer available.");
        return;
      }
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = decoded['ride'] ?? decoded;
        final updated = Ride.fromJson(data);
        if (updated.status.toLowerCase() == 'cancelled') {
          _exitWithMessage("The rider cancelled this trip.");
          return;
        }
        if (!mounted) return;
        setState(() {
          _ride = updated;
          if (!_statusFlow.contains(_status)) _status = updated.status;
        });
      }
    } catch (e) {
      debugPrint("Driver ride refresh error: $e");
    }
  }

  void _exitWithMessage(String message) {
    _pollTimer?.cancel();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  Future<void> _handleAccept() async {
    setState(() => _isProcessing = true);
    try {
      final response = await _rideService.acceptRide(_ride.id);
      if (response.statusCode == 200) {
        await _rideService.updateRideStatus(_ride.id, _statusFlow.first);
        if (!mounted) return;
        setState(() {
          _locallyAccepted = true;
          _status = _statusFlow.first;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't accept ride. Try again.")),
        );
      }
    } catch (e) {
      debugPrint("Accept Ride Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecline() async {
    setState(() => _isProcessing = true);
    try {
      await _rideService.declineRide(_ride.id);
    } catch (e) {
      debugPrint("Decline Ride Error: $e");
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleAdvance() async {
    final currentIndex = _statusFlow.indexOf(_status);
    final nextIndex = currentIndex == -1 ? 0 : currentIndex + 1;
    if (nextIndex >= _statusFlow.length) {
      Navigator.pop(context);
      return;
    }
    final nextStatus = _statusFlow[nextIndex];
    setState(() => _isProcessing = true);
    try {
      final response = await _rideService.updateRideStatus(
        _ride.id,
        nextStatus,
      );
      if (response.statusCode == 200) {
        if (nextStatus == 'COMPLETED') {
          _exitWithMessage("Trip completed");
          return;
        }
        if (!mounted) return;
        setState(() => _status = nextStatus);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update ride status.")),
        );
      }
    } catch (e) {
      debugPrint("Update Ride Status Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackgroundGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPending
                    ? "New ride request"
                    : (_statusTitles[_status] ?? "Ride accepted"),
                style: AppText.h1,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildRiderCard(),
              const SizedBox(height: AppSpacing.md),
              _buildTripCard(),
              const Spacer(),
              if (_isPending) _buildAcceptDeclineButtons() else _buildAdvanceButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiderCard() {
    final rider = _ride.rider;
    final String name = rider == null
        ? "Passenger"
        : "${rider['firstName'] ?? ''} ${rider['lastName'] ?? ''}".trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.cardFill,
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? "Passenger" : name, style: AppText.body),
                Text(_ride.vehicleType, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tripRow(Icons.circle, AppColors.primary, "Pickup", _ride.pickupAddress),
          const Divider(height: 24),
          _tripRow(Icons.location_on, Colors.redAccent, "Destination", _ride.destinationAddress),
        ],
      ),
    );
  }

  Widget _tripRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption),
              Text(value, style: AppText.body.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptDeclineButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isProcessing ? null : _handleDecline,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            child: const Text(
              "Decline",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleAccept,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Accept",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvanceButton() {
    final label = _nextActionLabels[_status] ?? "Head to Pickup";
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _handleAdvance,
        child: _isProcessing
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
