import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cityride/models/ride_model.dart';
import 'package:cityride/screens/driversearch.dart';
import 'package:cityride/screens/profile_screen.dart';
import 'package:cityride/screens/settins.dart';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/services/authservice.dart';
import 'package:cityride/services/rideservice.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
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

  String? _assignedPickupLabel;
  String? _assignedDestinationLabel;

  String _selectedVehicle = "Keke";
  bool _showVehicles = false;

  // Typed Model Instance
  Ride? _activeRide;

  final String _googleApiKey = "AIzaSyCeZCzNBO5995VfpOA7b2baQ1fJBP9t71c";

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
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _activeRide = Ride.fromJson(data[0]); // Using the Model
            _showVehicles = false;
          });
          _startStatusPolling();
        } else {
          setState(() => _activeRide = null);
          _statusTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
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

  void _onChipTap(String label) {
    if (_currentPosition == null) return;
    final random = Random();
    double latOffset = (random.nextDouble() * 0.02) - 0.01;
    double lngOffset = (random.nextDouble() * 0.02) - 0.01;
    LatLng targetPos = LatLng(
      _currentPosition!.latitude + latOffset,
      _currentPosition!.longitude + lngOffset,
    );

    setState(() {
      if (_isSearchingPickup) {
        _pickupController.text = label;
        _assignedPickupLabel = label;
        _addMarker(
          const MarkerId("pickup"),
          targetPos,
          label,
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
        _isSearchingPickup = false;
      } else {
        _destinationController.text = label;
        _assignedDestinationLabel = label;
        _destinationPosition = targetPos;
        _showVehicles = true;
        _addMarker(
          const MarkerId("destination"),
          targetPos,
          label,
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }
      _searchResults = [];
    });
    _moveCamera(targetPos);
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
          "address": _pickupController.text,
        },
        destination: {
          "lat": _destinationPosition!.latitude,
          "lng": _destinationPosition!.longitude,
          "address": _destinationController.text,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        _syncActiveRide();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DriverSearchScreen(
              pickupLocation: _currentPosition!,
              vehicleType: _selectedVehicle,
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
                child: const Icon(Icons.my_location, color: Color(0xFF147D44)),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
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
                        _buildQuickChips(),
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
    bool isAccepted = _activeRide!.status != 'pending';
    final driver = _activeRide!.driver;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
      child: Column(
        children: [
          Text(
            isAccepted ? "Driver is on the way" : "Finding your driver...",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF147D44),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[200],
              child: Icon(isAccepted ? Icons.person : Icons.hourglass_empty),
            ),
            title: Text(
              isAccepted
                  ? "${driver!['firstName']} ${driver['lastName']}"
                  : "Searching nearby drivers",
            ),
            subtitle: Text(
              isAccepted
                  ? "${_activeRide!.vehicleType} • 4.9 ★"
                  : "We'll notify you once accepted",
            ),
            trailing: isAccepted
                ? IconButton(
                    icon: const Icon(Icons.phone, color: Color(0xFF147D44)),
                    onPressed: () {},
                  )
                : null,
          ),
          const Divider(),
          _infoRow("To", _activeRide!.destinationAddress),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {}, // Implement cancel API call
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "Cancel Ride",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          children: [
            _circleBtn(
              Icons.menu,
              () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF147D44),
                      size: 14,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickupController.text.isEmpty
                            ? _currentAddress
                            : _pickupController.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _circleBtn(Icons.notifications_none, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good Morning, ${_firstName.isEmpty ? 'User' : _firstName}",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const Text(
                "Where to Today?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ],
          ),
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F2EE),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          children: [
            _inputField(_pickupController, "Pickup", Icons.circle, true),
            const SizedBox(height: 10),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF147D44), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                TextField(
                  controller: controller,
                  onTap: () => setState(() => _isSearchingPickup = isPickup),
                  onChanged: (val) => _onSearchChanged(val, isPickup),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
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
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF147D44)),
            accountName: Text(
              _firstName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_userMail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 45, color: Color(0xFF147D44)),
            ),
          ),
          _drawerItem(Icons.person_outline, "Profile", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 50,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }

  Widget _buildHandleBar() => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      height: 5,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  Widget _buildQuickChips() {
    final locations = [
      {'label': 'Home', 'icon': Icons.home},
      {'label': 'Office', 'icon': Icons.work},
      {'label': 'Chapel', 'icon': Icons.church},
      {'label': 'City Mall', 'icon': Icons.shopping_bag},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: locations
            .where(
              (loc) =>
                  loc['label'] != _assignedPickupLabel &&
                  loc['label'] != _assignedDestinationLabel,
            )
            .map((loc) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(
                    loc['icon'] as IconData,
                    size: 14,
                    color: const Color(0xFF147D44),
                  ),
                  label: Text(loc['label'] as String),
                  onPressed: () => _onChipTap(loc['label'] as String),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.black12),
                  ),
                ),
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildVehicleSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _vehicleCard("Keke", Icons.motorcycle, "₦200 - 500"),
          _vehicleCard("Cab", Icons.directions_car, "₦500 - 800"),
          _vehicleCard("Bus", Icons.directions_bus, "₦800 - 1200"),
        ],
      ),
    );
  }

  Widget _vehicleCard(String type, IconData icon, String priceRange) {
    bool isSelected = _selectedVehicle == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicle = type),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF147D44) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black87,
              size: 30,
            ),
            const SizedBox(height: 5),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              priceRange,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareSummary() {
    String fare = _selectedVehicle == "Keke"
        ? "₦200 - 500"
        : (_selectedVehicle == "Cab" ? "₦500 - 800" : "₦800 - 1200");
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F2EE),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Estimated fare",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  fare,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Arrival",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  "5 mins",
                  style: TextStyle(
                    color: Color(0xFF147D44),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: _isBooking ? null : _handleBookRide,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF147D44),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isBooking
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                "Book $_selectedVehicle",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _onSearchChanged(String query, bool isPickup) {
    setState(() {
      _isSearchingPickup = isPickup;
      if (isPickup)
        _assignedPickupLabel = null;
      else
        _assignedDestinationLabel = null;
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _searchResults.length,
        separatorBuilder: (c, i) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(
          leading: const Icon(Icons.location_on, color: Color(0xFF147D44)),
          title: Text(
            _searchResults[index]['description'],
            style: const TextStyle(fontSize: 14),
          ),
          onTap: () => _selectPlace(_searchResults[index]),
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
          _firstName = data['user']['firstName'] ?? "Toke";
          _userMail = data['user']['email'] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }
}
