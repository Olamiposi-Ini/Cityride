import 'dart:async';
import 'dart:convert';
import 'package:cityride/constants/api.dart';
import 'package:cityride/models/ride_model.dart';
import 'package:cityride/screens/driversearch.dart';
import 'package:cityride/screens/profile_screen.dart';
import 'package:cityride/screens/ride_history.dart' show RideHistoryScreen, showRatingSheet;
import 'package:cityride/screens/settins.dart';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/services/authservice.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:cityride/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:cityride/utils/format.dart';
import 'package:http/http.dart' as http;

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  final RideService _rideService = RideService();

  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  LatLng? _destinationPosition;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<dynamic> _searchResults = [];
  bool _isSearchingPickup = true;
  bool _isBooking = false;
  Timer? _debounce;
  Timer? _statusTimer;
  final Map<MarkerId, Marker> _markers = {};

  String _firstName = "";
  String _userMail = "";
  String _currentAddress = "Locating...";

  String _selectedVehicle = "Keke";
  bool _showVehicles = false;
  String? _estimatedFare;

  // Typed Model Instance
  Ride? _activeRide;

  final String _googleApiKey = ApiConstants.googleMapsKey;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _fetchProfileName();
    _syncActiveRide(); // Initial sync
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // RIDE STATE & POLLING
  // ---------------------------------------------------------------------------

  Future<void> _syncActiveRide() async {
    try {
      final response = await _rideService.getActiveRides();
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final List<dynamic> data = decoded['rides'] ?? [];
        if (data.isNotEmpty) {
          setState(() {
            _activeRide = Ride.fromJson(data[0]); // Using the Model
            _showVehicles = false;
          });
          _startStatusPolling();
        } else {
          final String? finishedRideId = _activeRide?.id;
          setState(() => _activeRide = null);
          _statusTimer?.cancel();
          if (finishedRideId != null) _checkIfNeedsRating(finishedRideId);
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> _checkIfNeedsRating(String rideId) async {
    try {
      final response = await _rideService.getRideById(rideId);
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final data = decoded['ride'] ?? decoded;
      if (data['status'] == 'COMPLETED' && data['rating'] == null) {
        if (!mounted) return;
        showRatingSheet(context, _rideService, rideId);
      }
    } catch (e) {
      debugPrint("Rating Check Error: $e");
    }
  }

  void _startStatusPolling() {
    if (_statusTimer != null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _syncActiveRide();
    });
  }

  // ---------------------------------------------------------------------------
  // MAP & SELECTION LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _checkLocationPermission() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always) {
      _determineInitialPosition();
    }
  }

  void _determineInitialPosition() async {
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    LatLng pos = LatLng(position.latitude, position.longitude);
    setState(() => _currentPosition = pos);
    _moveCamera(pos);
    String address = await _getAddressFromLatLng(pos);
    setState(() {
      _currentAddress = address;
      _pickupController.text = address;
      _addMarker(
        const MarkerId("pickup"),
        pos,
        "Pickup",
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });
  }

  Future<void> _onMapTap(LatLng pos) async {
    if (_activeRide != null) return;
    String address = await _getAddressFromLatLng(pos);
    setState(() {
      if (_isSearchingPickup) {
        _currentPosition = pos;
        _pickupController.text = address;
        _addMarker(
          const MarkerId("pickup"),
          pos,
          "Pickup",
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
        _isSearchingPickup = false;
      } else {
        _destinationPosition = pos;
        _destinationController.text = address;
        _showVehicles = true;
        _addMarker(
          const MarkerId("destination"),
          pos,
          "Destination",
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }
    });
    if (_showVehicles) _fetchFareEstimate();
  }

  Future<String> _getAddressFromLatLng(LatLng pos) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_googleApiKey";
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty)
        return data['results'][0]['formatted_address'];
    } catch (e) {
      debugPrint(e.toString());
    }
    return "Selected Location";
  }

  // ---------------------------------------------------------------------------
  // API ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _handleBookRide() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    setState(() => _isBooking = true);
    try {
      final response = await _rideService.createRide(
        pickupLocation: {
          "lat": _currentPosition!.latitude,
          "lng": _currentPosition!.longitude,
          "label": _pickupController.text,
          "address": _pickupController.text,
        },
        destination: {
          "lat": _destinationPosition!.latitude,
          "lng": _destinationPosition!.longitude,
          "label": _destinationController.text,
          "address": _destinationController.text,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        _syncActiveRide();
        final data = jsonDecode(response.body);
        final String? rideId = data['ride']?['id'] ?? data['id'];
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverSearchScreen(
              pickupLocation: _currentPosition!,
              vehicleType: _selectedVehicle,
              rideId: rideId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Booking Error: $e");
    } finally {
      setState(() => _isBooking = false);
    }
  }

  Future<void> _handleCancelRide() async {
    if (_activeRide == null) return;
    final String rideId = _activeRide!.id;
    setState(() => _isBooking = true);
    try {
      final response = await _rideService.cancelRide(rideId);
      if (response.statusCode == 200) {
        _statusTimer?.cancel();
        _statusTimer = null;
        setState(() => _activeRide = null);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't cancel ride. Try again.")),
        );
      }
    } catch (e) {
      debugPrint("Cancel Ride Error: $e");
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _fetchFareEstimate() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    try {
      final response = await _rideService.estimateFare(
        pickupLocation: {
          "lat": _currentPosition!.latitude,
          "lng": _currentPosition!.longitude,
          "label": _pickupController.text,
        },
        destination: {
          "lat": _destinationPosition!.latitude,
          "lng": _destinationPosition!.longitude,
          "label": _destinationController.text,
        },
      );
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        final dynamic fare =
            data['estimate']?['fareEstimate'] ??
            data['fare'] ??
            data['estimatedFare'] ??
            data['amount'];
        if (fare != null) {
          setState(() => _estimatedFare = formatNaira(fare));
          return;
        }
      }
      setState(() => _estimatedFare = null);
    } catch (e) {
      debugPrint("Fare Estimate Error: $e");
      setState(() => _estimatedFare = null);
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildProfessionalDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(6.46, 3.40),
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: Set<Marker>.of(_markers.values),
            onTap: _onMapTap,
          ),

          if (_activeRide == null) _buildTopBar(),

          // GPS Button
          if (_activeRide == null)
            Positioned(
              bottom: (MediaQuery.of(context).size.height * 0.4) + 20,
              right: 20,
              child: FloatingActionButton(
                heroTag: "gps_home",
                onPressed: _determineInitialPosition,
                backgroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  boxShadow: AppShadows.raised,
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHandleBar(),
                    if (_activeRide != null)
                      _buildActiveRideUI() // Using Model-based UI
                    else ...[
                      if (_searchResults.isEmpty) _buildGreetingHeader(),
                      _buildInputSection(),
                      if (_searchResults.isNotEmpty) _buildSuggestionsList(),
                      if (_searchResults.isEmpty) ...[
                        if (_showVehicles) _buildVehicleSelection(),
                        if (_showVehicles) _buildFareSummary(),
                        _buildBookButton(),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideUI() {
    bool isAccepted = _activeRide!.isAccepted;
    final driver = _activeRide!.driver;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isAccepted ? AppColors.primary : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isAccepted ? "Driver is on the way" : "Finding your driver…",
                style: AppText.h2,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(
                    isAccepted ? Icons.person : Icons.hourglass_empty,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAccepted
                            ? "${driver!['firstName']} ${driver['lastName']}"
                            : "Searching nearby drivers",
                        style: AppText.body,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAccepted
                            ? "${_activeRide!.vehicleType} • ${_activeRide!.driverRatingAverage != null ? '${_activeRide!.driverRatingAverage!.toStringAsFixed(1)} ★' : 'New'}"
                            : "We'll notify you once accepted",
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                if (isAccepted) _circleBtn(Icons.phone, () {}, size: 42),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _infoRow(Icons.flag_outlined, "To", _activeRide!.destinationAddress),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _handleCancelRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorBackground,
                foregroundColor: Colors.red,
                elevation: 0,
              ),
              child: _isBooking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Cancel Ride",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.lightGreyText),
        const SizedBox(width: 8),
        Text("$label  ", style: AppText.caption),
        Expanded(
          child: Text(
            value,
            style: AppText.body.copyWith(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _circleBtn(
              Icons.menu,
              () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: AppColors.primary,
                      size: 12,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _pickupController.text.isEmpty
                            ? _currentAddress
                            : _pickupController.text,
                        style: AppText.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _circleBtn(Icons.notifications_none, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good morning, ${_firstName.isEmpty ? 'User' : _firstName}",
                style: AppText.bodyMuted,
              ),
              const SizedBox(height: 2),
              const Text("Where to today?", style: AppText.h1),
            ],
          ),
          const CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.cardFill,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            _inputField(_pickupController, "Pickup", Icons.circle, true),
            _inputField(
              _destinationController,
              "Destination",
              Icons.location_on,
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isPickup,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            color: isPickup ? AppColors.primary : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label),
                TextField(
                  controller: controller,
                  onTap: () => setState(() => _isSearchingPickup = isPickup),
                  onChanged: (val) => _onSearchChanged(val, isPickup),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            accountName: Text(
              _firstName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            accountEmail: Text(_userMail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 45, color: AppColors.primary),
            ),
          ),
          _drawerItem(Icons.person_outline, "Profile", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }),

          _drawerItem(Icons.history, "Trip History", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RideHistoryScreen()),
            );
          }),

          _drawerItem(Icons.settings_outlined, "Settings", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          }),
          const Spacer(),
          _drawerItem(Icons.logout, "Logout", () async {
            await _authService.logout();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SignInScreen()),
              );
            }
          }, color: Colors.red),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UTILS ---
  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.darkText),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? AppColors.darkText,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {double size = 50}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: size,
        width: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.subtle,
        ),
        child: Icon(icon, color: AppColors.darkText, size: size * 0.44),
      ),
    );
  }

  Widget _buildHandleBar() => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: AppColors.indicatorInactive,
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  Widget _buildVehicleSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _vehicleCard("Keke", Icons.electric_rickshaw),
          _vehicleCard("Cab", Icons.directions_car_filled),
          _vehicleCard("Bus", Icons.directions_bus_filled),
        ],
      ),
    );
  }

  Widget _vehicleCard(String type, IconData icon) {
    bool isSelected = _selectedVehicle == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: 1.4,
          ),
          boxShadow: isSelected ? AppShadows.subtle : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.darkText,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.darkText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareSummary() {
    if (_estimatedFare == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimated fare", style: AppText.caption),
                Text(
                  _estimatedFare!,
                  style: AppText.h2.copyWith(fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: ElevatedButton(
        onPressed: _isBooking ? null : _handleBookRide,
        child: _isBooking
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                "Book $_selectedVehicle",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  void _onSearchChanged(String query, bool isPickup) {
    setState(() {
      _isSearchingPickup = isPickup;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (query.length < 2) {
        setState(() => _searchResults = []);
        return;
      }
      try {
        final url =
            "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$_googleApiKey";
        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);
        if (data['status'] == 'OK')
          setState(() => _searchResults = data['predictions'] ?? []);
      } catch (e) {
        debugPrint("Autocomplete error: $e");
      }
    });
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _searchResults.length,
            separatorBuilder: (c, i) =>
                const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: Text(
                _searchResults[index]['description'],
                style: AppText.body.copyWith(fontSize: 14),
              ),
              onTap: () => _selectPlace(_searchResults[index]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectPlace(dynamic suggestion) async {
    String placeId = suggestion['place_id'];
    String mainText = suggestion['structured_formatting']['main_text'];
    final url =
        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey";
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data['status'] == "OK") {
      final loc = data['result']['geometry']['location'];
      LatLng pos = LatLng(loc['lat'], loc['lng']);
      setState(() {
        if (_isSearchingPickup) {
          _pickupController.text = mainText;
          _currentPosition = pos;
          _addMarker(
            const MarkerId("pickup"),
            pos,
            "Pickup",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          );
          _isSearchingPickup = false;
        } else {
          _destinationController.text = mainText;
          _destinationPosition = pos;
          _showVehicles = true;
          _addMarker(
            const MarkerId("destination"),
            pos,
            "Destination",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          );
        }
        _searchResults = [];
      });
      _moveCamera(pos);
      FocusScope.of(context).unfocus();
      if (_showVehicles) _fetchFareEstimate();
    }
  }

  void _addMarker(
    MarkerId id,
    LatLng pos,
    String title,
    BitmapDescriptor icon,
  ) {
    setState(() {
      _markers[id] = Marker(
        markerId: id,
        position: pos,
        infoWindow: InfoWindow(title: title),
        icon: icon,
      );
    });
  }

  void _moveCamera(LatLng pos) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 15)),
    );
  }

  Future<void> _fetchProfileName() async {
    try {
      final response = await _authService.getCurrentProfile();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _firstName = data['user']['firstName'] ?? "User";
          _userMail = data['user']['email'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }
}
