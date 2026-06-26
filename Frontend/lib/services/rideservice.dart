import 'dart:convert';
import 'package:cityride/constants/api.dart';
import 'package:cityride/services/authservice.dart';
import 'package:http/http.dart' as http;

class RideService {
  static const String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final String? token = await _authService.getToken();
    final Map<String, String> headers = {"Content-Type": "application/json"};

    if (token != null) {
      headers["Authorization"] = "Bearer $token";
    } else {
      print("⚠️ Warning: Request missing an authentication token.");
    }
    return headers;
  }

  Future<http.Response> createRide({
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> destination,
  }) async {
    final Uri url = Uri.parse("$baseUrl/rides");
    final headers = await _getHeaders();

    final Map<String, dynamic> bodyPayload = {
      "pickupLocation": pickupLocation,
      "destination": destination,
    };

    print('--> POST $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Create Ride Exception: $e');
      rethrow;
    }
  }

  /// Fetches the user's active rides (GET /rides/me/active)
  Future<http.Response> getActiveRides() async {
    final Uri url = Uri.parse("$baseUrl/rides/me/active");
    final headers = await _getHeaders();

    print('--> GET $url');

    try {
      final response = await http.get(url, headers: headers);
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Get Active Rides Exception: $e');
      rethrow;
    }
  }

  /// Accepts a specific ride by its ID (PATCH /rides/{rideId}/accept)
  Future<http.Response> acceptRide(String rideId) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId/accept");
    final headers = await _getHeaders();

    print('--> PATCH $url');

    try {
      // http.patch is used here to match your --request PATCH instruction
      final response = await http.patch(url, headers: headers);
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Accept Ride Exception: $e');
      rethrow;
    }
  }

  /// Gets a fare estimate for a trip (POST /rides/estimate)
  Future<http.Response> estimateFare({
    required Map<String, dynamic> pickupLocation,
    required Map<String, dynamic> destination,
  }) async {
    final Uri url = Uri.parse("$baseUrl/rides/estimate");
    final headers = await _getHeaders();

    final Map<String, dynamic> bodyPayload = {
      "pickupLocation": pickupLocation,
      "destination": destination,
    };

    print('--> POST $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Estimate Fare Exception: $e');
      rethrow;
    }
  }

  /// Fetches a single ride by its ID (GET /rides/{rideId})
  Future<http.Response> getRideById(String rideId) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId");
    final headers = await _getHeaders();

    print('--> GET $url');

    try {
      final response = await http.get(url, headers: headers);
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Get Ride By Id Exception: $e');
      rethrow;
    }
  }

  /// Declines a specific ride by its ID (PATCH /rides/{rideId}/decline)
  Future<http.Response> declineRide(String rideId) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId/decline");
    final headers = await _getHeaders();

    print('--> PATCH $url');

    try {
      final response = await http.patch(url, headers: headers);
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Decline Ride Exception: $e');
      rethrow;
    }
  }

  /// Updates a ride's status (PATCH /rides/{rideId}/status)
  /// [status] must be one of: DRIVER_EN_ROUTE, DRIVER_ARRIVED, IN_PROGRESS, COMPLETED
  Future<http.Response> updateRideStatus(String rideId, String status) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId/status");
    final headers = await _getHeaders();
    final bodyPayload = {"status": status};

    print('--> PATCH $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Update Ride Status Exception: $e');
      rethrow;
    }
  }

  /// Cancels a specific ride by its ID (PATCH /rides/{rideId}/cancel)
  Future<http.Response> cancelRide(String rideId) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId/cancel");
    final headers = await _getHeaders();

    print('--> PATCH $url');

    try {
      final response = await http.patch(url, headers: headers);
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Cancel Ride Exception: $e');
      rethrow;
    }
  }

  // Inside your RideService class
  Future<List<dynamic>> getNearbyDrivers(double lat, double lng) async {
    final Uri url = Uri.parse(
      "$baseUrl/drivers/nearby?lat=$lat&lng=$lng&radiusKm=5",
    );
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return decoded['drivers'] ?? [];
      }
      return [];
    } catch (e) {
      print('[ERROR] Fetch Nearby Drivers: $e');
      return [];
    }
  }

  /// Sets the current driver's availability (PATCH /drivers/me/availability)
  Future<http.Response> setAvailability(bool isAvailable) async {
    final Uri url = Uri.parse("$baseUrl/drivers/me/availability");
    final headers = await _getHeaders();
    final bodyPayload = {"isAvailable": isAvailable};

    print('--> PATCH $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Set Availability Exception: $e');
      rethrow;
    }
  }

  /// Updates the current driver's GPS location (PATCH /drivers/me/location)
  Future<http.Response> updateDriverLocation(double lat, double lng) async {
    final Uri url = Uri.parse("$baseUrl/drivers/me/location");
    final headers = await _getHeaders();
    final bodyPayload = {"lat": lat, "lng": lng};

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      return response;
    } catch (e) {
      print('[ERROR] Update Driver Location Exception: $e');
      rethrow;
    }
  }

  /// Fetches the current driver's incoming ride requests (GET /drivers/me/requests)
  Future<http.Response> getIncomingRideRequests() async {
    final Uri url = Uri.parse("$baseUrl/drivers/me/requests");
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      return response;
    } catch (e) {
      print('[ERROR] Get Incoming Ride Requests Exception: $e');
      rethrow;
    }
  }

  /// Fetches the current user's ride history (GET /rides/me/history)
  Future<http.Response> getRideHistory({
    List<String> statuses = const ['COMPLETED', 'CANCELLED'],
    int limit = 20,
    int offset = 0,
  }) async {
    final params = statuses.map((s) => 'status=$s').join('&');
    final Uri url = Uri.parse(
      "$baseUrl/rides/me/history?$params&limit=$limit&offset=$offset",
    );
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      return response;
    } catch (e) {
      print('[ERROR] Get Ride History Exception: $e');
      rethrow;
    }
  }

  /// Fetches the current driver's earnings summary (GET /drivers/me/earnings)
  Future<http.Response> getDriverEarnings({String period = 'week'}) async {
    final Uri url = Uri.parse("$baseUrl/drivers/me/earnings?period=$period");
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      return response;
    } catch (e) {
      print('[ERROR] Get Driver Earnings Exception: $e');
      rethrow;
    }
  }

  /// Fetches the current driver's own trip list (GET /drivers/me/rides)
  Future<http.Response> getDriverRides({
    List<String> statuses = const ['COMPLETED'],
    int limit = 20,
    int offset = 0,
  }) async {
    final params = statuses.map((s) => 'status=$s').join('&');
    final Uri url = Uri.parse(
      "$baseUrl/drivers/me/rides?$params&limit=$limit&offset=$offset",
    );
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      return response;
    } catch (e) {
      print('[ERROR] Get Driver Rides Exception: $e');
      rethrow;
    }
  }

  /// Updates the current driver's vehicle details (PATCH /drivers/me)
  Future<http.Response> updateDriverProfile({
    String? vehicleType,
    String? plateNumber,
  }) async {
    final Uri url = Uri.parse("$baseUrl/drivers/me");
    final headers = await _getHeaders();
    final Map<String, dynamic> bodyPayload = {};
    if (vehicleType != null) bodyPayload["vehicleType"] = vehicleType;
    if (plateNumber != null) bodyPayload["plateNumber"] = plateNumber;

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      return response;
    } catch (e) {
      print('[ERROR] Update Driver Profile Exception: $e');
      rethrow;
    }
  }

  /// Submits a rating for a completed ride (POST /rides/{rideId}/rating)
  Future<http.Response> submitRating(
    String rideId,
    int rating, {
    String? comment,
  }) async {
    final Uri url = Uri.parse("$baseUrl/rides/$rideId/rating");
    final headers = await _getHeaders();
    final Map<String, dynamic> bodyPayload = {"rating": rating};
    if (comment != null && comment.isNotEmpty) {
      bodyPayload["comment"] = comment;
    }

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyPayload),
      );
      return response;
    } catch (e) {
      print('[ERROR] Submit Rating Exception: $e');
      rethrow;
    }
  }
}
