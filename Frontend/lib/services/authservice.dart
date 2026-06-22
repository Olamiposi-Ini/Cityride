import 'dart:convert';
import 'package:cityride/constants/api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = ApiConstants.baseUrl;

  // hello

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<http.Response> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
    String? vehicleType,
    String? plateNumber,
  }) async {
    List<String> nameParts = fullName.trim().split(' ');
    String firstName = nameParts.first;
    String lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    final Uri url = Uri.parse("$baseUrl/auth/register");

    final Map<String, dynamic> bodyPayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email.trim(),
      "phone": phone.trim(),
      "password": password,
      "role": role,
    };

    if (role == "DRIVER") {
      bodyPayload["vehicleType"] = vehicleType;
      bodyPayload["plateNumber"] = plateNumber;
    }

    // Request Log
    print('--> POST $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyPayload),
      );

      // Response Log
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');

      return response;
    } catch (e) {
      // Error Log
      print('[ERROR] Register Exception: $e');
      rethrow;
    }
  }

  Future<http.Response> verifyEmail({
    required String email,
    required String code,
  }) async {
    final Uri url = Uri.parse("$baseUrl/auth/verify-email");
    final Map<String, dynamic> bodyPayload = {
      "email": email.trim(),
      "code": code.trim(),
    };

    // Request Log
    print('--> POST $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyPayload),
      );

      // Response Log
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');

      return response;
    } catch (e) {
      print('[ERROR] Verify Email Exception: $e');
      rethrow;
    }
  }

  Future<http.Response> resendVerificationCode({required String email}) async {
    final Uri url = Uri.parse("$baseUrl/auth/resend-verification-code");
    final Map<String, dynamic> bodyPayload = {"email": email.trim()};

    print('--> POST $url');
    print('Payload: ${jsonEncode(bodyPayload)}');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyPayload),
      );

      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');
      return response;
    } catch (e) {
      print('[ERROR] Resend Code Exception: $e');
      rethrow;
    }
  }

  Future<http.Response> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final Map<String, String> payload = {
      "email": email.trim(),
      "password": password,
    };

    print("--> POST $url");
    print("Payload: ${jsonEncode(payload)}");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    print("<-- STATUS ${response.statusCode} FROM $url");
    print("Response: ${response.body}");

    // If login is successful, parse the body and encrypt the token
    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        final String? token =
            responseData['token'] ??
            responseData['accessToken'] ??
            responseData['data']?['token'];

        if (token != null) {
          await _secureStorage.write(key: 'auth_token', value: token);
          print("🔒 Secure Storage: Token successfully saved.");
        } else {
          print(
            "⚠️ Warning: Authentication succeeded but no token field was found in response payload.",
          );
        }
      } catch (e) {
        print("❌ Error parsing token data: $e");
      }
    }

    return response;
  }

  // Helper method to retrieve token for authenticated API requests
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  // Helper method to clear session token on logout
  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_token');
    print("🔒 Secure Storage: Token cleared.");
  }

  Future<http.Response> getCurrentProfile() async {
    final Uri url = Uri.parse("$baseUrl/auth/me");

    // Retrieve the saved token from secure storage
    final String? token = await getToken();

    // Setup headers with Authorization Bearer token
    final Map<String, String> headers = {"Content-Type": "application/json"};

    if (token != null) {
      headers["Authorization"] = "Bearer $token";
    } else {
      print("⚠️ Warning: Requesting profile without an authentication token.");
    }

    // Request Log
    print('--> GET $url');
    print('Headers: $headers');

    try {
      final response = await http.get(url, headers: headers);

      // Response Log
      print('<-- STATUS ${response.statusCode} FROM $url');
      print('Response: ${response.body}');

      return response;
    } catch (e) {
      // Error Log
      print('[ERROR] Get Current Profile Exception: $e');
      rethrow;
    }
  }
}
