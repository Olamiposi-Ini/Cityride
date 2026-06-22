import 'dart:convert';
import 'package:cityride/screens/signin.dart';
import 'package:cityride/screens/verification.dart';
import 'package:cityride/services/authservice.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color green = Color(0xFF0F7543);
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  String? selectedRole;
  String? selectedVehicle;
  bool _isLoading = false;

  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final plateController = TextEditingController();

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    plateController.dispose();
    super.dispose();
  }

  // Handle the registration API request logic flow
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Local validation for matching passwords
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    // Enforce role selection
    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a profile role type")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.register(
        fullName: fullNameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
        role: selectedRole!,
        vehicleType: selectedRole == "DRIVER" ? selectedVehicle : null,
        plateNumber: selectedRole == "DRIVER" ? plateController.text : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VerificationScreen(email: emailController.text.trim()),
            ),
          );
        }
      } else if (response.statusCode == 409) {
        // Intercept 409 Conflict (User already exists)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "An account with this email/phone already exists. Redirecting to login...",
              ),
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to the Sign In screen and drop the registration stack
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        }
      } else {
        // Parse server error descriptions gracefully for other codes (e.g., 400, 500)
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['message'] ?? 'An error occurred during registration',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Network connection error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: green,
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              // Top Section containing the Logo
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 150,
                      width: 150,
                      child: Image.asset(
                        "assets/cityride.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // Main Form Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F4F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              "Welcome!",
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A1C2A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Please Sign up to enjoy our services",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildTextField(
                              "Full Name",
                              "Enter Full Name",
                              fullNameController,
                              validator: (value) => value!.isEmpty
                                  ? "Full name is required"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              "Phone Number",
                              "Enter Phone",
                              phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (value) => value!.isEmpty
                                  ? "Phone number is required"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              "Email",
                              "Enter Email",
                              emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value!.isEmpty) return "Email is required";
                                if (!value.contains("@"))
                                  return "Enter a valid email address";
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              "Password",
                              "Enter Password",
                              passwordController,
                              obscure: true,
                              validator: (value) => value!.length < 6
                                  ? "Password must be at least 6 characters"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              "Confirm Password",
                              "Confirm Password",
                              confirmPasswordController,
                              obscure: true,
                              validator: (value) => value!.isEmpty
                                  ? "Please confirm your password"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildDropdown(
                              label: "Role",
                              value: selectedRole,
                              items: const [
                                DropdownMenuItem(
                                  value: "RIDER",
                                  child: Text("RIDER"),
                                ),
                                DropdownMenuItem(
                                  value: "DRIVER",
                                  child: Text("DRIVER"),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedRole = value;
                                });
                              },
                            ),
                            if (selectedRole == "DRIVER") ...[
                              const SizedBox(height: 16),
                              _buildTextField(
                                "Plate Number",
                                "Enter Plate Number",
                                plateController,
                                validator: (value) =>
                                    selectedRole == "DRIVER" && value!.isEmpty
                                    ? "Plate number is required for drivers"
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildDropdown(
                                label: "Vehicle Type",
                                value: selectedVehicle,
                                items: const [
                                  DropdownMenuItem(
                                    value: "CAB",
                                    child: Text("CAB"),
                                  ),
                                  DropdownMenuItem(
                                    value: "KEKE",
                                    child: Text("KEKE"),
                                  ),
                                  DropdownMenuItem(
                                    value: "BUS",
                                    child: Text("BUS"),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedVehicle = value;
                                  });
                                },
                              ),
                            ],
                            const SizedBox(height: 35),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: green,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        "Sign Up",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already have an account? ",
                                  style: TextStyle(color: Colors.black54),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignInScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Sign In",
                                    style: TextStyle(
                                      color: green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: (val) => val == null ? "Selection required" : null,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
