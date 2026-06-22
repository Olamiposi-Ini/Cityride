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

  // Inside your RideService class
  Future<List<dynamic>> getNearbyDrivers(double lat, double lng) async {
    final Uri url = Uri.parse(
      "$baseUrl/drivers/nearby?lat=$lat&lng=$lng&radiusKm=5",
    );
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(
          response.body,
        ); // Assuming it returns a list of drivers
      }
      return [];
    } catch (e) {
      print('[ERROR] Fetch Nearby Drivers: $e');
      return [];
    }
  }
}
